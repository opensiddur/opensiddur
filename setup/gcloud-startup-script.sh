#!/usr/bin/env bash
# This script is run on the gcloud instance. Be sure to edit the password before running it!
get_metadata() {
curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1?alt=text" -H "Metadata-Flavor: Google"
}

echo "Getting metadata..."
BRANCH=$(get_metadata BRANCH)
PASSWORD=$(get_metadata ADMIN_PASSWORD)
EXIST_MEMORY=$(get_metadata EXIST_MEMORY)
INSTALL_DIR=/usr/local/opensiddur

echo "Setting up the eXist user..."
useradd -c "eXist db"  exist

echo "Downloading prerequisites..."
apt update
apt install -y maven openjdk-8-jdk ant libxml2 libxml2-utils python3-lxml unzip
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

# set production to retrieve backups from master (production), everything else retrieves backups from develop
if [[ $BRANCH == "master" ]];
then
    BACKUP_BASE_BRANCH="master";
else
    BACKUP_BASE_BRANCH="develop";
fi
INSTANCE_BASE=${PROJECT}-${BACKUP_BASE_BRANCH}
echo "My backup base is $BACKUP_BASE_BRANCH"

# retrieve the latest backup from the prior instance
echo "Generating ssh keys..."
ssh-keygen -q -N "" -f ~/.ssh/google_compute_engine

# download the backup from the prior instance
PRIOR_INSTANCE=$(gcloud compute instances list --filter="name~'${INSTANCE_BASE}'" | \
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
    #gcloud compute ssh ${PRIOR_INSTANCE} --zone ${ZONE} --command "sudo rm -fr /tmp/backup.${COMMIT}"
    ( cd /tmp/exist-backup && tar zxvf exist-backup.tar.gz )
    # restore the backup
    echo "Restoring backup..."
    sudo -u exist ant restore

    # remove the backup
    #rm -fr /tmp/exist-backup
else
    echo "No prior instance exists. No backup will be retrieved.";
fi

echo "Starting eXist..."
systemctl start eXist-db

echo "Stopping prior instances..."
ALL_PRIOR_INSTANCES=$(gcloud compute instances list --filter="name~'${INSTANCE_BASE}'" | \
       sed -n '1!p' | \
       cut -d " " -f 1 | \
       grep -v "${INSTANCE_NAME}" )
echo "Not running stop command: gcloud compute instances stop $ALL_PRIOR_INSTANCES"