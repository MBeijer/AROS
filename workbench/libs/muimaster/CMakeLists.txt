cmake_minimum_required(VERSION 3.20)

add_executable(aros-muimaster-buildincludes EXCLUDE_FROM_ALL buildincludes.c)
set_target_properties(aros-muimaster-buildincludes PROPERTIES
  C_STANDARD 99
  C_STANDARD_REQUIRED YES
  C_EXTENSIONS YES
  FOLDER "aros/internal/includes"
)

file(GLOB _aros_mui_header_inputs CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/*.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/classes/*.h"
)
set(_aros_mui_header "${AROS_NATIVE_GENERATED_INCLUDE_DIR}/libraries/mui.h")
aros_add_emit_tool_stdout_file(
  aros-mui-header-native
  OUTPUT "${_aros_mui_header}"
  PROGRAM "$<TARGET_FILE:aros-muimaster-buildincludes>"
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  DEPENDS aros-muimaster-buildincludes ${_aros_mui_header_inputs}
)
set_target_properties(aros-mui-header-native PROPERTIES FOLDER "aros/internal/includes")

# includes-libraries-mui belongs to includes-generate-deps in MetaMake.
add_dependencies(aros-generated-includes-native aros-mui-header-native)
set_property(TARGET aros-generated-includes-native APPEND PROPERTY
  AROS_GENERATED_INCLUDE_FILES "${_aros_mui_header}"
)
