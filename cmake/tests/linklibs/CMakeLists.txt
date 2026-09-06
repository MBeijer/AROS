cmake_minimum_required(VERSION 3.20)
project(AROSLinklibFixture C)
include("${AROS_TEST_SOURCE}/cmake/AROSModule.cmake")
set(AROS_TARGET linux-x86_64)
set(AROS_TARGET_FAMILY unix)
set(AROS_CROSSTOOLS_TARGET_CPU test)
set(AROS_LEGACY_BUILD_DIR "${CMAKE_SOURCE_DIR}/config-snapshot")
set(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR "${CMAKE_BINARY_DIR}/toolchain")
set(AROS_NATIVE_PUBLIC_LIB_DIR "${CMAKE_BINARY_DIR}/lib")
set(AROS_NATIVE_BUILD_SDKS_DIR "${CMAKE_BINARY_DIR}/sdks")
set(AROS_NATIVE_PRIVATE_LIB_DIR "${AROS_NATIVE_BUILD_SDKS_DIR}/private/lib")
set(AROS_NATIVE_REL_LIB_DIR "${AROS_NATIVE_BUILD_SDKS_DIR}/rel/lib")
set(AROS_NATIVE_INCLUDE_DIR "${CMAKE_BINARY_DIR}/include")
set(AROS_NATIVE_OUTPUT_ROOT "${CMAKE_BINARY_DIR}/output")
if(TEST_FETCHED_HEADERS)
  include("${AROS_TEST_SOURCE}/cmake/AROSManifests.cmake")
  aros_collect_mmake_manifests(AROS_MMAKE_MANIFESTS)
endif()
file(MAKE_DIRECTORY "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}" "${AROS_NATIVE_INCLUDE_DIR}")
file(CREATE_LINK "${CMAKE_C_COMPILER}" "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}/test-aros-gcc" SYMBOLIC)
file(CREATE_LINK "${CMAKE_AR}" "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}/test-aros-ar" SYMBOLIC)
file(CREATE_LINK "${CMAKE_RANLIB}" "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}/test-aros-ranlib" SYMBOLIC)
add_custom_target(aros-configure)
add_custom_target(aros-native-includes)
set(_header_options)
if(TEST_LEGACY_GENERATED_HEADERS)
  set(_generated "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/library/generated")
  add_custom_command(OUTPUT "${_generated}/fixture-generated.h"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_generated}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      "${CMAKE_SOURCE_DIR}/generated-input.h" "${_generated}/fixture-generated.h"
    DEPENDS "${CMAKE_SOURCE_DIR}/generated-input.h" VERBATIM)
  add_custom_target(fixture-generated DEPENDS "${_generated}/fixture-generated.h")
  set(_header_options LEGACY_GENERATED_HEADERS DEPENDS fixture-generated fixture-core
    "${_generated}/fixture-generated.h")
endif()
aros_register_mmake_linklib(fixture-linklib MODULE_PATH library LIBNAME fixture ${_header_options})
# Publish the interface after its consumer to exercise deferred resolution.
set(_core_header "${AROS_NATIVE_INCLUDE_DIR}/fixture/core.h")
add_custom_command(OUTPUT "${_core_header}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${AROS_NATIVE_INCLUDE_DIR}/fixture"
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_SOURCE_DIR}/core.h" "${_core_header}"
  DEPENDS "${CMAKE_SOURCE_DIR}/core.h" VERBATIM)
add_custom_target(fixture-core DEPENDS "${_core_header}")
set_property(GLOBAL PROPERTY AROS_MODULE_INTERFACE_TARGET_fixture_core_includes fixture-core)
function(register_second_linklib)
  aros_register_mmake_linklib(fixture-second MODULE_PATH library LIBNAME second ${_header_options})
  add_custom_target(fixture-linklibs DEPENDS fixture-linklib fixture-second)
endfunction()
# Program discovery can register another linklib after the first finalizer.
cmake_language(DEFER CALL register_second_linklib)
