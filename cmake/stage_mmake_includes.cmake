if(NOT DEFINED AROS_SOURCE_DIR
   OR NOT DEFINED AROS_BINARY_DIR
   OR NOT DEFINED AROS_CONFIG_BUILD_DIR
   OR NOT DEFINED AROS_TARGET
   OR NOT DEFINED AROS_NATIVE_INCLUDE_DIR
   OR NOT DEFINED AROS_NATIVE_BUILD_SDKS_DIR
   OR NOT DEFINED MMAKEFILE_PATH
   OR NOT DEFINED INCLUDES_STAMP)
  message(FATAL_ERROR "Missing required generic mmake include staging parameters")
endif()

# Transitional callers can stage the same headers from multiple linklibs.
# Keep their copies atomic with respect to each other until all use native
# shared copy producers instead of this manifest-wide stager.
file(MAKE_DIRECTORY "${AROS_BINARY_DIR}")
file(LOCK "${AROS_BINARY_DIR}/.mmake-includes.lock" GUARD PROCESS TIMEOUT 120)

function(_aros_read_mmake_logical_lines file_path out_var)
  file(STRINGS "${file_path}" _raw_lines)
  set(_logical_lines)
  set(_current "")

  foreach(_raw_line IN LISTS _raw_lines)
    string(REGEX REPLACE "[\r\n]+$" "" _line "${_raw_line}")
    if(_current STREQUAL "")
      set(_current "${_line}")
    else()
      string(APPEND _current " " "${_line}")
    endif()

    if(_current MATCHES "\\\\[ \t]*$")
      string(REGEX REPLACE "\\\\[ \t]*$" "" _current "${_current}")
      string(STRIP "${_current}" _current)
    else()
      string(STRIP "${_current}" _current)
      if(NOT _current STREQUAL "")
        string(REPLACE ";" "\\;" _current "${_current}")
        list(APPEND _logical_lines "${_current}")
      endif()
      set(_current "")
    endif()
  endforeach()

  if(NOT _current STREQUAL "")
    string(STRIP "${_current}" _current)
    string(REPLACE ";" "\\;" _current "${_current}")
    list(APPEND _logical_lines "${_current}")
  endif()

  set(${out_var} "${_logical_lines}" PARENT_SCOPE)
endfunction()

function(_aros_expand_make_tokens input_value current_dir out_var)
  set(_expanded "${input_value}")
  set(_make_gendir "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen")
  set(_limit 32)
  while(_limit GREATER 0)
    math(EXPR _limit "${_limit} - 1")
    string(REGEX MATCH "\\$\\(([A-Za-z0-9_]+)\\)" _match "${_expanded}")
    if(NOT _match)
      break()
    endif()

    set(_var_name "${CMAKE_MATCH_1}")
    if(_var_name STREQUAL "SRCDIR")
      set(_replacement "${AROS_SOURCE_DIR}")
    elseif(_var_name STREQUAL "CURDIR")
      set(_replacement "${current_dir}")
    elseif(_var_name STREQUAL "GENDIR")
      set(_replacement "${_make_gendir}")
    else()
      set(_replacement "")
    endif()

    string(REPLACE "$(${_var_name})" "${_replacement}" _expanded "${_expanded}")
  endwhile()
  set(${out_var} "${_expanded}" PARENT_SCOPE)
endfunction()

function(_aros_copy_matching_headers src_dir dst_dir)
  if(NOT IS_DIRECTORY "${src_dir}")
    return()
  endif()

  file(MAKE_DIRECTORY "${dst_dir}")
  file(GLOB _header_files
    RELATIVE "${src_dir}"
    "${src_dir}/*.h"
    "${src_dir}/*.hpp"
  )
  foreach(_header IN LISTS _header_files)
    get_filename_component(_header_name "${_header}" NAME)
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
              "${src_dir}/${_header}"
              "${dst_dir}/${_header_name}"
      RESULT_VARIABLE _copy_result
    )
    if(NOT _copy_result EQUAL 0)
      message(FATAL_ERROR "Failed copying staged include ${src_dir}/${_header} -> ${dst_dir}/${_header_name}")
    endif()
  endforeach()
endfunction()

function(_aros_stage_copy_includes_mmake mmakefile_path)
  if(NOT EXISTS "${mmakefile_path}")
    return()
  endif()

  get_filename_component(_mmake_dir "${mmakefile_path}" DIRECTORY)
  file(RELATIVE_PATH _current_dir "${AROS_SOURCE_DIR}" "${_mmake_dir}")
  _aros_read_mmake_logical_lines("${mmakefile_path}" _logical_lines)

  foreach(_line IN LISTS _logical_lines)
    if(NOT _line MATCHES "^%copy_includes[ \t]+(.*)$")
      continue()
    endif()

    separate_arguments(_args NATIVE_COMMAND "${CMAKE_MATCH_1}")
    set(_copy_dir "")
    set(_copy_path ".")

    foreach(_arg IN LISTS _args)
      if(_arg MATCHES "^dir=(.*)$")
        set(_copy_dir "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^path=(.*)$")
        set(_copy_path "${CMAKE_MATCH_1}")
      endif()
    endforeach()

    if(_copy_dir STREQUAL "")
      set(_copy_dir ".")
    endif()

    _aros_expand_make_tokens("${_copy_dir}" "${_current_dir}" _copy_dir_expanded)
    _aros_expand_make_tokens("${_copy_path}" "${_current_dir}" _copy_path_expanded)

    if(IS_ABSOLUTE "${_copy_dir_expanded}")
      set(_source_dir "${_copy_dir_expanded}")
    else()
      set(_source_dir "${_mmake_dir}/${_copy_dir_expanded}")
    endif()

    if(DEFINED INCLUDES_SDK AND NOT INCLUDES_SDK STREQUAL "" AND NOT INCLUDES_SDK STREQUAL "public")
      set(_include_root "${AROS_NATIVE_BUILD_SDKS_DIR}/${INCLUDES_SDK}/include")
    else()
      set(_include_root "${AROS_NATIVE_INCLUDE_DIR}")
    endif()

    if(_copy_path_expanded STREQUAL "." OR _copy_path_expanded STREQUAL "")
      set(_dest_dir "${_include_root}")
    else()
      set(_dest_dir "${_include_root}/${_copy_path_expanded}")
    endif()

    _aros_copy_matching_headers("${_source_dir}" "${_dest_dir}")
  endforeach()
endfunction()

_aros_stage_copy_includes_mmake("${MMAKEFILE_PATH}")
file(TOUCH "${INCLUDES_STAMP}")
