#!/bin/bash

CART_NAME="foo"
CART_VERSION="0.1"
source /etc/openshift/node.conf

# Import Environment Variables
for f in ~/.env/*; do
    source $f
done

CONFIG_DIR="$CARTRIDGE_BASE_PATH/foo-0.1/info/configuration"

user_build.sh
