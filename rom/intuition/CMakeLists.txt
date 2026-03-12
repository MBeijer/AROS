cmake_minimum_required(VERSION 3.20)

set(_aros_intuition_generated_dir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/rom/intuition/intuition")
set(_aros_intuition_shutdown_image_h "${_aros_intuition_generated_dir}/shutdown_image.h")

aros_add_emit_tool_stdout_file(
  aros-rom-intuition-generated-native
  OUTPUT "${_aros_intuition_shutdown_image_h}"
  PROGRAM "$<TARGET_FILE:ilbmtoc>"
  COMMAND_ARGS
    "${CMAKE_CURRENT_SOURCE_DIR}/shutdown.ilbm"
  DEPENDS
    ilbmtoc
    "${CMAKE_CURRENT_SOURCE_DIR}/shutdown.ilbm"
)

aros_register_mmake_genmodule_module(
  aros-rom-intuition-native
  MODULE_PATH rom/intuition
  DEPENDS
    aros-rom-intuition-generated-native
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-intuition kernel-intuition ${_aros_legacy_crosstools_dep})
endif()
