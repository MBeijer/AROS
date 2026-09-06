cmake_minimum_required(VERSION 3.20)

set(_aros_dosboot_generated_dir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/rom/dosboot/dosboot")
set(_aros_dosboot_nomedia_image_h "${_aros_dosboot_generated_dir}/nomedia_image.h")

aros_add_emit_tool_stdout_file(
  aros-rom-dosboot-generated-native
  OUTPUT "${_aros_dosboot_nomedia_image_h}"
  PROGRAM "$<TARGET_FILE:ilbmtoc>"
  COMMAND_ARGS
    "${CMAKE_CURRENT_SOURCE_DIR}/nomedia.ilbm"
  DEPENDS
    ilbmtoc
    "${CMAKE_CURRENT_SOURCE_DIR}/nomedia.ilbm"
)

aros_register_mmake_genmodule_module(
  aros-rom-dosboot-native
  MODULE_PATH rom/dosboot
  DEPENDS
    aros-rom-dosboot-generated-native
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-dosboot kernel-dosboot ${_aros_legacy_crosstools_dep})
endif()
