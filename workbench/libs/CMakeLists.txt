cmake_minimum_required(VERSION 3.20)

# workbench/libs migration entrypoint.
set(_aros_workbench_libs_native_modules_default "gadtools")
set(
  AROS_WORKBENCH_LIBS_NATIVE_MODULES
  "${_aros_workbench_libs_native_modules_default}"
  CACHE STRING
  "Semicolon-separated workbench/libs modules enabled for native CMake migration"
)
foreach(_aros_wb_lib_native_module IN LISTS AROS_WORKBENCH_LIBS_NATIVE_MODULES)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_wb_lib_native_module}/CMakeLists.txt")
    add_subdirectory("${_aros_wb_lib_native_module}")
  endif()
endforeach()

file(GLOB _aros_workbench_libs_native_interface_mmakefiles
  RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/*/mmakefile.src"
)
set(_aros_workbench_libs_native_interface_modules_default)
foreach(_aros_workbench_libs_mmakefile IN LISTS _aros_workbench_libs_native_interface_mmakefiles)
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_workbench_libs_mmakefile}" _aros_workbench_libs_build_module_lines
    REGEX "^%build_module[^A-Za-z0-9_]"
  )
  if(_aros_workbench_libs_build_module_lines)
    get_filename_component(_aros_workbench_libs_module_name "${_aros_workbench_libs_mmakefile}" DIRECTORY)
    list(APPEND _aros_workbench_libs_native_interface_modules_default "${_aros_workbench_libs_module_name}")
  endif()
endforeach()
list(SORT _aros_workbench_libs_native_interface_modules_default)
set(_aros_workbench_libs_native_interface_modules_legacy_default
  "amigaguide;asl;commodities;datatypes;gadtools;cgfx;icon;locale;rexxsyslib;workbench"
)
set(
  AROS_WORKBENCH_LIBS_NATIVE_INTERFACE_MODULES
  "${_aros_workbench_libs_native_interface_modules_default}"
  CACHE STRING
  "Semicolon-separated workbench/libs modules registered for native interface generation"
)
if(AROS_WORKBENCH_LIBS_NATIVE_INTERFACE_MODULES STREQUAL "${_aros_workbench_libs_native_interface_modules_legacy_default}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_INTERFACE_MODULES
    "${_aros_workbench_libs_native_interface_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules registered for native interface generation"
    FORCE
  )
endif()

add_custom_target(aros-workbench-libs-sdk-interfaces-native)

foreach(_aros_wb_lib_module IN LISTS AROS_WORKBENCH_LIBS_NATIVE_INTERFACE_MODULES)
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_wb_lib_module}/mmakefile.src" _aros_wb_lib_build_module_lines
    REGEX "^%build_module[^A-Za-z0-9_]"
  )
  if(NOT _aros_wb_lib_build_module_lines)
    continue()
  endif()
  string(REPLACE "/" "-" _aros_wb_lib_target_id "${_aros_wb_lib_module}")
  aros_register_mmake_genmodule_module(
    "aros-workbench-libs-${_aros_wb_lib_target_id}-sdk-native"
    MODULE_PATH "workbench/libs/${_aros_wb_lib_module}"
  )
  add_dependencies(
    aros-workbench-libs-sdk-interfaces-native
    "aros-workbench-libs-${_aros_wb_lib_target_id}-sdk-native-interfaces"
  )
endforeach()

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-workbench-libs-complete workbench-libs-complete ${_aros_legacy_crosstools_dep})
endif()
