foreach(_name IN ITEMS kernel handler)
  if(_name STREQUAL "kernel")
    set(_path boot/kernel)
  else()
    set(_path L/differently-named-handler)
  endif()
  set(_output "${CMAKE_BINARY_DIR}/runtime/${_path}")
  get_filename_component(_dir "${_output}" DIRECTORY)
  add_custom_command(OUTPUT "${_output}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_dir}"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/${_name}.txt" "${_output}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${_name}.txt" VERBATIM)
  add_custom_target("producer-${_name}" DEPENDS "${_output}")
  set_target_properties("producer-${_name}" PROPERTIES AROS_MODULE_OUTPUT "${_output}")
endforeach()
