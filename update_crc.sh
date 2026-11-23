#!/bin/bash

# Usage update_crc.sh 2.52.0

VERSION="$1"
ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n "$(uname -m)" ;; esac)
OS=$(uname | awk '{print tolower($0)}')

echo "Getting crc version $VERSION..."
#CRC_DL_URL=https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/${VERSION}/crc-"${OS}"-"${ARCH}".tar.xz
CRC_DL_URL=https://developers.redhat.com/content-gateway/rest/mirror/pub/cgw/crc/${VERSION}/crc-"${OS}"-"${ARCH}".tar.xz
curl -LO ${CRC_DL_URL}

echo "Extracting..."
xz -d crc-"${OS}"-"${ARCH}".tar.xz
tar -xvf crc-"${OS}"-"${ARCH}".tar

echo "Moving binary..."
sudo mv -v crc-"${OS}"-"${VERSION}"-${ARCH}/crc /usr/local/bin/crc

echo "Cleaning up..."

rm crc-"${OS}"-"${ARCH}".tar
rm -rf crc-"${OS}"-"${VERSION}"-${ARCH}/

echo "Done. You might want to clean up ~/.crc/cache/"
