#!/usr/bin/env bash
# This script is run on the gcloud instance. Be sure to edit the password before running it!
get_metadata() {
curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1?alt=text" -H "Metadata-Flavor: Google"
}

BRANCH=$(get_metadata BRANCH)
PASSWORD=$(get_metadata ADMIN_PASSWORD)
EXIST_MEMORY=$(get_metadata EXIST_MEMORY)
INSTALL_DIR=/usr/local/opensiddur

useradd -c "eXist db"  exist
apt update
apt install -y maven openjdk-8-jdk ant libxml2 libxml2-utils python3-lxml
update-java-alternatives -s java-1.8.0-openjdk-amd64

mkdir -p src
cd src
git clone git://github.com/opensiddur/opensiddur.git
cd opensiddur
git checkout ${BRANCH}
export SRC=$HOME/src/opensiddur
cat << EOF > local.build.properties
installdir=${INSTALL_DIR}
max.memory=${EXIST_MEMORY}
cache.size=512
adminpassword=${PASSWORD}
EOF

ant autodeploy

chown -R exist:exist ${INSTALL_DIR}

# install the yajsw script
echo -e "Y\nexist\nY\nn" | ${INSTALL_DIR}/tools/yajsw/bin/installDaemon.sh

# install the backup cleaning script
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

systemctl start eXist-db