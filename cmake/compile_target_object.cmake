if(NOT DEFINED AROS_TOOLCHAIN_DIR
   OR NOT DEFINED AROS_TOOLCHAIN_PREFIX
   OR NOT DEFINED AROS_SYSROOT
   OR NOT DEFINED AROS_NATIVE_INCLUDE_DIR
   OR NOT DEFINED AROS_NATIVE_BUILD_SDKS_DIR
   OR NOT DEFINED OBJECT_SOURCE
   OR NOT DEFINED OBJECT_OUTPUT
   OR NOT DEFINED OBJECT_DEPFILE)
  message(FATAL_ERROR "Missing required generic target-object compile parameters")
endif()

function(_aros_decode_list input_value out_var)
  if("${input_value}" STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  string(REPLACE "|" ";" _decoded "${input_value}")
  set(${out_var} "${_decoded}" PARENT_SCOPE)
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

_aros_find_toolchain_program("gcc" _aros_target_cc)
if(NOT _aros_target_cc)
  message(FATAL_ERROR
    "Target compiler missing under ${AROS_TOOLCHAIN_DIR}. "
    "Expected ${AROS_TOOLCHAIN_PREFIX}-gcc in the toolchain root or bin/ directory."
  )
endif()

_aros_decode_list("${CPPFLAGS_ENCODED}" _aros_cppflags)
_aros_decode_list("${CFLAGS_ENCODED}" _aros_cflags)
_aros_decode_list("${USER_CPPFLAGS_ENCODED}" _aros_user_cppflags)
_aros_decode_list("${USER_CFLAGS_ENCODED}" _aros_user_cflags)
_aros_decode_list("${USER_INCLUDES_ENCODED}" _aros_user_includes)

get_filename_component(_aros_object_output_dir "${OBJECT_OUTPUT}" DIRECTORY)
get_filename_component(_aros_object_depfile_dir "${OBJECT_DEPFILE}" DIRECTORY)
file(MAKE_DIRECTORY "${_aros_object_output_dir}")
file(MAKE_DIRECTORY "${_aros_object_depfile_dir}")

set(_aros_compile_command
  "${_aros_target_cc}"
  "--sysroot=${AROS_SYSROOT}"
)
if(DEFINED AROS_SOURCE_DIR AND NOT AROS_SOURCE_DIR STREQUAL "")
  list(APPEND _aros_compile_command
    "-ffile-prefix-map=${AROS_SOURCE_DIR}/="
    "-fmacro-prefix-map=${AROS_SOURCE_DIR}/="
  )
endif()
if(DEFINED AROS_BINARY_DIR AND NOT AROS_BINARY_DIR STREQUAL "")
  list(APPEND _aros_compile_command
    "-ffile-prefix-map=${AROS_BINARY_DIR}/="
    "-fmacro-prefix-map=${AROS_BINARY_DIR}/="
  )
endif()
list(APPEND _aros_compile_command
  ${_aros_cppflags}
  ${_aros_user_cppflags}
  "-D__AROS_GIMME_DEPRECATED__"
  ${_aros_cflags}
  ${_aros_user_cflags}
  ${_aros_user_includes}
  "-I${AROS_NATIVE_BUILD_SDKS_DIR}/${SDK_NAME}/include"
  "-idirafter" "${AROS_NATIVE_INCLUDE_DIR}"
  "-MMD"
  "-MF" "${OBJECT_DEPFILE}"
  "-c" "${OBJECT_SOURCE}"
  "-o" "${OBJECT_OUTPUT}"
)

string(JOIN " " _aros_compile_command_text ${_aros_compile_command})
message("${_aros_compile_command_text}")

execute_process(
  COMMAND ${_aros_compile_command}
  RESULT_VARIABLE _aros_compile_result
)
if(NOT _aros_compile_result EQUAL 0)
  message(FATAL_ERROR "Failed compiling ${OBJECT_SOURCE}")
endif()
