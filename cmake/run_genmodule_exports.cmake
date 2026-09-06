if(NOT DEFINED AROS_GENMODULE OR AROS_GENMODULE STREQUAL "")
  message(FATAL_ERROR "AROS_GENMODULE is required")
endif()

if(NOT DEFINED MODULE_CONF OR MODULE_CONF STREQUAL "")
  message(FATAL_ERROR "MODULE_CONF is required")
endif()

if(NOT DEFINED MODULE_NAME OR MODULE_NAME STREQUAL "")
  message(FATAL_ERROR "MODULE_NAME is required")
endif()

if(NOT DEFINED MODULE_TYPE OR MODULE_TYPE STREQUAL "")
  message(FATAL_ERROR "MODULE_TYPE is required")
endif()

if(NOT DEFINED AROS_LIST_SEP OR AROS_LIST_SEP STREQUAL "")
  set(AROS_LIST_SEP "__AROS_LIST_SEP__")
endif()

function(_aros_decode_list input_value out_var)
  if(input_value STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
  else()
    string(REPLACE "|" ";" _decoded "${input_value}")
    set(${out_var} "${_decoded}" PARENT_SCOPE)
  endif()
endfunction()

_aros_decode_list("${WRITEINCLUDES_DIRS_ENCODED}" _writeincludes_dirs)
_aros_decode_list("${WRITELIBDEFS_DIRS_ENCODED}" _writelibdefs_dirs)

if(NOT _writeincludes_dirs AND NOT _writelibdefs_dirs)
  message(FATAL_ERROR "At least one genmodule export destination is required")
endif()

foreach(_output_dir IN LISTS _writeincludes_dirs _writelibdefs_dirs)
  if(_output_dir STREQUAL "")
    continue()
  endif()
  file(MAKE_DIRECTORY "${_output_dir}")
endforeach()

foreach(_output_dir IN LISTS _writeincludes_dirs)
  if(_output_dir STREQUAL "")
    continue()
  endif()
  foreach(_include_subdir IN ITEMS proto inline defines clib interface)
    file(MAKE_DIRECTORY "${_output_dir}/${_include_subdir}")
  endforeach()
endforeach()

foreach(_output_dir IN LISTS _writeincludes_dirs)
  if(_output_dir STREQUAL "")
    continue()
  endif()
  execute_process(
    COMMAND "${AROS_GENMODULE}"
            -c "${MODULE_CONF}"
            -d "${_output_dir}"
            writeincludes "${MODULE_NAME}" "${MODULE_TYPE}"
    COMMAND_ECHO STDOUT
    RESULT_VARIABLE _writeincludes_result
  )
  if(NOT _writeincludes_result EQUAL 0)
    message(FATAL_ERROR "genmodule writeincludes failed for ${MODULE_NAME}.${MODULE_TYPE} -> ${_output_dir}")
  endif()
endforeach()

foreach(_output_dir IN LISTS _writelibdefs_dirs)
  if(_output_dir STREQUAL "")
    continue()
  endif()
  execute_process(
    COMMAND "${AROS_GENMODULE}"
            -c "${MODULE_CONF}"
            -d "${_output_dir}"
            writelibdefs "${MODULE_NAME}" "${MODULE_TYPE}"
    COMMAND_ECHO STDOUT
    RESULT_VARIABLE _writelibdefs_result
  )
  if(NOT _writelibdefs_result EQUAL 0)
    message(FATAL_ERROR "genmodule writelibdefs failed for ${MODULE_NAME}.${MODULE_TYPE} -> ${_output_dir}")
  endif()
endforeach()
