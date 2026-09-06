if(DEFINED COMMAND_PROGRAM AND NOT COMMAND_PROGRAM STREQUAL "")
  set(PROGRAM "${COMMAND_PROGRAM}")
endif()

if(NOT DEFINED PROGRAM OR PROGRAM STREQUAL "")
  message(FATAL_ERROR "PROGRAM or COMMAND_PROGRAM is required")
endif()

if(NOT DEFINED OUTPUT_FILE OR OUTPUT_FILE STREQUAL "")
  message(FATAL_ERROR "OUTPUT_FILE is required")
endif()

set(_command_args)
if(DEFINED COMMAND_ARGS AND NOT COMMAND_ARGS STREQUAL "")
  string(REPLACE "|" ";" _command_args "${COMMAND_ARGS}")
elseif(DEFINED INPUT_FILE AND NOT INPUT_FILE STREQUAL "")
  set(_command_args "${INPUT_FILE}")
endif()

get_filename_component(_output_dir "${OUTPUT_FILE}" DIRECTORY)
file(MAKE_DIRECTORY "${_output_dir}")

set(_working_directory_args)
if(DEFINED WORKING_DIRECTORY AND NOT WORKING_DIRECTORY STREQUAL "")
  list(APPEND _working_directory_args WORKING_DIRECTORY "${WORKING_DIRECTORY}")
endif()

execute_process(
  COMMAND "${PROGRAM}" ${_command_args}
  ${_working_directory_args}
  OUTPUT_FILE "${OUTPUT_FILE}.tmp"
  RESULT_VARIABLE _tool_result
)

if(NOT _tool_result EQUAL 0)
  file(REMOVE "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}")
  message(FATAL_ERROR "Failed generating ${OUTPUT_FILE} with ${PROGRAM}")
endif()
file(RENAME "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}")
