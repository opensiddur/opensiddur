#!/usr/bin/env bash
# This script is run on the gcloud instance. Be sure to edit the password before running it!
get_metadata() {
curl "http://metadata.google.internal/computeMetadata/v1/instance/$1?alt=text" -H "Metadata-Flavor: Google"
}

PASSWORD=$(get_metadata ADMIN_PASSWORD)
EXIST_MEMORY=$(get_metadata EXIST_MEMORY)

useradd -c "eXist db"  exist
apt install -y git maven openjdk-8-jdk ant curl libxml2 libxml2-utils texlive-xetex nginx python3-lxml
mkdir -p src
cd src
git clone git://github.com/opensiddur/opensiddur.git
cd opensiddur
git checkout master
export SRC=$HOME/src/opensiddur
cat << EOF > local.build.properties
installdir=/usr/local/opensiddur
max.memory=${EXIST_MEMORY}
cache.size=512
adminpassword=${PASSWORD}
EOF

ant autodeploy

chown -R exist:exist /usr/local/opensiddur

# install the yajsw script
echo -e "Y\nexist\nY\nn" | tools/yajsw/bin/installDaemon.sh

# install the backup cleaning script
cat << EOF > /etc/cron.daily/clean-exist-backups
#!/bin/sh
find /usr/local/opensiddur/webapp/WEB-INF/data/export/full* \
  -maxdepth 0 \
  -type d \
  -not -newermt `date -d "14 days ago" +%Y%m%d` \
  -execdir rm -fr {} \;

find /usr/local/opensiddur/webapp/WEB-INF/data/export/report* \
  -maxdepth 0 \
  -type d \
  -not -newermt `date -d "14 days ago" +%Y%m%d` \
  -execdir rm -fr {} \;
EOF
chmod +x /etc/cron.daily/clean-exist-backups

systemctl start eXist-db