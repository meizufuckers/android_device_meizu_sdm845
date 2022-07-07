/*
 * Copyright (C) 2020 The MoKee Open Source Project
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 */

#define LOG_TAG "LightService"

#include "Light.h"

#include <android-base/file.h>
#include <android-base/logging.h>
#include <fstream>

#define PANEL_BRIGHTNESS_PATH     "/sys/class/backlight/panel0-backlight/brightness"
#define MX_LED_BLINK_PATH         "/sys/class/meizu/mx_leds/leds/breath/blink"

#define LED_OFF "0"
#define LED_BLINK "10"

namespace android {
namespace hardware {
namespace light {
namespace V2_0 {
namespace implementation {

static uint32_t rgbToBrightness(const LightState& state) {
    uint32_t color = state.color & 0x00ffffff;
    return ((77 * ((color >> 16) & 0xff)) + (150 * ((color >> 8) & 0xff)) +
            (29 * (color & 0xff))) >> 8;
}

static bool isLit(const LightState& state) {
    return (state.color & 0x00ffffff);
}

Light::Light() {
    auto attnFn(std::bind(&Light::setAttentionLight, this, std::placeholders::_1));
    auto backlightFn(std::bind(&Light::setPanelBacklight, this, std::placeholders::_1));
    auto notifFn(std::bind(&Light::setNotificationLight, this, std::placeholders::_1));
    mLights.emplace(std::make_pair(Type::ATTENTION, attnFn));
    mLights.emplace(std::make_pair(Type::BACKLIGHT, backlightFn));
    mLights.emplace(std::make_pair(Type::NOTIFICATIONS, notifFn));
}

// Methods from ::android::hardware::light::V2_0::ILight follow.
Return<Status> Light::setLight(Type type, const LightState& state) {
    auto it = mLights.find(type);

    if (it == mLights.end()) {
        return Status::LIGHT_NOT_SUPPORTED;
    }

    it->second(state);

    return Status::SUCCESS;
}

Return<void> Light::getSupportedTypes(getSupportedTypes_cb _hidl_cb) {
    std::vector<Type> types;

    for (auto const& light : mLights) {
        types.push_back(light.first);
    }

    _hidl_cb(types);

    return Void();
}

void Light::setAttentionLight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    mAttentionState = state;
    setSpeakerBatteryLightLocked();
}

void Light::setPanelBacklight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);

    uint32_t brightness = rgbToBrightness(state);
    int old_brightness = brightness;

    brightness = 5 + (brightness - 1.0) / (255 - 1) * (1023 - 5);
    if (brightness < 5) {
        brightness = 5;
    }

    LOG(VERBOSE) << "Scaling brightness: " << old_brightness << " => " << brightness;
    android::base::WriteStringToFile(std::to_string(brightness), PANEL_BRIGHTNESS_PATH);
}

void Light::setNotificationLight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    mNotificationState = state;
    setSpeakerBatteryLightLocked();
}

void Light::setSpeakerBatteryLightLocked() {
    if (isLit(mNotificationState)) {
        android::base::WriteStringToFile(LED_BLINK, MX_LED_BLINK_PATH);
    } else if (isLit(mAttentionState)) {
        android::base::WriteStringToFile(LED_BLINK, MX_LED_BLINK_PATH);
    } else {
        android::base::WriteStringToFile(LED_OFF, MX_LED_BLINK_PATH);
    }
}

}  // namespace implementation
}  // namespace V2_0
}  // namespace light
}  // namespace hardware
}  // namespace android
