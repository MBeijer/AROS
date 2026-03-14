cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-workbench-libs-mathtrans-native
  MODULE_PATH workbench/libs/mathtrans
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(
    aros-workbench-libs-mathtrans
    workbench-libs-mathtrans
    ${_aros_legacy_crosstools_dep}
  )
endif()
