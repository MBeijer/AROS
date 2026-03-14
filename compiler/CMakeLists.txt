cmake_minimum_required(VERSION 3.20)

set(_aros_compiler_native_linklibs_legacy_default "amiga;arossupport;stdc-static;libinit;autoinit")
set(_aros_compiler_native_linklibs_older_default "amiga;arossupport;stdc-static")
set(_aros_compiler_native_linklibs_default "amiga;arossupport;stdc-static;autoinit;libinit")
if(DEFINED AROS_COMPILER_NATIVE_LINKLIBS
   AND (AROS_COMPILER_NATIVE_LINKLIBS STREQUAL "${_aros_compiler_native_linklibs_legacy_default}"
        OR AROS_COMPILER_NATIVE_LINKLIBS STREQUAL "${_aros_compiler_native_linklibs_older_default}"))
  set(AROS_COMPILER_NATIVE_LINKLIBS "${_aros_compiler_native_linklibs_default}" CACHE STRING
    "Semicolon-separated compiler linklibs enabled for native CMake migration" FORCE)
endif()
set(
  AROS_COMPILER_NATIVE_LINKLIBS
  "${_aros_compiler_native_linklibs_default}"
  CACHE STRING
  "Semicolon-separated compiler linklibs enabled for native CMake migration"
)
set(_aros_compiler_native_module_linklibs_legacy_default "amiga;arossupport;stdc.static;libinit;autoinit")
set(_aros_compiler_native_module_linklibs_previous_default "amiga;arossupport;stdc.static;autoinit;libinit")
set(_aros_compiler_native_module_linklibs_default "amiga;arossupport;stdc.static;exec;autoinit;libinit")
if(DEFINED AROS_COMPILER_NATIVE_MODULE_LINKLIBS
   AND (AROS_COMPILER_NATIVE_MODULE_LINKLIBS STREQUAL "${_aros_compiler_native_module_linklibs_legacy_default}"
        OR AROS_COMPILER_NATIVE_MODULE_LINKLIBS STREQUAL "${_aros_compiler_native_module_linklibs_previous_default}"))
  set(AROS_COMPILER_NATIVE_MODULE_LINKLIBS "${_aros_compiler_native_module_linklibs_default}" CACHE STRING
    "Semicolon-separated default linklibs added to native genmodule-backed module links" FORCE)
endif()
set(
  AROS_COMPILER_NATIVE_MODULE_LINKLIBS
  "${_aros_compiler_native_module_linklibs_default}"
  CACHE STRING
  "Semicolon-separated default linklibs added to native genmodule-backed module links"
)
set(AROS_COMPILER_NATIVE_MODULE_LINKLIBS "${AROS_COMPILER_NATIVE_MODULE_LINKLIBS}" CACHE INTERNAL
  "Resolved default linklibs added to native genmodule-backed module links" FORCE)
set(_aros_compiler_native_module_autolibs_default
  "mui;arossupport;amiga;codesets;keymap;expansion;commodities;diskfont;asl;muimaster;datatypes;cybergraphics;workbench;icon;intuition;gadtools;layers;aros;partition;iffparse;graphics;locale;dos;utility;exec;autoinit;libinit"
)
set(
  AROS_COMPILER_NATIVE_MODULE_AUTOLIBS
  "${_aros_compiler_native_module_autolibs_default}"
  CACHE STRING
  "Semicolon-separated AROS autolib chain mirrored by native genmodule-backed module links when archives are available"
)
set(AROS_COMPILER_NATIVE_MODULE_AUTOLIBS "${AROS_COMPILER_NATIVE_MODULE_AUTOLIBS}" CACHE INTERNAL
  "Resolved AROS autolib chain mirrored by native genmodule-backed module links when archives are available" FORCE)

add_custom_target(aros-core-linklibs-native)
add_custom_target(aros-core-modules-native)

# Staged AROS float.h exposes FLT_EVAL_METHOD only when ISO C visibility is enabled.
# Legacy compiler/crt builds effectively compile with C99-visible libc headers.
set(_aros_compiler_crt_visibility_defines "__ISO_C_VISIBLE=1999")

foreach(_aros_compiler_linklib IN LISTS AROS_COMPILER_NATIVE_LINKLIBS)
  if(_aros_compiler_linklib STREQUAL "amiga")
    aros_register_mmake_linklib(
      aros-compiler-amiga-linklib-native
      MODULE_PATH compiler/alib
      MMAKE_NAME linklibs-amiga
    )
    add_dependencies(aros-core-linklibs-native aros-compiler-amiga-linklib-native)
  elseif(_aros_compiler_linklib STREQUAL "arossupport")
    aros_register_mmake_linklib(
      aros-compiler-arossupport-linklib-native
      MODULE_PATH compiler/arossupport
      MMAKE_NAME linklibs-arossupport
    )
    add_dependencies(aros-core-linklibs-native aros-compiler-arossupport-linklib-native)
  elseif(_aros_compiler_linklib STREQUAL "stdc-static")
    aros_register_mmake_linklib(
      aros-compiler-stdc-static-linklib-native
      MODULE_PATH compiler/crt
      MMAKE_NAME linklibs-stdc-static
    )
    add_dependencies(aros-core-linklibs-native aros-compiler-stdc-static-linklib-native)
  elseif(_aros_compiler_linklib STREQUAL "libinit")
    aros_register_mmake_linklib(
      aros-compiler-libinit-linklib-native
      MODULE_PATH compiler/libinit
      MMAKE_NAME linklibs-libinit
    )
    add_dependencies(aros-core-linklibs-native aros-compiler-libinit-linklib-native)
  elseif(_aros_compiler_linklib STREQUAL "autoinit")
    aros_register_mmake_linklib(
      aros-compiler-autoinit-linklib-native
      MODULE_PATH compiler/autoinit
      MMAKE_NAME linklibs-autoinit
    )
    add_dependencies(aros-core-linklibs-native aros-compiler-autoinit-linklib-native)
  else()
    message(FATAL_ERROR "Unknown native compiler linklib entry: ${_aros_compiler_linklib}")
  endif()
endforeach()

aros_register_mmake_genmodule_module(
  aros-compiler-m-native
  MODULE_PATH compiler/crt
  MODULE_NAME m
  MODULE_TYPE library
  MMAKEFILE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/crt/mmakefile.src"
  MODULE_CONF "${CMAKE_CURRENT_SOURCE_DIR}/crt/m.conf"
  MMAKE_NAME compiler-m
  COMPILE_DEFINITIONS ${_aros_compiler_crt_visibility_defines}
)
add_dependencies(aros-core-modules-native aros-compiler-m-native)

aros_register_mmake_genmodule_module(
  aros-compiler-stdlib-native
  MODULE_PATH compiler/crt
  MODULE_NAME stdlib
  MODULE_TYPE library
  MMAKEFILE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/crt/mmakefile.src"
  MODULE_CONF "${CMAKE_CURRENT_SOURCE_DIR}/crt/stdlib.conf"
  MMAKE_NAME compiler-stdlib
  COMPILE_DEFINITIONS ${_aros_compiler_crt_visibility_defines}
)
add_dependencies(aros-core-modules-native aros-compiler-stdlib-native)

aros_register_mmake_genmodule_module(
  aros-compiler-crt-native
  MODULE_PATH compiler/crt
  MODULE_NAME crt
  MODULE_TYPE library
  MMAKEFILE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/crt/mmakefile.src"
  MODULE_CONF "${CMAKE_CURRENT_SOURCE_DIR}/crt/crt.conf"
  MMAKE_NAME compiler-crt
  COMPILE_DEFINITIONS ${_aros_compiler_crt_visibility_defines}
)
add_dependencies(aros-core-modules-native aros-compiler-crt-native)
