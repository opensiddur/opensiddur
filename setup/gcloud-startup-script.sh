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
INSTALL_DIR=/usr/local/opensiddur

echo "Setting up the eXist user..."
useradd -c "eXist db"  exist

echo "Downloading prerequisites..."
apt update
export DEBIAN_FRONTEND=noninteractive
apt-get install -yq ddclient maven openjdk-8-jdk ant libxml2 libxml2-utils python3-lxml unzip
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
echo -e "Y\nexist\nY\nn" | ${INSTALL_DIR}/tools/yajsw/bin/installDaemon.sh

echo "Installing periodic backup cleaning..."
cat << EOF > /etc/cron.daily/clean-exist-backups
#!/bin/sh
find ${INSTALL_DIR}/webapp/WEB-INF/data/export/full* \
  -maxdepth 0 \
  -type d \
  -not -newermt `date -d "14 days ago" +%Y%m%d` \
  -execdir rm -fr {} \;

find ${INSTALL_DIR}/webapp/WEB-INF/data/export/report* \
  -maxdepth 0 \
  -type d \
  -not -newermt `date -d "14 days ago" +%Y%m%d` \
  -execdir rm -fr {} \;
EOF
chmod +x /etc/cron.daily/clean-exist-backups

# get some gcloud metadata:
PROJECT=$(gcloud config get-value project)
INSTANCE_NAME=$(hostname)
ZONE=$(gcloud compute instances list --filter="name=(${INSTANCE_NAME})" --format 'csv[no-heading](zone)')

DNS_NAME="db-feature.jewishliturgy.org"
# branch-specific environment settings
if [[ $BRANCH == "master" ]];
then
    BACKUP_BASE_BRANCH="master"
    DNS_NAME="db-prod.jewishliturgy.org";
else
    BACKUP_BASE_BRANCH="develop";
    if [[ $BRANCH == "develop" ]];
    then
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
PRIOR_INSTANCE=$(gcloud compute instances list --filter="name~'${BACKUP_INSTANCE_BASE}'" | \
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

echo "Stopping prior instances..."
ALL_PRIOR_INSTANCES=$(gcloud compute instances list --filter="name~'${INSTANCE_BASE}'" | \
       sed -n '1!p' | \
       cut -d " " -f 1 | \
       grep -v "${INSTANCE_NAME}" )
if [[ -n "${ALL_PRIOR_INSTANCES}" ]];
then
    gcloud compute instances stop ${ALL_PRIOR_INSTANCES} --zone ${ZONE};
else
    echo "No prior instances found for ${INSTANCE_BASE}";
fi