if(NOT DEFINED MMAKE_CONFIG_PATH OR MMAKE_CONFIG_PATH STREQUAL "")
  message(FATAL_ERROR "MMAKE_CONFIG_PATH is required")
endif()

if(NOT EXISTS "${MMAKE_CONFIG_PATH}")
  message(FATAL_ERROR "mmake config not found: ${MMAKE_CONFIG_PATH}")
endif()

if(NOT DEFINED AROS_SOURCE_DIR OR AROS_SOURCE_DIR STREQUAL "")
  message(FATAL_ERROR "AROS_SOURCE_DIR is required")
endif()

file(READ "${MMAKE_CONFIG_PATH}" _mmake_config_text)

set(_ignore_names)

# Always ignore the active build-dir basename.
if(DEFINED AROS_ACTIVE_BUILD_DIR AND NOT AROS_ACTIVE_BUILD_DIR STREQUAL "")
  get_filename_component(_active_build_basename "${AROS_ACTIVE_BUILD_DIR}" NAME)
  if(NOT _active_build_basename STREQUAL "")
    list(APPEND _ignore_names "${_active_build_basename}")
  endif()
endif()

# Ignore common CMake build dir names present in the source tree so stale
# build artifacts cannot be mistaken for source modules by MetaMake scans.
file(GLOB _source_cmake_build_dirs RELATIVE "${AROS_SOURCE_DIR}" "${AROS_SOURCE_DIR}/cmake-build*")
foreach(_dir_rel IN LISTS _source_cmake_build_dirs)
  if(NOT _dir_rel STREQUAL "")
    list(APPEND _ignore_names "${_dir_rel}")
  endif()
endforeach()

list(REMOVE_DUPLICATES _ignore_names)

set(_updated FALSE)
foreach(_ignore_name IN LISTS _ignore_names)
  if(NOT _mmake_config_text MATCHES "(^|\\n)ignoredir[ \t]+${_ignore_name}(\\n|$)")
    string(APPEND _mmake_config_text "ignoredir ${_ignore_name}\n")
    set(_updated TRUE)
  endif()
endforeach()

if(_updated)
  file(WRITE "${MMAKE_CONFIG_PATH}" "${_mmake_config_text}")
endif()
