cmake_minimum_required(VERSION 3.20)

file(GLOB _aros_workbench_hidds_scanned_interface_mmakefiles
  RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/*/mmakefile.src"
)
set(_aros_workbench_hidds_scanned_interface_modules_default)
foreach(_aros_hidd_mmakefile IN LISTS _aros_workbench_hidds_scanned_interface_mmakefiles)
  file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_hidd_mmakefile}" _aros_hidd_build_module_lines
    REGEX "^%build_module[^A-Za-z0-9_]"
  )
  if(_aros_hidd_build_module_lines)
    get_filename_component(_aros_hidd_module_name "${_aros_hidd_mmakefile}" DIRECTORY)
    list(APPEND _aros_workbench_hidds_scanned_interface_modules_default "${_aros_hidd_module_name}")
  endif()
endforeach()
list(SORT _aros_workbench_hidds_scanned_interface_modules_default)
set(_aros_workbench_hidds_interface_modules_default "i2c")
set(
  AROS_WORKBENCH_HIDDS_NATIVE_INTERFACE_MODULES
  "${_aros_workbench_hidds_interface_modules_default}"
  CACHE STRING
  "Semicolon-separated workbench/hidds modules registered for native interface generation"
)
if(AROS_WORKBENCH_HIDDS_NATIVE_INTERFACE_MODULES STREQUAL "${_aros_workbench_hidds_scanned_interface_modules_default}"
   OR AROS_WORKBENCH_HIDDS_NATIVE_INTERFACE_MODULES STREQUAL "i2c;parallel;serial")
  set(
    AROS_WORKBENCH_HIDDS_NATIVE_INTERFACE_MODULES
    "${_aros_workbench_hidds_interface_modules_default}"
    CACHE STRING
    "Semicolon-separated workbench/hidds modules registered for native interface generation"
    FORCE
  )
endif()

foreach(_aros_hidd_module IN LISTS AROS_WORKBENCH_HIDDS_NATIVE_INTERFACE_MODULES)
  if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_hidd_module}/mmakefile.src")
    continue()
  endif()

  aros_register_mmake_genmodule_module(
    "aros-workbench-hidds-${_aros_hidd_module}-sdk-native"
    MODULE_PATH "workbench/hidds/${_aros_hidd_module}"
  )
  if(TARGET aros-sdk-interfaces-native)
    add_dependencies(
      aros-sdk-interfaces-native
      "aros-workbench-hidds-${_aros_hidd_module}-sdk-native-interfaces"
    )
  endif()
endforeach()

aros_register_mmake_hidd_stub_producer(
  aros-workbench-hidds-i2c-stubs-native
  MODULE_PATH "workbench/hidds/i2c/stubs"
  INCLUDES_MMAKEFILE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/i2c/mmakefile.src"
  DEPENDS aros-workbench-hidds-i2c-sdk-native-interfaces
)

aros_register_mmake_hidd_stub_producer(
  aros-workbench-hidds-parallel-stubs-native
  MODULE_PATH "workbench/hidds/parallel"
)

aros_register_mmake_hidd_stub_producer(
  aros-workbench-hidds-serial-stubs-native
  MODULE_PATH "workbench/hidds/serial"
)
