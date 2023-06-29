/*
 * Copyright (C) 2023 transaero21 <transaero21@elseboot.ru>
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 */

#ifndef __RPMB_H__
#define __RPMB_H__

#define RPMB_PATH "/dev/mz_rpmb_ctl"

#define CMD 0x2a761729

#define UNLOCK_DEVICE 0x21560780
#define LOST_MODE 0x21560781
#define LOCK_MODE 0x21560782
#define GET_RSA_SEED 0x21560783
#define ROOT_DEVICE 0x21560784
#define UNROOT_DEVICE 0x21560785
#define SLOT_WRITE 0x21560786
#define SLOT_READ 0x21560787
#define GET_VERSION 0x21560788
#define LOCK_STATE 0x21560789
#define GET_ROOT_STATE 0x21560790
#define READ_RAC 0x21560791
#define WRITE_RAC 0x21560792
#define CLEAR_RAC 0x21560793
#define VERIFY_DEVICE 0x215607a2

typedef struct rpmb_ctl_head {
    unsigned int opt;
    int retval;
} rpmb_ctl_head;

typedef struct rpmb_slot_info {
    unsigned int slot_offset;
    unsigned int reserve;
    unsigned char nonce[32];
    unsigned char buf[256];
    unsigned char signature[256];
} rpmb_slot_info;

typedef struct rpmb_slot_msg {
    rpmb_ctl_head head;
    rpmb_slot_info info;
} rpmb_slot_msg;

typedef union rpmb_dev_info {
    unsigned char rsa_seed[20];
    unsigned char rsa_signature[256];
    unsigned int api_version;
    unsigned int root_state;
    unsigned int lock_state;
    int verify_device;
} rpmb_dev_info;

typedef struct rpmb_ctl_msg {
    rpmb_ctl_head head;
    rpmb_dev_info info;
} rpmb_ctl_msg;

#endif //__RPMB_H__
