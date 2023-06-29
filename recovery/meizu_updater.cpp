/*
 * Copyright (C) 2023 transaero21 <transaero21@elseboot.ru>
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 */

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#include "edify/expr.h"
#include "mz_rpmb.h"
#include "otautil/error_code.h"

Value* getRootStateFn(const char* name, State* state, const std::vector<std::unique_ptr<Expr>>&) {
    rpmb_ctl_msg msg;
    Value* value;
    int fd, ret;

    fd = open(RPMB_PATH, O_RDWR);
    if (fd < 0) {
        return ErrorAbort(state, kFileOpenFailure, "%s() failed to open rpmb: %d!", name, errno);
    }

    msg.head.opt = GET_ROOT_STATE;
    ret = ioctl(fd, CMD, &msg);
    if (ret || msg.head.retval) {
        value = ErrorAbort(state, kVendorFailure, "%s() failed to get root state!", name);
    } else {
        value = StringValue(strdup(msg.info.api_version != 25570739 ? "0" : "1"));
    }

    close(fd);
    return value;
}

Value* clearRootFn(const char* name, State* state, const std::vector<std::unique_ptr<Expr>>&) {
    rpmb_ctl_msg msg;
    Value* value;
    int fd, ret;

    fd = open(RPMB_PATH, O_RDWR);
    if (fd < 0) {
        return ErrorAbort(state, kFileOpenFailure, "%s() failed to open rpmb: %d!", name, errno);
    }

    msg.head.opt = UNROOT_DEVICE;
    ret = ioctl(fd, CMD, &msg);
    if (ret || msg.head.retval) {
        value = ErrorAbort(state, kVendorFailure, "%s() failed to clear root!", name);
    } else {
        msg.head.opt = CLEAR_RAC;
        ret = ioctl(fd, CMD, &msg);
        if (ret || msg.head.retval) {
            value = ErrorAbort(state, kVendorFailure, "%s() failed to clear rac!", name);
        } else {
            value = StringValue(strdup("1"));
        }
    }

    close(fd);
    return value;
}

void Register_librecovery_updater_meizu() {
    RegisterFunction("meizu.get_root_state", getRootStateFn);
    RegisterFunction("meizu.clear_root", clearRootFn);
}
