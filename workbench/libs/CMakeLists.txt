cmake_minimum_required(VERSION 3.20)

# workbench/libs migration entrypoint.
set(_aros_workbench_libs_native_modules_default
  "amigaguide;asl;bullet;camd;cgfx;cgxvideo;commodities;coolimages;datatypes;diskfont;gadtools;icon;identify;iffparse;kms;locale;lowlevel;mathffp;mathieeedoubbas;mathieeedoubtrans;mathieeesingbas;mathieeesingtrans;mathtrans;muiscreen;pccard;realtime;reqtools;rexxsupport;rexxsyslib;uuid;version;workbench"
)
set(
  AROS_WORKBENCH_LIBS_NATIVE_MODULES
  "${_aros_workbench_libs_native_modules_default}"
  CACHE STRING
  "Semicolon-separated workbench/libs modules enabled for native CMake migration"
)
set(_aros_workbench_libs_native_modules_legacy_default "gadtools")
set(_aros_workbench_libs_native_modules_previous_default
  "amigaguide;asl;bullet;cgfx;commodities;coolimages;datatypes;diskfont;gadtools;icon;iffparse;locale;rexxsyslib;workbench"
)
set(_aros_workbench_libs_native_modules_previous_default_v2
  "amigaguide;asl;bullet;cgfx;commodities;coolimages;datatypes;diskfont;gadtools;icon;iffparse;locale;lowlevel;realtime;rexxsyslib;workbench"
)
set(_aros_workbench_libs_native_modules_previous_default_v3
  "amigaguide;asl;bullet;cgfx;commodities;coolimages;datatypes;diskfont;gadtools;icon;iffparse;locale;lowlevel;realtime;rexxsyslib;version;workbench"
)
set(_aros_workbench_libs_native_modules_previous_default_v4
  "amigaguide;asl;bullet;cgfx;cgxvideo;commodities;coolimages;datatypes;diskfont;gadtools;icon;iffparse;locale;lowlevel;realtime;rexxsyslib;uuid;version;workbench"
)
set(_aros_workbench_libs_native_modules_previous_default_v5
  "amigaguide;asl;bullet;cgfx;cgxvideo;commodities;coolimages;datatypes;diskfont;gadtools;icon;iffparse;locale;lowlevel;mathffp;mathieeedoubbas;mathieeedoubtrans;mathieeesingbas;mathieeesingtrans;mathtrans;realtime;rexxsyslib;uuid;version;workbench"
)
set(_aros_workbench_libs_native_modules_previous_default_v6
  "amigaguide;asl;bullet;camd;cgfx;cgxvideo;commodities;coolimages;datatypes;diskfont;gadtools;icon;identify;iffparse;locale;lowlevel;mathffp;mathieeedoubbas;mathieeedoubtrans;mathieeesingbas;mathieeesingtrans;mathtrans;realtime;rexxsupport;rexxsyslib;uuid;version;workbench"
)
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_legacy_default}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_previous_default}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_previous_default_v2}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_previous_default_v3}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_previous_default_v4}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_previous_default_v5}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
if(AROS_WORKBENCH_LIBS_NATIVE_MODULES STREQUAL "${_aros_workbench_libs_native_modules_previous_default_v6}")
  set(
    AROS_WORKBENCH_LIBS_NATIVE_MODULES
    "${_aros_workbench_libs_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/libs modules enabled for native CMake migration"
    FORCE
  )
endif()
# START LEGACY: these two adapters still own behavior not translated from their
# manifests (MUI header generation and cgxvideo's compatibility flags).
add_subdirectory(muimaster)
# END LEGACY
foreach(_aros_wb_lib_native_module IN LISTS AROS_WORKBENCH_LIBS_NATIVE_MODULES)
  # Legacy workbench/libs module links resolve through the shared library
  # surface (mui, m, stdlib, crt, ...), unlike many ROM-native modules that
  # intentionally link against stdc.static directly.
  set(AROS_COMPILER_NATIVE_MODULE_LINKLIBS "")
  set(AROS_COMPILER_NATIVE_MODULE_AUTOLIBS
    "mui;arossupport;amiga;m;stdlib;crt;codesets;keymap;expansion;commodities;diskfont;asl;muimaster;datatypes;cybergraphics;workbench;icon;intuition;gadtools;layers;aros;partition;iffparse;graphics;locale;dos;utility;exec;autoinit;libinit"
  )
  if(_aros_wb_lib_native_module STREQUAL "cgxvideo")
    add_subdirectory(cgxvideo)
    continue()
  endif()
  string(REPLACE "/" "-" _aros_wb_lib_target_id "${_aros_wb_lib_native_module}")
  aros_register_mmake_genmodule_module(
    "aros-workbench-libs-${_aros_wb_lib_target_id}-native"
    MODULE_PATH "workbench/libs/${_aros_wb_lib_native_module}"
  )
  if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
    aros_register_legacy_make_target(
      "aros-workbench-libs-${_aros_wb_lib_target_id}"
      "workbench-libs-${_aros_wb_lib_target_id}"
      ${_aros_legacy_crosstools_dep}
    )
  endif()
endforeach()

set(_aros_workbench_libs_complete_native_deps)
foreach(_aros_wb_lib_native_module IN LISTS AROS_WORKBENCH_LIBS_NATIVE_MODULES)
  string(REPLACE "/" "-" _aros_wb_lib_target_id "${_aros_wb_lib_native_module}")
  if(TARGET "aros-workbench-libs-${_aros_wb_lib_target_id}-native")
    list(APPEND _aros_workbench_libs_complete_native_deps
      "aros-workbench-libs-${_aros_wb_lib_target_id}-native"
    )
  endif()
endforeach()

add_custom_target(
  aros-workbench-libs-complete-native
  DEPENDS ${_aros_workbench_libs_complete_native_deps}
)
set_target_properties(aros-workbench-libs-complete-native PROPERTIES FOLDER "aros/workbench")

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
