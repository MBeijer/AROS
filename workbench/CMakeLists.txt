cmake_minimum_required(VERSION 3.20)

# workbench/ migration entrypoint.
# Native workbench/* CMake module conversions should be added here incrementally,
# preserving legacy parity while switching subdirectories one-by-one.
set(_aros_workbench_native_modules_default "libs;hidds")
set(
  AROS_WORKBENCH_NATIVE_MODULES
  "${_aros_workbench_native_modules_default}"
  CACHE STRING
  "Semicolon-separated workbench modules enabled for native CMake migration"
)
if(AROS_WORKBENCH_NATIVE_MODULES STREQUAL "libs")
  set(
    AROS_WORKBENCH_NATIVE_MODULES
    "${_aros_workbench_native_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench modules enabled for native CMake migration"
    FORCE
  )
endif()
foreach(_aros_wb_module IN LISTS AROS_WORKBENCH_NATIVE_MODULES)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_wb_module}/CMakeLists.txt")
    add_subdirectory("${_aros_wb_module}")
  endif()
endforeach()

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-workbench workbench ${_aros_legacy_crosstools_dep})
  aros_register_legacy_make_target(aros-workbench-complete workbench-complete ${_aros_legacy_crosstools_dep})
endif()
