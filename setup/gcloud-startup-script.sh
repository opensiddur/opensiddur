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
STACK_MEMORY=$(get_metadata STACK_MEMORY)
DYN_EMAIL=$(get_metadata DYN_EMAIL)
DYN_USERNAME=$(get_metadata DYN_USERNAME)
DYN_PASSWORD=$(get_metadata DYN_PASSWORD)
BACKUP_BUCKET_BASE=$(get_metadata BACKUP_BUCKET_BASE)
INSTALL_DIR=/usr/local/opensiddur

echo "Setting up the eXist user..."
useradd -c "eXist db"  exist

echo "Downloading prerequisites..."
# apt is sometimes locked, so we need to wait for any locks to resolve
while [[ -n $(pgrep apt-get) ]]; do sleep 1; done

apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get install -yq ddclient docker.io maven openjdk-8-jdk ant libxml2 libxml2-utils nginx python3-certbot-nginx python3-lxml unzip unattended-upgrades update-notifier-common
update-java-alternatives -s java-1.8.0-openjdk-amd64

echo "Setting up unattended upgrades..."
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "Obtaining opensiddur sources..."
mkdir -p src
cd src
git clone https://github.com/opensiddur/opensiddur.git
cd opensiddur
git checkout ${BRANCH}
export SRC=$(pwd)
cat << EOF > local.build.properties
installdir=${INSTALL_DIR}
max.memory=${EXIST_MEMORY}
stack.memory=${STACK_MEMORY}
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
#!/bin/bash
BASE_DIR=${INSTALL_DIR}/webapp/WEB-INF/data/export
EARLIEST_DATE=\$(date -d "14 days ago" +%Y%m%d)

for backup in \$( \
    find \${BASE_DIR}/full* \
        -maxdepth 0 \
        -type d );
do
    if [[ \$(basename \$backup) < "full\$EARLIEST_DATE" ]];
    then rm -fr \$backup;
    fi;
done

for report in \$( \
    find \${BASE_DIR}/report* \
        -maxdepth 0 \
        -type f );
do
    if [[ \$(basename \$report) < "report-\$EARLIEST_DATE" ]];
    then rm -fr \$report;
    fi;
done
EOF
chmod +x /etc/cron.daily/clean-exist-backups

# get some gcloud metadata:
PROJECT=$(gcloud config get-value project)
INSTANCE_NAME=$(hostname)
ZONE=$(gcloud compute instances list --filter="name=(${INSTANCE_NAME})" --format 'csv[no-heading](zone)')

export DNS_NAME="db-feature.jewishliturgy.org"
BACKUP_CLOUD_BUCKET="${BACKUP_BUCKET_BASE}-feature"
RESTORE_CLOUD_BUCKET="${BACKUP_BUCKET_BASE}-prod";
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

echo "My backup base is $BACKUP_CLOUD_BUCKET"
echo "My restore base is $RESTORE_CLOUD_BUCKET"

# retrieve the latest backup from the prior instance
echo "Generating ssh keys..."
ssh-keygen -q -N "" -f ~/.ssh/google_compute_engine

# produce or download a recent backup
RESTORE_COMPLETE=0
if [[ $BRANCH == "master" ]];
then
    echo "We are in the master branch. Restoring from the existing master branch"

    PRIOR_INSTANCE=$(gcloud compute instances list --filter="status=RUNNING AND name~'${BACKUP_INSTANCE_BASE}'" | \
           sed -n '1!p' | \
           cut -d " " -f 1 | \
           grep -v "${INSTANCE_NAME}" | \
           head -n 1)

    if [[ -n "${PRIOR_INSTANCE}" ]];
    then
      echo "A prior instance ${PRIOR_INSTANCE} exists. Will not retrieve a backup to avoid a freeze. Will try to retrieve from cloud storage."
#        echo "Prior instance ${PRIOR_INSTANCE} exists. Retrieving a backup...";
#        gcloud logging -q write instance "${INSTANCE_NAME}: Restoring backup from the active master branch ${PRIOR_INSTANCE}." --severity=INFO
#        COMMIT=$(git rev-parse --short HEAD)
#
#        echo "Performing a backup on ${PRIOR_INSTANCE}..."
#        gcloud compute ssh ${PRIOR_INSTANCE} --quiet --zone ${ZONE} --command "cd /src/opensiddur && sudo -u exist ant backup-for-upgrade -Dbackup.directory=/tmp/backup.${COMMIT}"
#
#        echo "Copying backup here..."
#        mkdir /tmp/exist-backup
#        gcloud compute scp ${PRIOR_INSTANCE}:/tmp/backup.${COMMIT}/exist-backup.tar.gz /tmp/exist-backup --zone ${ZONE}
#        gcloud compute ssh ${PRIOR_INSTANCE} --zone ${ZONE} --command "sudo rm -fr /tmp/backup.${COMMIT}"
#        ( cd /tmp/exist-backup && tar zxvf exist-backup.tar.gz )
#        RESTORE_COMPLETE=1
    else
        echo "No prior instance exists. Will try to retrieve a backup from cloud storage.";
    fi;
fi;

if [[ ${RESTORE_COMPLETE} == 0 ]];
then
    echo "We are in the $BRANCH branch. Restoring from a recent cloud storage backup of master"
    echo "Finding the most recent backup of master..."
    MOST_RECENT_BACKUP=$(gsutil ls gs://opensiddur-database-backups-prod | tail -n 1)

    echo "Most recent backup is ${MOST_RECENT_BACKUP}"
    if [[ -z "${MOST_RECENT_BACKUP}" ]];
    then
        echo "No viable backup exists. Proceeding without restoring data."
        gcloud logging -q write instance "${INSTANCE_NAME}: No viable backup exists to restore data." --severity=ALERT
    else
        gcloud logging -q write instance "${INSTANCE_NAME}: Restoring backup from cloud storage ${MOST_RECENT_BACKUP}." --severity=INFO
        BACKUP_FILENAME=$(basename ${MOST_RECENT_BACKUP})
        BACKUP_TEMP_DIR=/tmp/backup.master/fullbackup
        mkdir -p ${BACKUP_TEMP_DIR}
        gsutil cp ${MOST_RECENT_BACKUP} ${BACKUP_TEMP_DIR}

        ( cd ${BACKUP_TEMP_DIR} && tar zxvf ${BACKUP_FILENAME} && rm -f ${BACKUP_FILENAME} && \
            sudo chown -R exist:exist /tmp/backup.master )
        ( cd /src/opensiddur && sudo -u exist ant process-backup-for-upgrade -Dbackup.directory=/tmp/backup.master )

        mkdir -p /tmp/exist-backup
        ( cd /tmp/exist-backup && tar zxvf /tmp/backup.master/exist-backup.tar.gz )
        sudo rm -fr /tmp/backup.master
        RESTORE_COMPLETE=1;
    fi;
fi;

if [[ ${RESTORE_COMPLETE} == 1 ]];
then
        # restore the backup
        echo "Restoring backup..."
        sudo -u exist ant restore

        # remove the backup
        rm -fr /tmp/exist-backup
fi;

echo "Installing daily backup copy..."
EXPORT_DIR=${INSTALL_DIR}/webapp/WEB-INF/data/export
cat << EOF > /etc/cron.daily/copy-exist-backups
#!/bin/bash
echo "Starting Open Siddur Daily Backup to Cloud..."

export PATH=\$PATH:/snap/bin

BACKUPS=\$(find ${EXPORT_DIR}/* -maxdepth 0 -type d -newermt \$(date -d "1 day ago" +%Y%m%d))

if [[ -z "\$BACKUPS" ]];
then
gcloud logging -q write instance "${INSTANCE_NAME}: No backup available to write today!" --severity=ALERT
fi

for dir in \$BACKUPS; do
    cd \$dir
    BASENAME=\$(basename \$dir)
    echo "Backing up \$BASENAME to gs://${BACKUP_CLOUD_BUCKET}..."
    tar zcvf \$BASENAME.tar.gz db
    gsutil cp \$BASENAME.tar.gz gs://${BACKUP_CLOUD_BUCKET}
    gcloud logging -q write instance "${INSTANCE_NAME}: Backup \$BASENAME.tar.gz written to gs://${BACKUP_CLOUD_BUCKET}" --severity=INFO
    rm \$dir/\$BASENAME.tar.gz;
done

echo "Daily backup complete."
EOF
chmod +x /etc/cron.daily/copy-exist-backups

echo "Starting eXist..."
systemctl start eXist-db

echo "Wait until eXist-db is up..."
python3 python/wait_for_up.py --host=localhost --port=8080 --timeout=86400

gcloud logging -q write instance "${INSTANCE_NAME}: eXist is up." --severity=INFO

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

gcloud logging -q write instance "${INSTANCE_NAME}: Dynamic DNS propagation for ${DNS_NAME} to ${PUBLIC_IP} has completed successfully." --severity=INFO

echo "Get an SSL certificate..."
if [[ $BRANCH = feature/* ]];
then
    echo "using staging cert for feature branch $BRANCH"
    CERTBOT_DRY_RUN="--test-cert";
else
    CERTBOT_DRY_RUN="";
fi
certbot --nginx -n --domain ${DNS_NAME} --email ${DYN_EMAIL} --no-eff-email --agree-tos --redirect ${CERTBOT_DRY_RUN}

gcloud logging -q write instance "${INSTANCE_NAME}: SSL certificate has been obtained." --severity=INFO

echo "Scheduling SSL Certificate renewal..."
cat << EOF > /etc/cron.daily/certbot_renewal
#!/bin/sh
certbot renew
EOF
chmod +x /etc/cron.daily/certbot_renewal

echo "Restarting nginx..."
systemctl restart nginx

gcloud logging -q write instance "${INSTANCE_NAME}: Web server is up." --severity=INFO

# TODO: only do this if the upgrade is necessary...
echo "Changing JLPTEI schema for v0.12+..."
${INSTALL_DIR}/bin/client.sh -qs -u admin -P "${PASSWORD}" -x "xquery version '3.1'; import module namespace upg12='http://jewishliturgy.org/modules/upgrade12' at 'xmldb:exist:///db/apps/opensiddur-server/modules/upgrade12.xqm'; upg12:upgrade-all()" -ouri=xmldb:exist://localhost:8080/exist/xmlrpc
${INSTALL_DIR}/bin/client.sh -qs -u admin -P "${PASSWORD}" -x "xquery version '3.1'; import module namespace upgrade122='http://jewishliturgy.org/modules/upgrade122' at 'xmldb:exist:///db/apps/opensiddur-server/modules/upgrade122.xqm'; upgrade122:upgrade-all()" -ouri=xmldb:exist://localhost:8080/exist/xmlrpc

echo "Removing stale ssh keys..."
# Note that this will (intentionally) leave the key for the immediate-prior instance
_contains () { # Check if space-separated list $1 contains line $2
echo "$1" | tr ' ' '\n' | grep -F -x -q "$2"
}

RUNNING_INSTANCES=$(gcloud compute instances list | grep RUNNING | cut -f 1 -d " ")
echo "Running instances are ${RUNNING_INSTANCES}"

for FINGERPRINT in $(gcloud compute os-login ssh-keys list ); do
INSTANCE=$(gcloud compute os-login ssh-keys describe --key $FINGERPRINT --format "(key)" | grep "root@" | tr -d ' ' | sed -e "s/root@//g");
if ! _contains "$RUNNING_INSTANCES" "$INSTANCE";
then
  if [[ -n "$INSTANCE" ]];
  then
    echo "Removing ssh key for $INSTANCE"
    gcloud compute os-login ssh-keys remove --key $FINGERPRINT
  fi
fi
done

echo "Stopping prior instances..."
ALL_PRIOR_INSTANCES=$(gcloud compute instances list --filter="status=RUNNING AND name~'${INSTANCE_BASE}'" | \
       sed -n '1!p' | \
       cut -d " " -f 1 | \
       grep -v "${INSTANCE_NAME}" || true )
if [[ -n "${ALL_PRIOR_INSTANCES}" ]];
then
    gcloud compute instances stop ${ALL_PRIOR_INSTANCES} --zone ${ZONE};
else
    echo "No prior instances found for ${INSTANCE_BASE}";
fi

gcloud logging -q write instance "${INSTANCE_NAME}: startup script completed successfully." --severity=INFO
echo "Done."