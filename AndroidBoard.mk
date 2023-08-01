#
# Copyright (C) 2023 transaero21 <transaero21@elseboot.ru>
#
# SPDX-License-Identifier: Apache-2.0
#

#----------------------------------------------------------------------
# Copy prebuilt kernel to out directory
#----------------------------------------------------------------------

ifneq ($(TARGET_PREBUILT_KERNEL),)

INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel

$(INSTALLED_KERNEL_TARGET): $(TARGET_PREBUILT_KERNEL)
	cp $(TARGET_PREBUILT_KERNEL) $(PRODUCT_OUT)/kernel

endif
