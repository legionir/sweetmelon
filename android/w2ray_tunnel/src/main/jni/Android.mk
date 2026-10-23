# hev-socks5-tunnel (https://github.com/heiher/hev-socks5-tunnel), vendored at the commit in
# hev-socks5-tunnel/.rev-id. This file builds only the shared library, as the upstream Android.mk does,
# without its standalone executable. When updating the vendored sources, compare with upstream Android.mk.
TOP_PATH := $(call my-dir)
HEV_PATH := $(TOP_PATH)/hev-socks5-tunnel

include $(HEV_PATH)/third-part/yaml/Android.mk
include $(HEV_PATH)/third-part/lwip/Android.mk
ENABLE_MEMALLOC_SLICE := 0
include $(HEV_PATH)/third-part/hev-task-system/Android.mk

LOCAL_PATH := $(HEV_PATH)
SRCDIR := $(LOCAL_PATH)/src
REV_ID := $(shell cat $(HEV_PATH)/.rev-id)

include $(HEV_PATH)/build.mk
HEV_SRC := $(patsubst $(SRCDIR)/%,src/%,$(SRCFILES))

include $(CLEAR_VARS)
LOCAL_MODULE := hev-socks5-tunnel
LOCAL_SRC_FILES := $(HEV_SRC)
LOCAL_C_INCLUDES := \
    $(HEV_PATH)/src \
    $(HEV_PATH)/src/misc \
    $(HEV_PATH)/src/core/include \
    $(HEV_PATH)/third-part/yaml/include \
    $(HEV_PATH)/third-part/lwip/src/include \
    $(HEV_PATH)/third-part/lwip/src/ports/include \
    $(HEV_PATH)/third-part/hev-task-system/include
LOCAL_CFLAGS += -DFD_SET_DEFINED -DSOCKLEN_T_DEFINED -DENABLE_LIBRARY
LOCAL_CFLAGS += -fno-stack-clash-protection $(VERSION_CFLAGS)
ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
LOCAL_CFLAGS += -mfpu=neon
endif
LOCAL_STATIC_LIBRARIES := yaml lwip hev-task-system
LOCAL_LDFLAGS += -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
include $(BUILD_SHARED_LIBRARY)
