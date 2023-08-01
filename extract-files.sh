#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
# Copyright (C) 2022 Meizu SDM845 Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

export VENDOR=meizu
export DEVICE_COMMON=sdm845

MY_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

ANDROID_ROOT="$MY_DIR/../../.."

HELPER="$ANDROID_ROOT/tools/extract-utils/extract_utils.sh"
if [ ! -f $HELPER ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. $HELPER
echo $HELPER
CLEAN_VENDOR=true
SECTION=
KANG=
FIRMWARE=

while [ $# -gt 0 ]; do
    case $1 in
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -s | --section)
            SECTION=$2
            CLEAN_VENDOR=false
            shift
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        *)
            SRC=$1
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case $1 in
    # Vendor modules should only access /data/vendor/*
    etc/vstab_db_0_720p_video_30fps.config | etc/vstab_db_0_4k_video_30fps.config | etc/vstab_db_0_1080p_video_30fps.config | vendor/lib/camera/components/com.arcsoft.node.realtimebokeh.so | vendor/lib/camera/components/com.qti.stats.pdlib.so | vendor/lib/camera/components/com.arcsoft.node.capturebokeh.so | vendor/lib/camera/components/com.arcsoft.node.picauto.so | vendor/lib/camera/components/com.arcsoft.node.hdr.so | vendor/lib/camera/components/com.qti.stats.aec.so | vendor/lib/camera/components/com.arcsoft.node.beauty.so | vendor/lib/camera/components/com.arcsoft.node.smoothtransition.so | vendor/lib/camera/components/com.arcsoft.node.lowlighthdr.so | vendor/lib/camera/components/com.inv.node.eis.so | vendor/lib/libarcsoft_dualcam_refocus.so | vendor/lib/libmms_hal_vstab.so | vendor/lib/hw/com.qti.chi.override.so | vendor/lib/hw/camera.qcom.so)
        sed -i "s|/data/misc/camera|/data/vendor/camx|g" $2
        ;;&
    # Wrap libgui_vendor into libwui
    vendor/lib/camera/components/com.inv.node.eis.so | vendor/lib/libmms_warper_vstab.so | vendor/lib/libmms_hal_vstab.so | vendor/bin/hw/vendor.qti.hardware.qdutils_disp@1.0-service-qti)
        sed -i "s|libgui.so|libwui.so|g" $2
        ;;&
    # Avoid using libshims if possible
    # Remove libandroid.so dependencies in camera stack
    vendor/lib/libmms_warper_vstab.so | vendor/lib/libmms_hal_vstab.so)
        if [ -z $(patchelf --print-needed $2 | grep "libshim_camera.so") ]; then
            patchelf --add-needed "libshim_camera.so" $2
        fi
        patchelf --remove-needed "libandroid.so" $2
        ;;
    # Using sensor blobs from polaris
    vendor/lib/libsensorcal.so | vendor/lib/libsnsdiaglog.so | vendor/lib/sensors.ssc.so | vendor/lib64/libsensorcal.so | vendor/lib64/libsnsdiaglog.so | vendor/lib64/sensors.ssc.so | vendor/bin/sensors.qcom)
        patchelf --replace-needed "libssc.so" "libssc_sensors.so" $2
        ;;
    # Audio: Add libprocessgroup dependency
    vendor/lib/hw/audio.primary.sdm845.so | vendor/lib64/hw/audio.primary.sdm845.so)
        if [ -z $(patchelf --print-needed $2 | grep "libprocessgroup.so") ]; then
            patchelf --add-needed "libprocessgroup.so" $2
        fi
        ;;
    # Remove callback function
    vendor/lib64/hw/fingerprint.goodix.sdm845.so)
        sed -i 's|\xa0\x02\x40\xf9\x29\xff\xff\x97\xe0\x03\x1f\x2a|\xa0\x02\x40\xf9\x1f\x20\x03\xd5\xe0\x03\x1f\x2a|g' $2
        ;;&
    # Remove system only libs deps
    vendor/lib64/libvendor.goodix.hardware.biometrics.fingerprint@2.1.so | vendor/lib64/hw/fingerprint.goodix.sdm845.so)
        patchelf --remove-needed "libbacktrace.so" $2
        patchelf --remove-needed "libunwind.so" $2
        ;;&
    # Bring stock libkeymaster libs for goodix
    vendor/lib64/libsoftkeymasterdevice-goodix.so | vendor/lib64/libkeymaster_portable-goodix.so | vendor/lib64/hw/fingerprint.goodix.sdm845.so | vendor/lib64/libvendor.goodix.hardware.biometrics.fingerprint@2.1.so)
        patchelf --replace-needed "libkeymaster_messages.so" "libkeymaster_messages-goodix.so" $2
        patchelf --replace-needed "libkeymaster_portable.so" "libkeymaster_portable-goodix.so" $2
        patchelf --replace-needed "libsoftkeymasterdevice.so" "libsoftkeymasterdevice-goodix.so" $2
        ;;
    # Remove android.hidl.base@1.0 shims
    vendor/bin/hw/vendor.display.color@1.0-service | vendor/bin/hw/vendor.qti.hardware.qteeconnector@1.0-service | vendor/lib/vendor.display.postproc@1.0_vendor.so)
        patchelf --remove-needed "android.hidl.base@1.0.so" $2
        ;;&
    # Remove libicuuc.so dependencies from QTEE blobs
    vendor/lib/hw/vendor.qti.hardware.qteeconnector@1.0-impl.so | vendor/lib64/hw/vendor.qti.hardware.qteeconnector@1.0-impl.so)
        patchelf --remove-needed "libicuuc.so" $2
        ;;
    # Make QTI SensorsCalibrate HAL load with VNDK 28 libbase
    vendor/lib64/hw/vendor.qti.hardware.sensorscalibrate@1.0-impl.so)
        sed -i "s|libbase.so|libbv28.so|g" $2
        ;;
    esac
}

setup_vendor $DEVICE $VENDOR $ANDROID_ROOT false $CLEAN_VENDOR
extract $MY_DIR/../$DEVICE/proprietary-files-$DEVICE.txt $SRC $KANG $SECTION
extract_firmware $MY_DIR/firmware-files-$DEVICE_COMMON.txt $SRC

setup_vendor $DEVICE_COMMON $VENDOR $ANDROID_ROOT true $CLEAN_VENDOR
extract $MY_DIR/proprietary-files-$DEVICE_COMMON.txt $SRC $KANG $SECTION

"$MY_DIR/setup-makefiles.sh" "$@"
