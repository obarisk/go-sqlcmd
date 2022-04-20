#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#------------------------------------------------------------------------------

# Description:
#
# Instructions to be invoked under the build CI pipeline in AzureDevOps.
#
# Build and save the `sqlcmd` image into the bundle:
<<<<<<< HEAD
# `docker-sqlcmd-${PACKAGE_VERSION}.tar`
=======
# `sqlcmd-docker-${PACKAGE_VERSION}.tar`
>>>>>>> main
#
# Usage:
#
# export BUILD_NUMBER=12345  (optional - used to identify the IMAGE_NAME)
# $ pipeline.sh

: "${REPO_ROOT_DIR:=`cd $(dirname $0); cd ../../../; pwd`}"
DIST_DIR=${BUILD_STAGINGDIRECTORY:=${REPO_ROOT_DIR}/output/docker}
IMAGE_NAME=microsoft/sqlcmd${BUILD_BUILDNUMBER:=''}

<<<<<<< HEAD
cp ${BUILD_OUTPUT}/SqlcmdLinuxAmd64/sqlcmd ${REPO_ROOT_DIR}/sqlcmd

chmod u+x ${REPO_ROOT_DIR}/sqlcmd

PACKAGE_VERSION=${PACKAGE_VERSION:=0.0.1}

echo "=========================================================="
echo "PACKAGE_VERSION: ${PACKAGE_VERSION}"
=======
if [[ "${BUILD_OUTPUT}" != "" ]]; then
    cp ${BUILD_OUTPUT}/SqlcmdLinuxAmd64/sqlcmd ${REPO_ROOT_DIR}/sqlcmd
fi

chmod u+x ${REPO_ROOT_DIR}/sqlcmd

PACKAGE_VERSION=${CLI_VERSION:=0.0.1}
PACKAGE_VERSION_REVISION=${CLI_VERSION_REVISION:=1}

echo "=========================================================="
echo "PACKAGE_VERSION: ${PACKAGE_VERSION}"
echo "PACKAGE_VERSION_REVISION: ${PACKAGE_VERSION_REVISION}"
>>>>>>> main
echo "IMAGE_NAME: ${IMAGE_NAME}"
echo "Output location: ${DIST_DIR}"
echo "=========================================================="

docker build --no-cache \
             --build-arg BUILD_DATE="`date -u +"%Y-%m-%dT%H:%M:%SZ"`" \
             --build-arg PACKAGE_VERSION=${PACKAGE_VERSION} \
<<<<<<< HEAD
=======
             --build-arg PACKAGE_VERSION_REVISION=${PACKAGE_VERSION_REVISION} \
>>>>>>> main
             --tag ${IMAGE_NAME}:latest \
             ${REPO_ROOT_DIR}

echo "=========================================================="
echo "Done - docker build"
echo "=========================================================="

mkdir -p ${DIST_DIR} || exit 1
<<<<<<< HEAD
docker save -o "${DIST_DIR}/docker-sqlcmd-${PACKAGE_VERSION}.tar" ${IMAGE_NAME}:latest
=======
docker save -o "${DIST_DIR}/sqlcmd-docker-${PACKAGE_VERSION}-${PACKAGE_VERSION_REVISION}.tar" ${IMAGE_NAME}:latest
>>>>>>> main

echo "=========================================================="
echo "Done - docker save"
echo "=========================================================="

echo "=== Done ================================================="
docker rmi -f ${IMAGE_NAME}:latest
ls ${DIST_DIR}
echo "=========================================================="
