cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-workbench-libs-muiscreen-native
  MODULE_PATH workbench/libs/muiscreen
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(
    aros-workbench-libs-muiscreen
    workbench-libs-muiscreen
    ${_aros_legacy_crosstools_dep}
  )
endif()
