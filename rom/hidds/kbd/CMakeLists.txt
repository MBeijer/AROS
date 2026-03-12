cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-hidd-kbd-native
  MODULE_PATH rom/hidds/kbd
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-hidd-kbd kernel-hidd-kbd ${_aros_legacy_crosstools_dep})
endif()
