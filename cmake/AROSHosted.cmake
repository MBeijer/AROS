include_guard(GLOBAL)

# This platform profile is deliberately restricted to the first runnable
# milestone. Manifest entrypoints, not OS-local CMake files, select producers.
set(_aros_hosted_supported OFF)
if(AROS_TARGET STREQUAL "linux-x86_64" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux"
   AND CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64" AND NOT CMAKE_CROSSCOMPILING)
  set(_aros_hosted_supported ON)
endif()
option(AROS_BUILD_HOSTED_BOOTSTRAP "Build the CMake-native Linux x86_64 hosted launcher" ${_aros_hosted_supported})
if(NOT AROS_BUILD_HOSTED_BOOTSTRAP)
  return()
endif()
if(NOT _aros_hosted_supported)
  message(FATAL_ERROR "AROS_BUILD_HOSTED_BOOTSTRAP currently requires native Linux x86_64 and AROS_TARGET=linux-x86_64")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/AROSHostTargets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/AROSScriptOutputs.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/AROSKickstart.cmake")
include(CheckIncludeFile)
include(CheckCCompilerFlag)
check_include_file(syscall.h AROS_HOST_HAVE_SYSCALL_H)
check_include_file(sys/syscall.h AROS_HOST_HAVE_SYS_SYSCALL_H)
set(AROS_HOST_SYSCALL_CPPFLAGS "")
if(AROS_HOST_HAVE_SYSCALL_H)
  string(APPEND AROS_HOST_SYSCALL_CPPFLAGS " -DHAVE_SYSCALL_H")
endif()
if(AROS_HOST_HAVE_SYS_SYSCALL_H)
  string(APPEND AROS_HOST_SYSCALL_CPPFLAGS " -DHAVE_SYS_SYSCALL_H")
endif()
check_c_compiler_flag(-mgeneral-regs-only AROS_HOST_HAVE_GENERAL_REGS_ONLY)
if(AROS_HOST_HAVE_GENERAL_REGS_ONLY)
  set(AROS_HOST_GENERAL_REGS_FLAGS "-mgeneral-regs-only")
endif()
set(AROS_HOST_KERNEL_COMPILE_OPTIONS
  -fno-common -fno-stack-protector -DAROS_BUILD_TYPE=AROS_BUILD_TYPE_PERSONAL)
set(AROS_HOST_KERNEL_LINK_OPTIONS -Wl,--hash-style=sysv "-Wl,-rpath,./lib")
aros_add_mmake_host_target(aros-bootstrap-native MMAKE_NAME kernel-bootstrap-hosted
  DEPENDS aros-native-includes HEADER_INTERFACES kernel-exec-includes)
get_target_property(_bootstrap_dir aros-bootstrap-native RUNTIME_OUTPUT_DIRECTORY)
file(RELATIVE_PATH AROS_HOSTED_BOOTARCH "${AROS_NATIVE_SYSTEM_DIR}" "${_bootstrap_dir}")
aros_determine_target_context("${AROS_TARGET}" _arch _cpu _variant _family)
aros_add_mmake_script_output(aros-bootstrap-config-native MMAKE_NAME "boot-${_family}" CONFIGURE_PREVIEW)
aros_register_mmake_kickstart(aros-hosted-kernel-native
  MMAKE_NAME "kernel-link-${_family}" BOOTARCH "${AROS_HOSTED_BOOTARCH}")
add_custom_target(aros-hosted-bootstrap-native DEPENDS aros-bootstrap-native aros-bootstrap-config-native)
set_target_properties(aros-hosted-bootstrap-native PROPERTIES FOLDER "aros/hosted")
add_custom_target(aros-hosted-metadata-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/host-metadata"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_host_metadata.cmake" VERBATIM)
set_target_properties(aros-hosted-metadata-check PROPERTIES FOLDER "aros/tests")
add_custom_target(aros-host-discovery-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/host-discovery"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_host_discovery.cmake" VERBATIM)
set_target_properties(aros-host-discovery-check PROPERTIES FOLDER "aros/tests")
add_custom_target(aros-crt-metadata-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/crt-layers"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_crt_layers.cmake"
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/crt-headers"
    "-DAROS_CC=${_aros_native_target_cc}" "-DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}"
    "-DAROS_SYSROOT=${AROS_NATIVE_DEVELOPER_DIR}"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/native_crt_headers.cmake"
  DEPENDS aros-native-includes VERBATIM)
set_target_properties(aros-crt-metadata-check PROPERTIES FOLDER "aros/tests")
add_custom_target(aros-crt-link-check
  COMMAND "${CMAKE_COMMAND}" "-DAROS_CC=${_aros_native_target_cc}"
    "-DAROS_M_LIBRARY=$<TARGET_PROPERTY:m.library,AROS_MODULE_OUTPUT>"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/native_crt_link.cmake"
  DEPENDS aros-compiler-m-native VERBATIM)
set_target_properties(aros-crt-link-check PROPERTIES FOLDER "aros/tests")
add_custom_target(aros-kickstart-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/kickstart"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_kickstart.cmake" VERBATIM)
set_target_properties(aros-kickstart-check PROPERTIES FOLDER "aros/tests")

add_executable(aros-hosted-kernel-load-test EXCLUDE_FROM_ALL "${CMAKE_SOURCE_DIR}/cmake/tests/hosted_kernel_load.c")
get_target_property(_loader_manifest aros-bootstrap-linklib-native AROS_HOST_MANIFEST)
get_filename_component(_loader_dir "${_loader_manifest}" DIRECTORY)
target_include_directories(aros-hosted-kernel-load-test PRIVATE "${_loader_dir}/include")
target_link_libraries(aros-hosted-kernel-load-test PRIVATE aros-bootstrap-linklib-native)
set_target_properties(aros-hosted-kernel-load-test PROPERTIES FOLDER "aros/tests")
add_custom_target(aros-hosted-kernel-load-check
  COMMAND "$<TARGET_FILE:aros-hosted-kernel-load-test>" "$<TARGET_PROPERTY:aros-hosted-kernel-native,AROS_MODULE_OUTPUT>"
  DEPENDS aros-hosted-kernel-load-test aros-hosted-kernel-native VERBATIM)
set_target_properties(aros-hosted-kernel-load-check PROPERTIES FOLDER "aros/tests")
