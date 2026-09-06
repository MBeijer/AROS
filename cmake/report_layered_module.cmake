if(NOT DEFINED AROS_SOURCE_DIR OR NOT DEFINED AROS_BINARY_DIR OR NOT DEFINED AROS_TARGET OR NOT DEFINED MODULE_PATH)
  message(FATAL_ERROR "AROS_SOURCE_DIR, AROS_BINARY_DIR, AROS_TARGET, and MODULE_PATH must be defined")
endif()

include("${AROS_SOURCE_DIR}/cmake/AROSLayering.cmake")

set(_module_dir "${AROS_SOURCE_DIR}/${MODULE_PATH}")
if(NOT IS_DIRECTORY "${_module_dir}")
  message(FATAL_ERROR "Module directory not found: ${_module_dir}")
endif()

get_filename_component(_module_name "${MODULE_PATH}" NAME)
set(_module_mmakefile "${_module_dir}/mmakefile.src")
set(_module_mmake_name "")
if(EXISTS "${_module_mmakefile}")
  aros_layering_extract_primary_mmake_name("${_module_mmakefile}" _module_mmake_name)
endif()

aros_layering_get_active_dir_layers(_active_dir_layers)
aros_layering_get_active_alias_layers(_active_alias_layers)

set(_resolved_layer_dirs)
set(_resolved_alias_layers "${_active_alias_layers}")
if(NOT _module_mmake_name STREQUAL "")
  aros_layering_collect_resolved_module_layer_mmakefiles(
    "${_module_name}"
    "${_module_mmake_name}"
    _resolved_layer_mmakefiles
    _resolved_layer_dirs
    _resolved_alias_layers
  )
else()
  set(_resolved_layer_dirs "${_active_dir_layers}")
endif()

file(GLOB _base_files
  RELATIVE "${_module_dir}"
  "${_module_dir}/*.c"
  "${_module_dir}/*.h"
  "${_module_dir}/*.S"
  "${_module_dir}/*.s"
)
list(SORT _base_files)

message(STATUS "Layered module report")
message(STATUS "  target: ${AROS_TARGET}")
message(STATUS "  module: ${MODULE_PATH}")
if(NOT _module_mmake_name STREQUAL "")
  message(STATUS "  mmake:  ${_module_mmake_name}")
endif()

message(STATUS "  active alias targets:")
foreach(_alias IN LISTS _active_alias_layers)
  message(STATUS "    - ${_alias}")
endforeach()

if(NOT _resolved_alias_layers STREQUAL "${_active_alias_layers}")
  message(STATUS "  resolved alias targets:")
  foreach(_alias IN LISTS _resolved_alias_layers)
    message(STATUS "    - ${_alias}")
  endforeach()
endif()

message(STATUS "  active layer dirs:")
foreach(_layer IN LISTS _active_dir_layers)
  set(_layer_module_dir "${AROS_SOURCE_DIR}/arch/${_layer}/${_module_name}")
  if(IS_DIRECTORY "${_layer_module_dir}")
    message(STATUS "    - arch/${_layer}/${_module_name}")
  endif()
endforeach()

message(STATUS "  resolved layer dirs:")
set(_existing_layer_dirs)
foreach(_layer IN LISTS _resolved_layer_dirs)
  set(_layer_module_dir "${AROS_SOURCE_DIR}/arch/${_layer}/${_module_name}")
  if(IS_DIRECTORY "${_layer_module_dir}")
    message(STATUS "    - arch/${_layer}/${_module_name}")
    list(APPEND _existing_layer_dirs "${_layer}")
  endif()
endforeach()

if(NOT _existing_layer_dirs)
  message(STATUS "  no layer directories for module")
  return()
endif()

message(STATUS "  base files overridden by layers:")
set(_override_found FALSE)
foreach(_file IN LISTS _base_files)
  foreach(_layer IN LISTS _existing_layer_dirs)
    set(_candidate "${AROS_SOURCE_DIR}/arch/${_layer}/${_module_name}/${_file}")
    if(EXISTS "${_candidate}")
      set(_override_found TRUE)
      message(STATUS "    - ${_file} -> arch/${_layer}/${_module_name}/${_file}")
      break()
    endif()
  endforeach()
endforeach()
if(NOT _override_found)
  message(STATUS "    (none)")
endif()

message(STATUS "  layer-only source files:")
set(_extra_found FALSE)
foreach(_layer IN LISTS _existing_layer_dirs)
  set(_layer_module_dir "${AROS_SOURCE_DIR}/arch/${_layer}/${_module_name}")
  file(GLOB _layer_files
    RELATIVE "${_layer_module_dir}"
    "${_layer_module_dir}/*.c"
    "${_layer_module_dir}/*.h"
    "${_layer_module_dir}/*.S"
    "${_layer_module_dir}/*.s"
  )
  list(SORT _layer_files)
  foreach(_file IN LISTS _layer_files)
    if(NOT EXISTS "${_module_dir}/${_file}")
      set(_extra_found TRUE)
      message(STATUS "    - arch/${_layer}/${_module_name}/${_file}")
    endif()
  endforeach()
endforeach()
if(NOT _extra_found)
  message(STATUS "    (none)")
endif()
