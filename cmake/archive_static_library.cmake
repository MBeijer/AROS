if(NOT DEFINED AROS_CONFIG_BUILD_DIR
   OR NOT DEFINED AROS_TARGET
   OR NOT DEFINED AROS_TOOLCHAIN_DIR
   OR NOT DEFINED AROS_TOOLCHAIN_PREFIX
   OR NOT DEFINED ARCHIVE_OUTPUT
   OR NOT DEFINED OBJECTS_ENCODED)
  message(FATAL_ERROR "Missing required static archive parameters")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/AROSNativeConfig.cmake")

function(_aros_decode_list input_value out_var)
  if("${input_value}" STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  string(REPLACE "|" ";" _decoded "${input_value}")
  set(${out_var} "${_decoded}" PARENT_SCOPE)
endfunction()

function(_aros_unwrap_strip_expression input_value out_var)
  set(_value "${input_value}")
  if(_value MATCHES "^\\$\\(strip[ \t]*(.*)\\)$")
    set(_value "${CMAKE_MATCH_1}")
  endif()
  string(STRIP "${_value}" _value)
  set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

function(_aros_read_config_tokens variable_name out_var)
  _aros_native_config_value("${variable_name}" _value _found)
  if(_found)
    separate_arguments(_tokens NATIVE_COMMAND "${_value}")
    set(${out_var} "${_tokens}" PARENT_SCOPE)
    return()
  endif()
  set(_config_files
    "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
    "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
    "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
    "${AROS_CONFIG_BUILD_DIR}/config/make.cfg"
  )

  foreach(_config_file IN LISTS _config_files)
    if(NOT EXISTS "${_config_file}")
      continue()
    endif()

    file(STRINGS "${_config_file}" _value_line REGEX "^${variable_name}[ \t]*:?=")
    if(_value_line)
      string(REGEX REPLACE "^${variable_name}[ \t]*:?=[ \t]*" "" _value "${_value_line}")
      _aros_unwrap_strip_expression("${_value}" _value)
      if(_value)
        separate_arguments(_tokens NATIVE_COMMAND "${_value}")
        set(${out_var} "${_tokens}" PARENT_SCOPE)
      else()
        set(${out_var} "" PARENT_SCOPE)
      endif()
      return()
    endif()
  endforeach()

  set(${out_var} "" PARENT_SCOPE)
endfunction()

function(_aros_find_toolchain_program tool_name out_var)
  foreach(_candidate IN ITEMS
      "${AROS_TOOLCHAIN_DIR}/${AROS_TOOLCHAIN_PREFIX}-${tool_name}"
      "${AROS_TOOLCHAIN_DIR}/bin/${AROS_TOOLCHAIN_PREFIX}-${tool_name}")
    if(EXISTS "${_candidate}")
      set(${out_var} "${_candidate}" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  set(${out_var} "" PARENT_SCOPE)
endfunction()

_aros_decode_list("${OBJECTS_ENCODED}" _aros_archive_objects)
if(NOT _aros_archive_objects)
  message(FATAL_ERROR "No objects were provided for ${ARCHIVE_OUTPUT}")
endif()

_aros_read_config_tokens("AR_PLAIN" _aros_archive_ar)
_aros_read_config_tokens("RANLIB" _aros_archive_ranlib)
_aros_find_toolchain_program("ar" _aros_archive_ar_fallback)
_aros_find_toolchain_program("ranlib" _aros_archive_ranlib_fallback)

set(_aros_archive_ar_path "")
if(_aros_archive_ar)
  list(GET _aros_archive_ar 0 _aros_archive_ar_path)
endif()
if((NOT _aros_archive_ar OR "${_aros_archive_ar_path}" STREQUAL "" OR NOT EXISTS "${_aros_archive_ar_path}") AND _aros_archive_ar_fallback)
  set(_aros_archive_ar "${_aros_archive_ar_fallback}")
endif()

set(_aros_archive_ranlib_path "")
if(_aros_archive_ranlib)
  list(GET _aros_archive_ranlib 0 _aros_archive_ranlib_path)
endif()
if((NOT _aros_archive_ranlib OR "${_aros_archive_ranlib_path}" STREQUAL "" OR NOT EXISTS "${_aros_archive_ranlib_path}") AND _aros_archive_ranlib_fallback)
  set(_aros_archive_ranlib "${_aros_archive_ranlib_fallback}")
endif()

if(NOT _aros_archive_ar)
  message(FATAL_ERROR "Target ar was not resolved for ${ARCHIVE_OUTPUT}")
endif()
if(NOT _aros_archive_ranlib)
  message(FATAL_ERROR "Target ranlib was not resolved for ${ARCHIVE_OUTPUT}")
endif()

get_filename_component(_aros_archive_output_dir "${ARCHIVE_OUTPUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_aros_archive_output_dir}")
if(EXISTS "${ARCHIVE_OUTPUT}")
  file(REMOVE "${ARCHIVE_OUTPUT}")
endif()

string(JOIN " " _aros_archive_ar_text "${_aros_archive_ar}" cr "${ARCHIVE_OUTPUT}" ${_aros_archive_objects})
message("${_aros_archive_ar_text}")
execute_process(
  COMMAND "${_aros_archive_ar}" cr "${ARCHIVE_OUTPUT}" ${_aros_archive_objects}
  RESULT_VARIABLE _aros_archive_ar_result
)
if(NOT _aros_archive_ar_result EQUAL 0)
  message(FATAL_ERROR "Failed archiving ${ARCHIVE_OUTPUT}")
endif()

string(JOIN " " _aros_archive_ranlib_text "${_aros_archive_ranlib}" "${ARCHIVE_OUTPUT}")
message("${_aros_archive_ranlib_text}")
execute_process(
  COMMAND ${_aros_archive_ranlib} "${ARCHIVE_OUTPUT}"
  RESULT_VARIABLE _aros_archive_ranlib_result
)
if(NOT _aros_archive_ranlib_result EQUAL 0)
  message(FATAL_ERROR "Failed indexing ${ARCHIVE_OUTPUT}")
endif()
