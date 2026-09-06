cmake_minimum_required(VERSION 3.20)

aros_register_layered_module_sources_target(aros-rom-utility-layered-sources rom/utility)

aros_register_mmake_genmodule_module(
  aros-rom-utility-native
  MODULE_PATH rom/utility
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/intern.h"
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-utility kernel-utility ${_aros_legacy_crosstools_dep})
endif()
