include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/AROSMmakeEntrypoints.cmake")

function(aros_register_mmake_kickstart target_name)
  cmake_parse_arguments(KICK "" "MODULE_PATH;MMAKE_NAME;BOOTARCH" "" ${ARGN})
  if(NOT KICK_MODULE_PATH)
    aros_find_mmake_entrypoint(_producer NAMES "${KICK_MMAKE_NAME}" KINDS link_kickstart)
    set(KICK_MODULE_PATH "${_producer_MODULE_PATH}")
  endif()
  set(_work "${CMAKE_BINARY_DIR}/kickstart/${target_name}")
  file(MAKE_DIRECTORY "${_work}")
  set(_context "${_work}/context.cmake")
  file(WRITE "${_context}" "")
  set(AROS_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
  set(AROS_CONFIG_BUILD_DIR "${AROS_LEGACY_BUILD_DIR}")
  set(MODULE_PATH "${KICK_MODULE_PATH}")
  set(MODULE_MMAKE_NAME "${KICK_MMAKE_NAME}")
  aros_find_mmake_manifest("${CMAKE_SOURCE_DIR}/${MODULE_PATH}" MODULE_MMAKEFILE)
  set(_AROS_MMAKE_VAR_KOBJSDIR "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/gen/kobjs")
  set(_AROS_MMAKE_VAR_AROSARCHDIR "${AROS_NATIVE_SYSTEM_DIR}/${KICK_BOOTARCH}")
  foreach(_var IN ITEMS AROS_SOURCE_DIR AROS_CONFIG_BUILD_DIR AROS_TARGET AROS_TARGET_FAMILY
      AROS_NATIVE_CONFIG_FILE
      MODULE_PATH MODULE_MMAKE_NAME MODULE_MMAKEFILE _AROS_MMAKE_VAR_KOBJSDIR _AROS_MMAKE_VAR_AROSARCHDIR)
    file(APPEND "${_context}" "set(${_var} [==[${${_var}}]==])\n")
  endforeach()
  set(_collector "${CMAKE_SOURCE_DIR}/cmake/collect_mmake_kickstart.cmake")
  execute_process(COMMAND "${CMAKE_COMMAND}" "-DCONTEXT_FILE=${_context}" "-DOUTPUT_FILE=${_work}/metadata.tmp.cmake"
    -P "${_collector}" RESULT_VARIABLE _result)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Failed collecting ${KICK_MMAKE_NAME}")
  endif()
  configure_file("${_work}/metadata.tmp.cmake" "${_work}/metadata.cmake" COPYONLY)
  include("${_work}/metadata.cmake")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    ${AROS_NATIVE_CONFIG_FILE}
    "${MODULE_MMAKEFILE}" "${_collector}"
    "${CMAKE_SOURCE_DIR}/cmake/AROSMmakeBuild.cmake"
    "${CMAKE_SOURCE_DIR}/cmake/AROSMmakeFunctions.cmake")
  add_custom_target("${target_name}")
  set_target_properties("${target_name}" PROPERTIES FOLDER "aros/hosted"
    AROS_KICKSTART_METADATA "${_work}/metadata.cmake"
    AROS_MODULE_OUTPUT "${KICKSTART_OUTPUT}")
  set_property(GLOBAL APPEND PROPERTY AROS_KICKSTART_TARGETS "${target_name}")
endfunction()

function(aros_finalize_kickstarts)
  get_property(_targets GLOBAL PROPERTY AROS_KICKSTART_TARGETS)
  foreach(_target IN LISTS _targets)
    get_target_property(_metadata "${_target}" AROS_KICKSTART_METADATA)
    include("${_metadata}")
    set(_deps)
    foreach(_object IN LISTS KICKSTART_OBJECTS)
      get_filename_component(_key "${_object}" NAME_WE)
      get_property(_producer GLOBAL PROPERTY "AROS_KICKSTART_OBJECT_${_key}")
      if(NOT _producer)
        message(FATAL_ERROR "${_target}: no native kickstart object producer for ${_key}")
      endif()
      string(REPLACE "|" ";" _producer "${_producer}")
      list(GET _producer 0 _producer_target)
      list(GET _producer 1 _producer_file)
      if(NOT _producer_file STREQUAL _object)
        message(FATAL_ERROR "${_target}: unexpected object path ${_object}")
      endif()
      list(APPEND _deps "${_producer_target}" "${_producer_file}")
    endforeach()
    _aros_collect_registered_archive_dependencies(_archive_files _archive_targets ${KICKSTART_LIBS})
    set(_toolchain "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}")
    if(NOT _toolchain)
      set(_toolchain "${AROS_CROSSTOOLS_INSTALL_DIR}")
    endif()
    add_custom_command(OUTPUT "${KICKSTART_OUTPUT}"
      COMMAND "${CMAKE_COMMAND}" "-DMETADATA=${_metadata}"
        "-DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}" "-DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}"
        "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
        "-DAROS_TARGET=${AROS_TARGET}" "-DAROS_TOOLCHAIN_DIR=${_toolchain}"
        "-DAROS_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros"
        "-DAROS_NATIVE_PUBLIC_LIB_DIR=${AROS_NATIVE_PUBLIC_LIB_DIR}"
        "-DAROS_NATIVE_PRIVATE_LIB_DIR=${AROS_NATIVE_PRIVATE_LIB_DIR}"
        "-DAROS_NATIVE_REL_LIB_DIR=${AROS_NATIVE_REL_LIB_DIR}"
        -P "${CMAKE_SOURCE_DIR}/cmake/link_kickstart.cmake"
      DEPENDS ${_deps} ${_archive_files} ${_archive_targets} "${_metadata}"
        ${AROS_NATIVE_CONFIG_FILE} "${CMAKE_SOURCE_DIR}/cmake/AROSNativeConfig.cmake"
        "${CMAKE_SOURCE_DIR}/cmake/link_kickstart.cmake"
      COMMENT "Linking native kickstart ${KICKSTART_OUTPUT}" VERBATIM)
    # The command and its file consumer must be registered in the same directory.
    add_custom_target("${_target}-link" DEPENDS "${KICKSTART_OUTPUT}")
    set_target_properties("${_target}-link" PROPERTIES FOLDER "aros/hosted/internal")
    add_dependencies("${_target}" "${_target}-link")
  endforeach()
endfunction()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL aros_finalize_kickstarts)
