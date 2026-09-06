cmake_minimum_required(VERSION 3.20)

find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(_aros_dos_generated_dir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/rom/dos/dos")
set(_aros_dos_errorlist_h "${_aros_dos_generated_dir}/errorlist.h")
set(_aros_dos_strings_h "${_aros_dos_generated_dir}/strings.h")

aros_add_emit_tool_stdout_file(
  aros-rom-dos-generated-native
  OUTPUT "${_aros_dos_errorlist_h}"
  PROGRAM "${Python3_EXECUTABLE}"
  COMMAND_ARGS
    "${CMAKE_CURRENT_SOURCE_DIR}/genstrings.py"
    "${CMAKE_CURRENT_SOURCE_DIR}/catalogs/dos.cd"
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/catalogs/dos.cd"
    "${CMAKE_CURRENT_SOURCE_DIR}/genstrings.py"
)

aros_add_flexcat_header(
  aros-rom-dos-strings-header-native
  OUTPUT "${_aros_dos_strings_h}"
  CD_FILE "${CMAKE_CURRENT_SOURCE_DIR}/catalogs/dos.cd"
  SOURCE_DESCRIPTION "${CMAKE_SOURCE_DIR}/tools/flexcat/src/sd/C_h_aros.sd"
)

aros_register_mmake_linklib(
  aros-rom-dos-loadseg-linklib-native
  MODULE_PATH rom/dos
  LIBNAME loadseg
)

aros_register_mmake_genmodule_module(
  aros-rom-dos-native
  MODULE_PATH rom/dos
  DEPENDS
    aros-rom-dos-generated-native
    aros-rom-dos-strings-header-native
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom-dos kernel-dos ${_aros_legacy_crosstools_dep})
endif()
