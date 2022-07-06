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

function extract_non_hlos() {
    RADIO_DIR=$MY_DIR/../../../vendor/$VENDOR/$DEVICE
    ANDROIDMK=$RADIO_DIR/Android.mk
    NON_HLOS_PATH=$RADIO_DIR/radio/NON-HLOS.bin
    EXTRACTED_PATH=$RADIO_DIR/non_hlos
    if [ -d $EXTRACTED_PATH ]; then
        rm -rf $EXTRACTED_PATH
    fi
    if [ -f $NON_HLOS_PATH ]; then
        if [ $(stat -c%s $NON_HLOS_PATH) -gt 51199 ]; then
            if [ ! -z $(command -v 7z) ]; then
                mkdir -p $EXTRACTED_PATH
                7z x $NON_HLOS_PATH -o$EXTRACTED_PATH || true
                cat << EOF >> $ANDROIDMK
ifeq (\$(LOCAL_PATH)/non_hlos, \$(wildcard \$(LOCAL_PATH)/non_hlos))

PREBUILT_MODEM := \$(PRODUCT_OUT)/NON-HLOS.bin
ifeq (\$(PREBUILT_MODEM), \$(wildcard \$(PREBUILT_MODEM)))

SCRIPT_DIR := \$(LOCAL_PATH)/../../../device/$VENDOR/$DEVICE_COMMON/radio/scripts

\$(shell \$(SCRIPT_DIR)/fatgen.py --fat16 --name=\$(PREBUILT_MODEM) --size=120 --sectorsize=4096)
\$(shell \$(SCRIPT_DIR)/fatadd.py --name=\$(PREBUILT_MODEM) --from=non_hlos --sectorsize=4096)

\$(call add-radio-file,\$(PREBUILT_MODEM))

endif
endif

EOF
            else
                echo "Unable to find 7z"
            fi
        fi
    else
        echo "Unable to find NON-HLOS.bin at $NON_HLOS_PATH"
    fi
}

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
extract_non_hlos
write_makefiles $MY_DIR/../$DEVICE/proprietary-files-$DEVICE.txt true
write_footers
