#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#------------------------------------------------------------------------------

# Description:
#
# Instructions to be invoked under the build CI pipeline in AzureDevOps.
#
# Builds homebrew formula artifact and copy back from the container to the local
# filesystem. The build pipeline can then save it as an artifact as it sees fit.
#
# Usage:
#
# $ pipeline-formula.sh

IMAGE_NAME=microsoft/sqlcmd:homebrew-builder
: "${REPO_ROOT_DIR:=`cd $(dirname $0); cd ../../../; pwd`}"
DIST_DIR=${REPO_ROOT_DIR}/output/homebrew
CLI_VERSION=0.0.1

mkdir -p ${DIST_DIR}

echo "=========================================================="
echo "CLI_VERSION: ${CLI_VERSION}"
echo "HOMEBREW_UPSTREAM_URL: ${HOMEBREW_UPSTREAM_URL}"
echo "HOMEBREW_BOTTLE_URL: ${HOMEBREW_BOTTLE_URL}"
echo "GO_SQLCMD_SRC_URL: ${GO_SQLCMD_SRC_URL}"
echo "Output location: ${DIST_DIR}"
echo "=========================================================="

docker build --no-cache \
             --build-arg BUILD_DATE="`date -u +"%Y-%m-%dT%H:%M:%SZ"`" \
             --build-arg CLI_VERSION=${CLI_VERSION} \
             --tag ${IMAGE_NAME} \
             ${REPO_ROOT_DIR}

echo "=========================================================="
echo "Done - docker build"
echo "=========================================================="

docker run -di ${IMAGE_NAME}

echo "=========================================================="
echo "Done - docker run -di ${IMAGE_NAME}"
echo "=========================================================="

out=$(docker ps -q --filter "ancestor=$IMAGE_NAME")
containerId=(${out// / })

echo "=========================================================="
echo "out: ${out}"
echo "containerId: ${containerId}"
echo "=========================================================="

docker cp ${REPO_ROOT_DIR}/release/mac/homebrew ${containerId}:./sqlcmd

# -- if no upstream url given, use local source bundle formula `file://` URI --
if  [ -z "$HOMEBREW_UPSTREAM_URL" ] ;
then
    ${REPO_ROOT_DIR}/release/src/pipeline.sh
    mv ${REPO_ROOT_DIR}/output/sqlcmd-${CLI_VERSION}.tar.gz ${DIST_DIR}/sqlcmd.tar.gz
    HOMEBREW_UPSTREAM_URL="sqlcmd.tar.gz"
    echo ${DIST_DIR}/${HOMEBREW_UPSTREAM_URL}
    docker cp ${DIST_DIR}/${HOMEBREW_UPSTREAM_URL} ${containerId}:./sqlcmd/docker
fi

# -- build formula --
docker exec -e "CLI_VERSION"=${CLI_VERSION} \
            -e "HOMEBREW_UPSTREAM_URL"=${HOMEBREW_UPSTREAM_URL} \
            -e "HOMEBREW_BOTTLE_URL"=${HOMEBREW_BOTTLE_URL} \
            -e "GO_SQLCMD_SRC_URL"=${GO_SQLCMD_SRC_URL} \
            ${containerId} ./sqlcmd/docker/run.sh
docker cp ${containerId}:sqlcmd.rb ${DIST_DIR}

# -- include helper install script for local installation --
INSTALL_TPL="#!/usr/bin/env bash\n: \"\${BASE_DIR:=\`cd \$(dirname \$0); pwd\`}\"\
\nsed -i '.tmp' \"s|{{PWD}}|\$BASE_DIR|g\" sqlcmd.rb\
\nif [[ -z \"\$1\"  ]]; then arg=\"--build-from-source\"; else arg=\"\$1\"; fi\
\nHOMEBREW_NO_ENV_FILTERING=1 ACCEPT_EULA=Y brew install \$arg ./sqlcmd.rb --help"
echo -e ${INSTALL_TPL} > ${DIST_DIR}/install.sh
chmod 755 ${DIST_DIR}/install.sh

echo "${DIST_DIR}/"
ls ${DIST_DIR}

echo "=== Done ================================================="
docker rm -f ${containerId}
echo "=========================================================="
