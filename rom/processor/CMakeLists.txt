cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-processor-native
  MODULE_PATH rom/processor
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/processor_intern.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/defaults.h"
)
