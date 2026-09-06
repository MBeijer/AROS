cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-expansion-native
  MODULE_PATH rom/expansion
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-expansion kernel-expansion ${_aros_legacy_crosstools_dep})
endif()
