cmake_minimum_required(VERSION 3.20)

set(_aros_kernel_generated_include_dir "${CMAKE_BINARY_DIR}/modules/rom_kernel/genmodule/include")
set(_aros_kernel_private_include_dir "${AROS_NATIVE_BUILD_SDKS_DIR}/private/include")

aros_add_genmodule_exports(
  aros-rom-kernel-clocksource-exports-native
  MODULE_PATH rom/kernel
  CONF_FILE "${CMAKE_CURRENT_SOURCE_DIR}/clocksource.conf"
  MODULE_NAME clocksource
  MODULE_TYPE resource
  WRITEINCLUDES_DIRS
    "${_aros_kernel_generated_include_dir}"
    "${AROS_NATIVE_INCLUDE_DIR}"
    "${_aros_kernel_private_include_dir}"
  WRITELIBDEFS_DIRS
    "${_aros_kernel_generated_include_dir}"
)

aros_register_mmake_genmodule_module(
  aros-rom-kernel-native
  MODULE_PATH rom/kernel
  DEPENDS
    aros-rom-kernel-clocksource-exports-native
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-kernel kernel-kernel ${_aros_legacy_crosstools_dep})
endif()
