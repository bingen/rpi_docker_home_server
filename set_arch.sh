#!/bin/bash

ARCH=$1
if [ $# -eq 0 ]; then
    echo "You must pass arch as a parameter"
    exit 1
fi

case ${ARCH} in
    #'rpi') IMAGE='resin/raspberrypi3-debian:latest' ;;
    'rpi')
        IMAGE='arm32v7/debian:stretch'
        ARCH_PREFIX='rpi'
        GO_ARCH='armv6l'
        ;;
    'arm64')
        IMAGE='arm64v7/debian:stretch'
        ARCH_PREFIX='arm64'
        GO_ARCH='arm64'
        ;;
    'amd64')
        IMAGE='debian:stretch'
        ARCH_PREFIX='amd64'
        GO_ARCH='amd64'
        ;;
esac

for i in `find ./ -name Dockerfile.template`; do
    dockerfile=${i/\.template/}
    cp ${i} ${dockerfile}
    sed -i "s/FROM BASE_IMAGE_PLACEHOLDER/FROM ${IMAGE}/g" ${dockerfile}
    sed -i "s/GO_ARCH GO_ARCH_PLACEHOLDER/GO_ARCH ${GO_ARCH}/g" ${dockerfile}
    sed -i "s/bingen\/ARCH_PLACEHOLDER/bingen\/${ARCH_PREFIX}/g" ${dockerfile}
done;
sed -i "s/ARCH_PLACEHOLDER/${ARCH_PREFIX}/g" .env
