#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#------------------------------------------------------------------------------

: "${REPO_ROOT_DIR:=`cd $(dirname $0); pwd`}"

echo $REPO_ROOT_DIR

python $REPO_ROOT_DIR/formula_directive.py