#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
# Copyright (C) 2022 Meizu SDM845 Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

MY_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

ANDROID_ROOT="$MY_DIR/../../.."

HELPER="$ANDROID_ROOT/tools/extract-utils/extract_utils.sh"
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

function fixup_filesmap_path() {
    ANDROIDMK=$MY_DIR/../../../vendor/$VENDOR/$DEVICE/Android.mk
    sed -i "s|$DEVICE/radio/filesmap|$DEVICE_COMMON/radio/filesmap|g" $ANDROIDMK
}

setup_vendor $DEVICE_COMMON $VENDOR $ANDROID_ROOT true false
write_headers "m1882 m1892"
write_makefiles $MY_DIR/proprietary-files-sdm845.txt true
write_footers

setup_vendor $DEVICE $VENDOR $ANDROID_ROOT false false
write_headers $DEVICE
append_firmware_calls_to_makefiles
fixup_filesmap_path
write_makefiles $MY_DIR/../$DEVICE/proprietary-files-$DEVICE.txt true
write_footers
