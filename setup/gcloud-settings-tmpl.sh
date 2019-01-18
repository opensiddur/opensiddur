#!/bin/bash -x
# settings needed for gcloud.
# To use this, copy it to gcloud-settings.sh and set the values
VERSION=$(git rev-parse --short HEAD)
PROJECT_NAME=opensiddur
INSTANCE_NAME=opensiddur-server-${VERSION}
ZONE=us-west2-a
MACHINE_TYPE=n1-standard-1
IMAGE=ubuntu-1804-bionic-v20181222
IMAGE_PROJECT=ubuntu-os-cloud
BOOT_DISK_SIZE_GB=20

EXIST_MEMORY=3072
# change this!
ADMIN_PASSWORD=$(echo "***You need to set a password***" && exit 1)