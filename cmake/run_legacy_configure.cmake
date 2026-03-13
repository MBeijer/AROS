if(NOT DEFINED AROS_SOURCE_DIR OR AROS_SOURCE_DIR STREQUAL "")
  message(FATAL_ERROR "AROS_SOURCE_DIR is required")
endif()

if(NOT DEFINED AROS_ACTIVE_BUILD_DIR OR AROS_ACTIVE_BUILD_DIR STREQUAL "")
  message(FATAL_ERROR "AROS_ACTIVE_BUILD_DIR is required")
endif()

if(NOT DEFINED AROS_LIST_SEP OR AROS_LIST_SEP STREQUAL "")
  set(AROS_LIST_SEP "__AROS_LIST_SEP__")
endif()

set(_configure_args_encoded "${AROS_CONFIGURE_ARGS_ENCODED}")
if(_configure_args_encoded STREQUAL "")
  set(_configure_args)
else()
  string(REPLACE "${AROS_LIST_SEP}" ";" _configure_args "${_configure_args_encoded}")
endif()

set(_required_outputs_encoded "${AROS_REQUIRED_OUTPUTS_ENCODED}")
if(_required_outputs_encoded STREQUAL "")
  set(_required_outputs)
else()
  string(REPLACE "${AROS_LIST_SEP}" ";" _required_outputs "${_required_outputs_encoded}")
endif()

file(MAKE_DIRECTORY "${AROS_ACTIVE_BUILD_DIR}")

execute_process(
  COMMAND "${AROS_SOURCE_DIR}/configure" ${_configure_args}
  WORKING_DIRECTORY "${AROS_ACTIVE_BUILD_DIR}"
  COMMAND_ECHO STDOUT
  RESULT_VARIABLE _aros_configure_result
)
if(NOT _aros_configure_result EQUAL 0)
  message(FATAL_ERROR "Legacy configure failed in ${AROS_ACTIVE_BUILD_DIR}")
endif()

execute_process(
  COMMAND "${CMAKE_COMMAND}"
          "-DMMAKE_CONFIG_PATH=${AROS_ACTIVE_BUILD_DIR}/mmake.config"
          "-DAROS_SOURCE_DIR=${AROS_SOURCE_DIR}"
          "-DAROS_ACTIVE_BUILD_DIR=${AROS_ACTIVE_BUILD_DIR}"
          -P "${AROS_SOURCE_DIR}/cmake/append_mmake_ignoredirs.cmake"
  COMMAND_ECHO STDOUT
  RESULT_VARIABLE _aros_append_mmake_ignoredirs_result
)
if(NOT _aros_append_mmake_ignoredirs_result EQUAL 0)
  message(FATAL_ERROR "Failed updating mmake ignoredir list for ${AROS_ACTIVE_BUILD_DIR}")
endif()

foreach(_required_output IN LISTS _required_outputs)
  if(NOT EXISTS "${_required_output}")
    message(FATAL_ERROR "Expected legacy configure output was not generated: ${_required_output}")
  endif()
endforeach()
