#
# Copyright (C) 2011 The Android Open Source Project
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

TEST_COMMON_SRC_FILES := \
	src/barrier_test.cc \
	src/base/histogram_test.cc \
	src/base/mutex_test.cc \
	src/base/unix_file/fd_file_test.cc \
	src/base/unix_file/mapped_file_test.cc \
	src/base/unix_file/null_file_test.cc \
	src/base/unix_file/random_access_file_utils_test.cc \
	src/base/unix_file/string_file_test.cc \
	src/class_linker_test.cc \
	src/compiler/driver/compiler_driver_test.cc \
	src/compiler/elf_writer_test.cc \
	src/compiler/jni/jni_compiler_test.cc \
	src/dex_file_test.cc \
	src/dex_instruction_visitor_test.cc \
	src/dex_method_iterator_test.cc \
	src/exception_test.cc \
	src/gc/accounting/space_bitmap_test.cc \
	src/gc/heap_test.cc \
	src/gc/space/space_test.cc \
	src/gtest_test.cc \
	src/image_test.cc \
	src/indenter_test.cc \
	src/indirect_reference_table_test.cc \
	src/intern_table_test.cc \
	src/jni_internal_test.cc \
	src/mirror/dex_cache_test.cc \
	src/mirror/object_test.cc \
	src/oat/utils/arm/managed_register_arm_test.cc \
	src/oat/utils/x86/managed_register_x86_test.cc \
	src/oat_test.cc \
	src/output_stream_test.cc \
	src/reference_table_test.cc \
	src/runtime_support_test.cc \
	src/runtime_test.cc \
	src/thread_pool_test.cc \
	src/utils_test.cc \
	src/verifier/method_verifier_test.cc \
	src/verifier/reg_type_test.cc \
	src/zip_archive_test.cc

ifeq ($(ART_SEA_IR_MODE),true)
TEST_COMMON_SRC_FILES += \
	src/compiler/utils/scoped_hashtable_test.cc
endif

TEST_TARGET_SRC_FILES := \
	$(TEST_COMMON_SRC_FILES)

TEST_HOST_SRC_FILES := \
	$(TEST_COMMON_SRC_FILES) \
	src/oat/utils/x86/assembler_x86_test.cc

ART_HOST_TEST_EXECUTABLES :=
ART_TARGET_TEST_EXECUTABLES :=
ART_HOST_TEST_TARGETS :=
ART_TARGET_TEST_TARGETS :=

ART_TEST_CFLAGS :=
ifeq ($(ART_USE_PORTABLE_COMPILER),true)
  ART_TEST_CFLAGS += -DART_USE_PORTABLE_COMPILER=1
endif

# $(1): target or host
# $(2): file name
define build-art-test
  ifneq ($(1),target)
    ifneq ($(1),host)
      $$(error expected target or host for argument 1, received $(1))
    endif
  endif

  art_target_or_host := $(1)
  art_gtest_filename := $(2)

  art_gtest_name := $$(notdir $$(basename $$(art_gtest_filename)))

  include $(CLEAR_VARS)
  ifeq ($$(art_target_or_host),target)
    include external/stlport/libstlport.mk
  endif

  LOCAL_CPP_EXTENSION := $(ART_CPP_EXTENSION)
  LOCAL_MODULE := $$(art_gtest_name)
  ifeq ($$(art_target_or_host),target)
    LOCAL_MODULE_TAGS := tests
  endif
  LOCAL_SRC_FILES := $$(art_gtest_filename) src/common_test.cc
  LOCAL_C_INCLUDES += $(ART_C_INCLUDES)
  LOCAL_SHARED_LIBRARIES := libartd-compiler libartd
  LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_PATH)/build/Android.common.mk
  LOCAL_ADDITIONAL_DEPENDENCIES += $(LOCAL_PATH)/build/Android.gtest.mk

  # Mac OS linker doesn't understand --export-dynamic.
  ifneq ($(HOST_OS)-$$(art_target_or_host),darwin-host)
    # Allow jni_compiler_test to find Java_MyClassNatives_bar within itself using dlopen(NULL, ...).
    LOCAL_LDFLAGS := -Wl,--export-dynamic -Wl,-u,Java_MyClassNatives_bar -Wl,-u,Java_MyClassNatives_sbar
  endif

  LOCAL_CFLAGS := $(ART_TEST_CFLAGS)
  ifeq ($$(art_target_or_host),target)
    LOCAL_CLANG := $(ART_TARGET_CLANG)
    LOCAL_CFLAGS += $(ART_TARGET_CFLAGS) $(ART_TARGET_DEBUG_CFLAGS)
    LOCAL_SHARED_LIBRARIES += libdl libicuuc libicui18n libnativehelper libstlport libz libcutils
    LOCAL_STATIC_LIBRARIES += libgtest
    LOCAL_MODULE_PATH := $(ART_NATIVETEST_OUT)
    include $(LLVM_DEVICE_BUILD_MK)
    include $(BUILD_EXECUTABLE)
    art_gtest_exe := $$(LOCAL_MODULE_PATH)/$$(LOCAL_MODULE)
    ART_TARGET_TEST_EXECUTABLES += $$(art_gtest_exe)
  else # host
    LOCAL_CLANG := $(ART_HOST_CLANG)
    LOCAL_CFLAGS += $(ART_HOST_CFLAGS) $(ART_HOST_DEBUG_CFLAGS)
    LOCAL_SHARED_LIBRARIES += libicuuc-host libicui18n-host libnativehelper libz-host
    LOCAL_STATIC_LIBRARIES += libcutils
    ifeq ($(HOST_OS),darwin)
      # Mac OS complains about unresolved symbols if you don't include this.
      LOCAL_WHOLE_STATIC_LIBRARIES := libgtest_host
    endif
    include $(LLVM_HOST_BUILD_MK)
    include $(BUILD_HOST_EXECUTABLE)
    art_gtest_exe := $(HOST_OUT_EXECUTABLES)/$$(LOCAL_MODULE)
    ART_HOST_TEST_EXECUTABLES += $$(art_gtest_exe)
  endif
art_gtest_target := test-art-$$(art_target_or_host)-gtest-$$(art_gtest_name)
ifeq ($$(art_target_or_host),target)
.PHONY: $$(art_gtest_target)
$$(art_gtest_target): $$(art_gtest_exe) test-art-target-sync
	adb shell touch $(ART_TEST_DIR)/$$@
	adb shell rm $(ART_TEST_DIR)/$$@
	adb shell chmod 755 $(ART_NATIVETEST_DIR)/$$(notdir $$<)
	adb shell sh -c "$(ART_NATIVETEST_DIR)/$$(notdir $$<) && touch $(ART_TEST_DIR)/$$@"
	$(hide) (adb pull $(ART_TEST_DIR)/$$@ /tmp/ && echo $$@ PASSED) || (echo $$@ FAILED && exit 1)
	$(hide) rm /tmp/$$@

ART_TARGET_TEST_TARGETS += $$(art_gtest_target)
else
.PHONY: $$(art_gtest_target)
$$(art_gtest_target): $$(art_gtest_exe) test-art-host-dependencies
	$$<
	@echo $$@ PASSED

ART_HOST_TEST_TARGETS += $$(art_gtest_target)
endif
endef

ifeq ($(ART_BUILD_TARGET),true)
  $(foreach file,$(TEST_TARGET_SRC_FILES), $(eval $(call build-art-test,target,$(file))))
endif
ifeq ($(ART_BUILD_HOST),true)
  $(foreach file,$(TEST_HOST_SRC_FILES), $(eval $(call build-art-test,host,$(file))))
endif
