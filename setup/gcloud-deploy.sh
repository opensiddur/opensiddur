#!/bin/bash
# This script is used to deploy from local to gcloud.
# Before running it, you need to have gcloud sdk set up on you machine and provide the appropriate settings in
# gcloud-settings.sh
DIR=$(dirname "${BASH_SOURCE[0]}")
source ${DIR}/gcloud-settings.sh

gcloud beta compute \
    --project=${PROJECT_NAME} instances create ${INSTANCE_NAME} \
    --zone=${ZONE} \
    --machine-type=${MACHINE_TYPE} \
    --network=default \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server \
    --image=${IMAGE} \
    --image-project=${IMAGE_PROJECT} \
    --boot-disk-size=${BOOT_DISK_SIZE_GB}GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=${INSTANCE_NAME} \
    --metadata-from-file startup-script=setup/gcloud-startup-script.sh \
    --metadata ADMIN_PASSWORD=${ADMIN_PASSWORD},EXIST_MEMORY=${EXIST_MEMORY},BRANCH=${BRANCH}

# TODO: copy the old instance database to the new instance
# TODO: point db-dev.jewishliturgy.org to the new instance



