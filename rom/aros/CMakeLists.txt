cmake_minimum_required(VERSION 3.20)

set(_aros_abi_file "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/AROS/Prefs/Env-Archive/ABI")

add_custom_command(
  OUTPUT "${_aros_abi_file}"
  COMMAND "${CMAKE_COMMAND}"
          -DINPUT_FILE=${CMAKE_CURRENT_SOURCE_DIR}/arosinquirea.c
          -DDEFINE_NAME=AROS_ABI_VERSION_MAJOR
          -DOUTPUT_FILE=${_aros_abi_file}
          -P "${CMAKE_SOURCE_DIR}/cmake/extract_define_to_file.cmake"
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/arosinquirea.c"
    "${CMAKE_SOURCE_DIR}/cmake/extract_define_to_file.cmake"
  VERBATIM
)

add_custom_target(aros-rom-aros-abi-file-native DEPENDS "${_aros_abi_file}")

aros_register_mmake_genmodule_module(
  aros-rom-aros-native
  MODULE_PATH rom/aros
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/aros_intern.h"
)

add_dependencies(aros-rom-aros-native aros-rom-aros-abi-file-native)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-aros kernel-aros ${_aros_legacy_crosstools_dep})
endif()
