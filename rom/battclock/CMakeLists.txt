cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-battclock-native
  MODULE_PATH rom/battclock
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-battclock kernel-battclock ${_aros_legacy_crosstools_dep})
endif()
