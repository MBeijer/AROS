cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-debug-native
  MODULE_PATH rom/debug
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/debug_intern.h"
)
