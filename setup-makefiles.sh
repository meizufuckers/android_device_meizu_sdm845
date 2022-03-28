#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

VENDOR=meizu
DEVICE_COMMON=sdm845


MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

ANDROID_ROOT="$MY_DIR"/../../..

HELPER="$ANDROID_ROOT/tools/extract-utils/extract_utils.sh"
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

if [ -z "${1}" ];
then
    setup_vendor "$DEVICE_COMMON" "$VENDOR" "$ANDROID_ROOT" true
    write_headers "m1882 m1892"
    write_makefiles "${MY_DIR}/proprietary-files-sdm845.txt" true
    write_footers
fi

if [ -n "${1}" ];
then
    setup_vendor "${1}" "${VENDOR}" "${ANDROID_ROOT}" false
    write_headers
    write_makefiles "${MY_DIR}/${1}/proprietary-files-${1}.txt" true
    write_footers
fi
