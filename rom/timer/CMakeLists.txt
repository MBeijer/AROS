cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-rom-timer-native
  MODULE_PATH rom/timer
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/timer_intern.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/timer_macros.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/timervblank.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/timer_platform.h"
)
