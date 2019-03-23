#!/usr/bin/env bash
# This script is run on the gcloud instance. Be sure to edit the password before running it!
get_metadata() {
curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1?alt=text" -H "Metadata-Flavor: Google"
}

set -e

echo "Getting metadata..."
BRANCH=$(get_metadata BRANCH)
PASSWORD=$(get_metadata ADMIN_PASSWORD)
EXIST_MEMORY=$(get_metadata EXIST_MEMORY)
DYN_EMAIL=$(get_metadata DYN_EMAIL)
DYN_USERNAME=$(get_metadata DYN_USERNAME)
DYN_PASSWORD=$(get_metadata DYN_PASSWORD)
BACKUP_BUCKET_BASE=$(get_metadata BACKUP_BUCKET_BASE)
INSTALL_DIR=/usr/local/opensiddur

echo "Setting up the eXist user..."
useradd -c "eXist db"  exist

echo "Downloading prerequisites..."
apt update
export DEBIAN_FRONTEND=noninteractive
apt-get install -yq ddclient maven openjdk-8-jdk ant libxml2 libxml2-utils nginx python3-certbot-nginx python3-lxml unzip
update-java-alternatives -s java-1.8.0-openjdk-amd64

echo "Obtaining opensiddur sources..."
mkdir -p src
cd src
git clone git://github.com/opensiddur/opensiddur.git
cd opensiddur
git checkout ${BRANCH}
export SRC=$(pwd)
cat << EOF > local.build.properties
installdir=${INSTALL_DIR}
max.memory=${EXIST_MEMORY}
cache.size=512
adminpassword=${PASSWORD}
EOF

echo "Building opensiddur..."
ant autodeploy

chown -R exist:exist ${INSTALL_DIR}

# install the yajsw script
echo "Installing YAJSW..."
export RUN_AS_USER=exist
export WRAPPER_UNATTENDED=1
export WRAPPER_USE_SYSTEMD=1
${INSTALL_DIR}/tools/yajsw/bin/installDaemon.sh

echo "Installing periodic backup cleaning..."
cat << EOF > /etc/cron.daily/clean-exist-backups
#!/bin/sh
find ${INSTALL_DIR}/webapp/WEB-INF/data/export/full* \
  -maxdepth 0 \
  -type d \
  -not -newermt \$(date -d "14 days ago" +%Y%m%d) \
  -execdir rm -fr {} \;

find ${INSTALL_DIR}/webapp/WEB-INF/data/export/report* \
  -maxdepth 0 \
  -type d \
  -not -newermt \$(date -d "14 days ago" +%Y%m%d) \
  -execdir rm -fr {} \;
EOF
chmod +x /etc/cron.daily/clean-exist-backups

# get some gcloud metadata:
PROJECT=$(gcloud config get-value project)
INSTANCE_NAME=$(hostname)
ZONE=$(gcloud compute instances list --filter="name=(${INSTANCE_NAME})" --format 'csv[no-heading](zone)')

export DNS_NAME="db-feature.jewishliturgy.org"
BACKUP_CLOUD_BUCKET="${BACKUP_BUCKET_BASE}-feature"
# branch-specific environment settings
if [[ $BRANCH == "master" ]];
then
    BACKUP_BASE_BRANCH="master"
    BACKUP_CLOUD_BUCKET="${BACKUP_BUCKET_BASE}-prod"
    DNS_NAME="db-prod.jewishliturgy.org";
else
    BACKUP_BASE_BRANCH="develop";
    if [[ $BRANCH == "develop" ]];
    then
        BACKUP_CLOUD_BUCKET="${BACKUP_BUCKET_BASE}-preprod"
        DNS_NAME="db-dev.jewishliturgy.org";
    fi
fi
BACKUP_INSTANCE_BASE=${PROJECT}-${BACKUP_BASE_BRANCH}
INSTANCE_BASE=${PROJECT}-${BRANCH//\//-}

echo "My backup base is $BACKUP_BASE_BRANCH"

# retrieve the latest backup from the prior instance
echo "Generating ssh keys..."
ssh-keygen -q -N "" -f ~/.ssh/google_compute_engine

# download the backup from the prior instance
PRIOR_INSTANCE=$(gcloud compute instances list --filter="status=RUNNING AND name~'${BACKUP_INSTANCE_BASE}'" | \
       sed -n '1!p' | \
       cut -d " " -f 1 | \
       grep -v "${INSTANCE_NAME}" | \
       head -n 1)
if [[ -n "${PRIOR_INSTANCE}" ]];
then
    echo "Prior instance ${PRIOR_INSTANCE} exists. Retrieving a backup...";
    COMMIT=$(git rev-parse --short HEAD)

    echo "Performing a backup on ${PRIOR_INSTANCE}..."
    gcloud compute ssh ${PRIOR_INSTANCE} --zone ${ZONE} --command "cd /src/opensiddur && sudo -u exist ant backup-for-upgrade -Dbackup.directory=/tmp/backup.${COMMIT}"

    echo "Copying backup here..."
    mkdir /tmp/exist-backup
    gcloud compute scp ${PRIOR_INSTANCE}:/tmp/backup.${COMMIT}/exist-backup.tar.gz /tmp/exist-backup --zone ${ZONE}
    gcloud compute ssh ${PRIOR_INSTANCE} --zone ${ZONE} --command "sudo rm -fr /tmp/backup.${COMMIT}"
    ( cd /tmp/exist-backup && tar zxvf exist-backup.tar.gz )
    # restore the backup
    echo "Restoring backup..."
    sudo -u exist ant restore

    # remove the backup
    rm -fr /tmp/exist-backup
else
    echo "No prior instance exists. No backup will be retrieved.";
fi

echo "Installing daily backup copy..."
EXPORT_DIR=${INSTALL_DIR}/webapp/WEB-INF/data/export
cat << EOF > /etc/cron.daily/copy-exist-backups
#!/bin/bash
echo "Starting Open Siddur Daily Backup to Cloud..."

export PATH=\$PATH:/snap/bin

for dir in \$(find ${EXPORT_DIR}/* -maxdepth 0 -type d -newermt \$(date -d "1 day ago" +%Y%m%d) ); do
    cd \$dir
    BASENAME=\$(basename \$dir)
    echo "Backing up \$BASENAME to gs://${BACKUP_CLOUD_BUCKET}..."
    tar zcvf \$BASENAME.tar.gz db
    gsutil cp \$BASENAME.tar.gz gs://${BACKUP_CLOUD_BUCKET}
    rm \$dir/\$BASENAME.tar.gz;
done

echo "Daily backup complete."
EOF
chmod +x /etc/cron.daily/copy-exist-backups

echo "Starting eXist..."
systemctl start eXist-db

echo "Wait until eXist-db is up..."
python3 python/wait_for_up.py

echo "Installing dynamic DNS updater to update ${DNS_NAME}..."
cat << EOF > /etc/ddclient.conf
## ddclient configuration file
daemon=600
# check every 600 seconds
syslog=yes
# log update msgs to syslog
mail-failure=${DYN_EMAIL} # Mail failed updates to user
pid=/var/run/ddclient.pid
# record PID in file.
ssl=yes
# use HTTPS
## Detect IP with our CheckIP server
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
## DynDNS username and password here
login=${DYN_USERNAME}
password=${DYN_PASSWORD}
## Default options
  protocol=dyndns2
server=members.dyndns.org
## Dyn Standard DNS hosts
custom=yes, ${DNS_NAME}
EOF

echo "Restarting ddclient..."
systemctl restart ddclient;

echo "Configure nginx..."
cat setup/nginx.conf.tmpl | envsubst '$DNS_NAME' > /etc/nginx/sites-enabled/opensiddur.conf

echo "Wait for DNS propagation..."
PUBLIC_IP=$(curl icanhazip.com)
while [[ $(dig +short ${DNS_NAME} @resolver1.opendns.com) != "${PUBLIC_IP}" ]];
do
    echo "Waiting 1 min for ${DNS_NAME} to resolve to ${PUBLIC_IP}..."
    sleep 60;
done

echo "Get an SSL certificate..."
if [[ $BRANCH = feature/* ]];
then
    echo "using staging cert for feature branch $BRANCH"
    CERTBOT_DRY_RUN="--test-cert";
else
    CERTBOT_DRY_RUN="";
fi
certbot --nginx -n --domain ${DNS_NAME} --email ${DYN_EMAIL} --no-eff-email --agree-tos --redirect ${CERTBOT_DRY_RUN}

echo "Scheduling SSL Certificate renewal..."
cat << EOF > /etc/cron.daily/certbot_renewal
#!/bin/sh
certbot renew
EOF
chmod +x /etc/cron.daily/certbot_renewal

echo "Restarting nginx..."
systemctl restart nginx

echo "Stopping prior instances..."
ALL_PRIOR_INSTANCES=$(gcloud compute instances list --filter="status=RUNNING AND name~'${INSTANCE_BASE}'" | \
       sed -n '1!p' | \
       cut -d " " -f 1 | \
       grep -v "${INSTANCE_NAME}" )
if [[ -n "${ALL_PRIOR_INSTANCES}" ]];
then
    gcloud compute instances stop ${ALL_PRIOR_INSTANCES} --zone ${ZONE};
else
    echo "No prior instances found for ${INSTANCE_BASE}";
fi