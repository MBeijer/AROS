include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/AROSMmakeRules.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/AROSRuntime.cmake")

# Select the hosted runtime slice from upstream's boot configuration, not from
# a list of per-directory CMake registrations. ROM/Workbench still use their
# existing registrations until that broader discovery path is verified.
get_target_property(_boot_config aros-bootstrap-config-native AROS_SCRIPT_PREVIEW)
file(STRINGS "${_boot_config}" _boot_lines REGEX "^[ \t]*module[ \t]+")
get_target_property(_bootstrap_dir aros-bootstrap-native RUNTIME_OUTPUT_DIRECTORY)
file(RELATIVE_PATH _bootarch "${AROS_NATIVE_SYSTEM_DIR}" "${_bootstrap_dir}")
set(_boot_module_paths)
set(_boot_module_names)
foreach(_line IN LISTS _boot_lines)
  string(REGEX REPLACE "^[ \t]*module[ \t]+" "" _path "${_line}")
  string(STRIP "${_path}" _path)
  list(APPEND _boot_module_paths "${_path}")
  get_filename_component(_name "${_path}" NAME)
  string(REGEX REPLACE "([.][^.]+|-handler)$" "" _name "${_name}")
  list(APPEND _boot_module_names "${_name}")
endforeach()
aros_layering_get_active_dir_layers(_layers)
list(APPEND _layers all-hosted)
set(_hosted_manifests)
foreach(_manifest IN LISTS AROS_MMAKE_MANIFESTS)
  file(RELATIVE_PATH _path "${CMAKE_SOURCE_DIR}" "${_manifest}")
  if(_path MATCHES "^arch/([^/]+)/" AND CMAKE_MATCH_1 IN_LIST _layers)
    list(APPEND _hosted_manifests "${_manifest}")
  endif()
endforeach()
aros_discover_genmodule_manifests(_hosted_modules
  MANIFESTS ${_hosted_manifests} MODULE_NAMES ${_boot_module_names})
set(_hosted_targets)
foreach(_module IN LISTS _hosted_modules)
  string(REPLACE "|" ";" _fields "${_module}")
  list(GET _fields 0 _path)
  list(GET _fields 1 _mmake)
  list(GET _fields 2 _name)
  list(GET _fields 3 _type)
  _aros_sanitize_property_key("${_path}:${_name}:${_type}" _key)
  get_property(_target GLOBAL PROPERTY "AROS_REGISTERED_GENMODULE_TARGET_${_key}")
  if(NOT _target)
    set(_target "aros-arch-${_name}-native")
    if(TARGET "${_target}")
      message(FATAL_ERROR "Discovered hosted target name collision for ${_path}: ${_target}")
    endif()
    aros_register_mmake_genmodule_module("${_target}" MODULE_PATH "${_path}" MMAKE_NAME "${_mmake}")
    add_dependencies(aros-sdk-interfaces-native "${_target}-interfaces")
  endif()
  string(REGEX REPLACE "-native$" "" _diagnostic_target "${_target}")
  aros_register_layered_module_sources_target("${_diagnostic_target}-layered-sources" "${_path}")
  aros_add_mmake_static_files("${_target}-static-files"
    MODULE_PATH "${_path}" MMAKE_NAME "${_mmake}")
  add_dependencies("${_target}" "${_target}-static-files")
  list(APPEND _hosted_targets "${_target}")
endforeach()
add_custom_target(aros-hosted-modules-native DEPENDS ${_hosted_targets})
set_target_properties(aros-hosted-modules-native PROPERTIES FOLDER "aros/hosted"
  AROS_BOOT_MODULE_PATHS "${_boot_module_paths}")

add_custom_target(aros-static-files-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/static-files"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_static_files.cmake"
  VERBATIM)
set_target_properties(aros-static-files-check PROPERTIES FOLDER "aros/tests")

function(_aros_finalize_hosted_boot_modules)
  get_target_property(_paths aros-hosted-modules-native AROS_BOOT_MODULE_PATHS)
  aros_add_runtime_module_set(aros-hosted-boot-modules-native
    SYSTEM_DIR "${AROS_NATIVE_SYSTEM_DIR}" MODULE_PATHS ${_paths})
  get_target_property(_outputs aros-hosted-boot-modules-native AROS_RUNTIME_MODULE_OUTPUTS)
  add_custom_target(aros-hosted-boot-load-check
    COMMAND "$<TARGET_FILE:aros-hosted-kernel-load-test>" ${_outputs}
    DEPENDS aros-hosted-kernel-load-test aros-hosted-boot-modules-native
    COMMENT "Checking the complete native boot module set without executing it"
    VERBATIM)
  set_target_properties(aros-hosted-boot-modules-native PROPERTIES FOLDER "aros/hosted")
  set_target_properties(aros-hosted-boot-load-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-hosted-run-verbose
    COMMAND "$<TARGET_FILE:aros-bootstrap-native>" --verbose
    WORKING_DIRECTORY "${AROS_NATIVE_SYSTEM_DIR}"
    DEPENDS aros-hosted-bootstrap-native aros-hosted-boot-modules-native
      aros-core-modules-native aros-programs-native aros-runtime-data-native
    USES_TERMINAL VERBATIM
    COMMENT "Launching the current native hosted runtime with boot diagnostics")
  set_target_properties(aros-hosted-run-verbose PROPERTIES FOLDER "aros/hosted")
endfunction()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _aros_finalize_hosted_boot_modules)

add_custom_target(aros-runtime-graph-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/runtime-graph"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/runtime_module_set.cmake"
  VERBATIM)
set_target_properties(aros-runtime-graph-check PROPERTIES FOLDER "aros/tests")

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  add_custom_target(aros-hosted-boot-trace-check
    COMMAND "${CMAKE_COMMAND}"
      "-DAROS_BOOTSTRAP=$<TARGET_FILE:aros-bootstrap-native>"
      "-DAROS_SYSTEM_DIR=${AROS_NATIVE_SYSTEM_DIR}"
      "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/boot-trace"
      "-DTEST_CC=${CMAKE_C_COMPILER}"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/hosted_boot_trace.cmake"
    DEPENDS aros-bootstrap-native VERBATIM)
  set_target_properties(aros-hosted-boot-trace-check PROPERTIES FOLDER "aros/tests")
endif()
