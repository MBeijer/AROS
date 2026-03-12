cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-graphics-native
  MODULE_PATH rom/graphics
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-graphics kernel-graphics ${_aros_legacy_crosstools_dep})
endif()
