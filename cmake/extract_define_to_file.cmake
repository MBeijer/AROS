if(NOT DEFINED INPUT_FILE OR NOT DEFINED DEFINE_NAME OR NOT DEFINED OUTPUT_FILE)
  message(FATAL_ERROR "INPUT_FILE, DEFINE_NAME, and OUTPUT_FILE are required")
endif()

if(NOT EXISTS "${INPUT_FILE}")
  message(FATAL_ERROR "Input file not found: ${INPUT_FILE}")
endif()

file(READ "${INPUT_FILE}" _extract_define_source)
string(
  REGEX MATCH
  "#[ \t]*define[ \t]+${DEFINE_NAME}[ \t]+([0-9]+)"
  _extract_define_match
  "${_extract_define_source}"
)
if(NOT _extract_define_match)
  message(FATAL_ERROR "Failed to find ${DEFINE_NAME} in ${INPUT_FILE}")
endif()

get_filename_component(_extract_define_output_dir "${OUTPUT_FILE}" DIRECTORY)
file(MAKE_DIRECTORY "${_extract_define_output_dir}")
file(WRITE "${OUTPUT_FILE}" "${CMAKE_MATCH_1}\n")
