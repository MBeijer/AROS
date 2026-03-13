cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-workbench-libs-diskfont-native
  MODULE_PATH workbench/libs/diskfont
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(
    aros-workbench-libs-diskfont
    workbench-libs-diskfont
    ${_aros_legacy_crosstools_dep}
  )
endif()
