cmake_minimum_required(VERSION 3.20)

project(AROS LANGUAGES C CXX)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "cmake")

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  message(FATAL_ERROR "In-source builds are not supported. Use: cmake -S . -B <build-dir>")
endif()

set(AROS_TARGET "linux-x86_64" CACHE STRING "AROS configure target (for example linux-x86_64, amiga-m68k)")
set(_aros_configure_args_default "$ENV{EXTRA_CONFIGURE_OPTS}")
set(AROS_CONFIGURE_ARGS "${_aros_configure_args_default}" CACHE STRING "Extra arguments passed to ./configure (defaults to EXTRA_CONFIGURE_OPTS env when present)")
set(_aros_make_jobs_default "$ENV{MAKE_JOBS}")
set(AROS_MAKE_JOBS "${_aros_make_jobs_default}" CACHE STRING "Parallel jobs passed to GNU make (-j). Empty uses make default")
set(AROS_TOOLCHAIN_INSTALL_DIR "" CACHE PATH "Passed to configure as --with-aros-toolchain-install=DIR when set")
set(AROS_PORTS_SOURCES_DIR "" CACHE PATH "Passed to configure as --with-portssources=DIR when set")
set(AROS_GNU_MAKE_PROGRAM "" CACHE FILEPATH "GNU make executable used for AROS makefile targets; auto-detected when empty")
option(AROS_ENABLE_LEGACY_PIPELINE "Expose top-level AROS build targets through CMake" ON)
option(AROS_BUILD_METAMAKE "Build MetaMake (mmake) with CMake" ON)
option(AROS_BUILD_ZOPFLI "Build tools/zopfli with CMake" ON)
option(AROS_BUILD_UDIS86 "Build arch/all-pc/udis86 with CMake" ON)
option(AROS_BUILD_GENMF "Build tools/genmf with CMake" ON)
option(AROS_BUILD_GENMODULE "Build tools/genmodule with CMake" ON)
option(AROS_BUILD_SETREV "Build tools/setrev with CMake" ON)
option(AROS_BUILD_ELF2HUNK "Build tools/elf2hunk with CMake" ON)
option(AROS_BUILD_ILBMTOC "Build tools/ilbmtoc with CMake" ON)
option(AROS_BUILD_ARCHTOOL "Build tools/archtools with CMake" ON)
option(AROS_BUILD_ILBMTOICON "Build tools/ilbmtoicon with CMake" ON)
option(AROS_BUILD_DTDESC "Build tools/dtdesc with CMake" ON)
option(AROS_BUILD_GENCTBL "Build tools/genctbl with CMake" ON)
option(AROS_BUILD_MKAMIKEYMAP "Build tools/mkamikeymap with CMake" ON)
option(AROS_BUILD_FD2PRAGMA "Build tools/fd2pragma with CMake" ON)
option(AROS_BUILD_ADFLIB "Build tools/ADFlib with CMake" ON)
option(AROS_BUILD_FLEXCAT "Build tools/flexcat with CMake" ON)
option(AROS_BUILD_LHA "Build tools/lha with CMake" ON)

include("${CMAKE_SOURCE_DIR}/cmake/AROSConfigSnapshot.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/AROSModule.cmake")
set(AROS_NATIVE_CONFIG_FILE "" CACHE FILEPATH "Optional literal NAME=value configuration for native manifest readers")
if(AROS_NATIVE_CONFIG_FILE)
  get_filename_component(AROS_NATIVE_CONFIG_FILE "${AROS_NATIVE_CONFIG_FILE}" ABSOLUTE BASE_DIR "${CMAKE_SOURCE_DIR}")
  _aros_native_config(_aros_native_config)
endif()
include("${CMAKE_SOURCE_DIR}/cmake/AROSManifests.cmake")
aros_collect_mmake_manifests(AROS_MMAKE_MANIFESTS)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/mmakefile" "${CMAKE_SOURCE_DIR}/mmake.config.in")
add_custom_target(aros-manifest-reconfigure-check
  COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/manifest-reconfigure"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_reconfigure.cmake"
  VERBATIM)
set_target_properties(aros-manifest-reconfigure-check PROPERTIES FOLDER "aros/tests")
# START LEGACY: compatibility bridge options for legacy MetaMake/make flow.
set(AROS_LEGACY_BUILD_DIR "${CMAKE_BINARY_DIR}/legacy-main" CACHE PATH "Build directory used for legacy configure+make wrapper targets")
option(AROS_LEGACY_USE_NATIVE_MMAKE "Use CMake-built mmake binary when running legacy GNU make targets" OFF)
option(AROS_LEGACY_SKIP_CROSSTOOLS_MMAKE "Skip legacy make-driven crosstools rebuild in wrapper targets when crosstools dependencies are provided by CMake" OFF)
option(AROS_LEGACY_REQUIRE_CROSSTOOLS "Require aros-crosstools-toolchain dependency for legacy make-wrapper targets" ON)
option(AROS_LEGACY_REQUIRE_CROSSTOOLS_RUNTIME "Require runtime-complete crosstools for legacy wrappers/parity checks" ON)
option(AROS_LEGACY_REUSE_EXISTING_CROSSTOOLS "Skip wrapper crosstools dependency when an existing toolchain install already provides the required target compiler" ON)
option(AROS_LEGACY_FORCE_MMAKE_CONFIG "Force MMAKE_CONFIG to the active build's mmake.config for legacy wrapper invocations" ON)
option(AROS_ENABLE_COEXIST_COMPARE "Build and compare native-CMake and legacy MetaMake tool outputs" ON)
option(AROS_COEXIST_STRICT_COMPARE "Fail coexist compare target when any artifact differs" OFF)
option(AROS_ENABLE_OUTPUT_PARITY_CHECK "Enable full output-tree parity comparison target against a legacy reference build" ON)
option(AROS_OUTPUT_PARITY_STRICT "Fail output parity target on any file mismatch" ON)
option(AROS_PARITY_LEGACY_SERIAL_MAKE "Run legacy-reference parity make step with -j1 for deterministic/stable output generation" ON)
# END LEGACY

add_subdirectory(tools)

separate_arguments(_aros_configure_args NATIVE_COMMAND "${AROS_CONFIGURE_ARGS}")

if(AROS_GNU_MAKE_PROGRAM)
  set(_aros_make_program "${AROS_GNU_MAKE_PROGRAM}")
else()
  find_program(_aros_make_program NAMES gmake make REQUIRED)
endif()

set(_aros_effective_toolchain_install_dir "${AROS_TOOLCHAIN_INSTALL_DIR}")
if(NOT _aros_effective_toolchain_install_dir AND AROS_CROSSTOOLS_NATIVE AND AROS_CROSSTOOLS_INSTALL_DIR)
  set(_aros_effective_toolchain_install_dir "${AROS_CROSSTOOLS_INSTALL_DIR}")
endif()

function(_aros_dir_has_target_gcc _dir _triplet _out_var)
  set(_has FALSE)
  if(_dir AND EXISTS "${_dir}/bin/${_triplet}-gcc")
    set(_has TRUE)
  elseif(_dir AND EXISTS "${_dir}/${_triplet}-gcc")
    set(_has TRUE)
  endif()

  if(_has AND AROS_LEGACY_REQUIRE_CROSSTOOLS_RUNTIME)
    set(_has_runtime FALSE)
    set(_runtime_candidates
      "${_dir}/lib/gcc/${_triplet}/${AROS_GCC_VERSION}/libstdc++.a"
      "${_dir}/lib/gcc/${_triplet}/${AROS_GCC_VERSION}/libstdc++.so"
      "${_dir}/${_triplet}/lib/libstdc++.a"
      "${_dir}/${_triplet}/lib/libstdc++.so"
      "${_dir}/${_triplet}/lib64/libstdc++.a"
      "${_dir}/${_triplet}/lib64/libstdc++.so"
    )
    foreach(_runtime_path IN LISTS _runtime_candidates)
      if(EXISTS "${_runtime_path}")
        set(_has_runtime TRUE)
        break()
      endif()
    endforeach()
    if(NOT _has_runtime)
      set(_has FALSE)
    endif()
  endif()

  set(${_out_var} "${_has}" PARENT_SCOPE)
endfunction()

set(_aros_reusable_toolchain_dir "")
if(AROS_CROSSTOOLS_TARGET_CPU)
  set(_aros_toolchain_triplet "${AROS_CROSSTOOLS_TARGET_CPU}-aros")
  set(_aros_toolchain_candidates)
  if(_aros_effective_toolchain_install_dir)
    list(APPEND _aros_toolchain_candidates "${_aros_effective_toolchain_install_dir}")
  endif()
  list(APPEND _aros_toolchain_candidates
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/tools/crosstools"
    "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools"
  )
  list(REMOVE_DUPLICATES _aros_toolchain_candidates)
  foreach(_aros_toolchain_candidate IN LISTS _aros_toolchain_candidates)
    _aros_dir_has_target_gcc("${_aros_toolchain_candidate}" "${_aros_toolchain_triplet}" _aros_candidate_has_gcc)
    if(_aros_candidate_has_gcc)
      set(_aros_reusable_toolchain_dir "${_aros_toolchain_candidate}")
      break()
    endif()
  endforeach()
endif()

if(_aros_reusable_toolchain_dir
   AND (AROS_CROSSTOOLS_NATIVE OR AROS_TOOLCHAIN_INSTALL_DIR)
   AND NOT _aros_effective_toolchain_install_dir STREQUAL _aros_reusable_toolchain_dir)
  message(STATUS "Using reusable existing crosstools install: ${_aros_reusable_toolchain_dir}")
  set(_aros_effective_toolchain_install_dir "${_aros_reusable_toolchain_dir}")
endif()

set(_aros_native_toolchain_install_dir "${AROS_TOOLCHAIN_INSTALL_DIR}")
if(NOT _aros_native_toolchain_install_dir AND AROS_CROSSTOOLS_NATIVE AND AROS_CROSSTOOLS_INSTALL_DIR)
  set(_aros_native_toolchain_install_dir "${AROS_CROSSTOOLS_INSTALL_DIR}")
  if(AROS_CROSSTOOLS_TARGET_CPU)
    _aros_dir_has_target_gcc(
      "${_aros_native_toolchain_install_dir}"
      "${AROS_CROSSTOOLS_TARGET_CPU}-aros"
      _aros_native_toolchain_has_gcc
    )
    if(NOT _aros_native_toolchain_has_gcc AND _aros_reusable_toolchain_dir)
      set(_aros_native_toolchain_install_dir "${_aros_reusable_toolchain_dir}")
    endif()
  endif()
endif()
if(NOT _aros_native_toolchain_install_dir AND _aros_reusable_toolchain_dir)
  set(_aros_native_toolchain_install_dir "${_aros_reusable_toolchain_dir}")
endif()
set(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR "${_aros_native_toolchain_install_dir}" CACHE INTERNAL
  "Effective toolchain prefix used by CMake-native build stages")

set(_aros_configure_cli_args "--target=${AROS_TARGET}")
if(_aros_effective_toolchain_install_dir)
  list(APPEND _aros_configure_cli_args "--with-aros-toolchain-install=${_aros_effective_toolchain_install_dir}")
endif()
if(AROS_PORTS_SOURCES_DIR)
  list(APPEND _aros_configure_cli_args "--with-portssources=${AROS_PORTS_SOURCES_DIR}")
endif()
list(APPEND _aros_configure_cli_args ${_aros_configure_args})

string(REPLACE ";" "\n" _aros_configure_cli_args_text "${_aros_configure_cli_args}")
set(_aros_configure_args_file "${CMAKE_BINARY_DIR}/.cmake-aros-configure-args.txt")
file(GENERATE OUTPUT "${_aros_configure_args_file}" CONTENT "${_aros_configure_cli_args_text}\n")

set(_aros_make_job_args)
if(AROS_MAKE_JOBS)
  list(APPEND _aros_make_job_args -j "${AROS_MAKE_JOBS}")
endif()

set(_aros_make_var_args)
set(_aros_make_common_deps)
set(_aros_legacy_crosstools_dep)
set(_aros_legacy_reuse_existing_crosstools FALSE)
if(AROS_LEGACY_USE_NATIVE_MMAKE AND TARGET metamake)
  list(APPEND _aros_make_var_args "MMAKE=$<TARGET_FILE:metamake>")
  list(APPEND _aros_make_common_deps metamake)
endif()
if(AROS_LEGACY_SKIP_CROSSTOOLS_MMAKE AND AROS_LEGACY_REQUIRE_CROSSTOOLS)
  list(APPEND _aros_make_var_args "CROSSTOOLS_TARGET=")
endif()
if(AROS_LEGACY_FORCE_MMAKE_CONFIG)
  list(APPEND _aros_make_var_args "MMAKE_CONFIG=${AROS_LEGACY_BUILD_DIR}/mmake.config")
endif()
if(AROS_LEGACY_REQUIRE_CROSSTOOLS)
  # START LEGACY: avoid rebuilding crosstools when a compatible install already exists.
  if(AROS_LEGACY_REUSE_EXISTING_CROSSTOOLS)
    if(_aros_reusable_toolchain_dir)
      set(_aros_legacy_reuse_existing_crosstools TRUE)
    elseif(AROS_CROSSTOOLS_TARGET_CPU AND _aros_effective_toolchain_install_dir)
      set(_aros_legacy_triplet "${AROS_CROSSTOOLS_TARGET_CPU}-aros")
      _aros_dir_has_target_gcc("${_aros_effective_toolchain_install_dir}" "${_aros_legacy_triplet}" _aros_legacy_reuse_existing_crosstools)
    endif()
  endif()
  # END LEGACY

  if(_aros_legacy_reuse_existing_crosstools)
    message(STATUS "Reusing existing crosstools install for legacy wrappers: ${_aros_effective_toolchain_install_dir}")
  elseif(AROS_LEGACY_REQUIRE_CROSSTOOLS_RUNTIME)
    set(_aros_legacy_crosstools_dep aros-crosstools)
  else()
    set(_aros_legacy_crosstools_dep aros-crosstools-toolchain)
  endif()
endif()

set(AROS_CONFIGURE_STAMP "${CMAKE_BINARY_DIR}/.cmake-aros-configured.stamp")
set(AROS_CONFIGURE_TARGET_CFG "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg")
set(AROS_CONFIGURE_MMAKE_CONFIG "${AROS_LEGACY_BUILD_DIR}/mmake.config")
set(_aros_append_mmake_ignoredirs_script "${CMAKE_SOURCE_DIR}/cmake/append_mmake_ignoredirs.cmake")
set(_aros_run_legacy_configure_script "${CMAKE_SOURCE_DIR}/cmake/run_legacy_configure.cmake")
string(TOLOWER "${CMAKE_HOST_SYSTEM_NAME}" _aros_host_arch)
set(_aros_host_cpu "${CMAKE_HOST_SYSTEM_PROCESSOR}")
if(NOT _aros_host_cpu)
  set(_aros_host_cpu "${CMAKE_SYSTEM_PROCESSOR}")
endif()
if(NOT _aros_host_cpu)
  set(_aros_host_cpu "unknown")
endif()
aros_determine_target_context("${AROS_TARGET}" _aros_target_arch _aros_target_cpu _aros_target_variant _aros_target_family)
set(AROS_TARGET_FAMILY "${_aros_target_family}" CACHE INTERNAL
  "Derived target family used by CMake-native layering and module resolution")
set(_aros_configure_required_outputs
  "${AROS_LEGACY_BUILD_DIR}/Makefile"
  "${AROS_LEGACY_BUILD_DIR}/config.status"
  "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
  "${AROS_CONFIGURE_MMAKE_CONFIG}"
  "${AROS_CONFIGURE_TARGET_CFG}"
  "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
  "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/conf.cmake"
  "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/make.defaults"
)
set(_aros_list_sep "__AROS_LIST_SEP__")
string(REPLACE ";" "${_aros_list_sep}" _aros_configure_cli_args_encoded "${_aros_configure_cli_args}")
string(REPLACE ";" "${_aros_list_sep}" _aros_configure_required_outputs_encoded "${_aros_configure_required_outputs}")
set(_aros_bootstrap_snapshot_state_file "${CMAKE_BINARY_DIR}/.cmake-aros-configure-bootstrap-state.txt")
set(_aros_bootstrap_snapshot_toolchain_dir "${_aros_effective_toolchain_install_dir}")
if(NOT _aros_bootstrap_snapshot_toolchain_dir)
  set(_aros_bootstrap_snapshot_toolchain_dir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/tools/crosstools")
endif()
string(JOIN "\n" _aros_bootstrap_snapshot_state
  "AROS_BOOTSTRAP_SNAPSHOT_VERSION=3"
  "AROS_TARGET=${AROS_TARGET}"
  "AROS_LEGACY_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}"
  "AROS_EFFECTIVE_TOOLCHAIN_INSTALL_DIR=${_aros_bootstrap_snapshot_toolchain_dir}"
  "AROS_HOST_ARCH=${_aros_host_arch}"
  "AROS_HOST_CPU=${_aros_host_cpu}"
  "AROS_TARGET_FAMILY=${_aros_target_family}"
)

set(_aros_bootstrap_snapshot_outputs
  "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
  "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
  "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
  "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
)
set(_aros_bootstrap_snapshot_needed FALSE)
foreach(_aros_snapshot_output IN LISTS _aros_bootstrap_snapshot_outputs)
  if(NOT EXISTS "${_aros_snapshot_output}")
    set(_aros_bootstrap_snapshot_needed TRUE)
    break()
  endif()
endforeach()

if(NOT _aros_bootstrap_snapshot_needed)
  if(EXISTS "${_aros_bootstrap_snapshot_state_file}")
    file(READ "${_aros_bootstrap_snapshot_state_file}" _aros_existing_bootstrap_snapshot_state)
  elseif(EXISTS "${AROS_LEGACY_BUILD_DIR}/config.status")
    set(_aros_existing_bootstrap_snapshot_state "${_aros_bootstrap_snapshot_state}\n")
    file(WRITE "${_aros_bootstrap_snapshot_state_file}" "${_aros_bootstrap_snapshot_state}\n")
  else()
    set(_aros_existing_bootstrap_snapshot_state "")
  endif()
  if(NOT _aros_existing_bootstrap_snapshot_state STREQUAL "${_aros_bootstrap_snapshot_state}\n")
    set(_aros_bootstrap_snapshot_needed TRUE)
  endif()
endif()

if(_aros_bootstrap_snapshot_needed)
  message(STATUS "Generating CMake bootstrap config snapshot in ${AROS_LEGACY_BUILD_DIR}")
  aros_write_bootstrap_config_snapshot(
    BUILD_DIR "${AROS_LEGACY_BUILD_DIR}"
    TARGET "${AROS_TARGET}"
    TOOLCHAIN_DIR "${_aros_bootstrap_snapshot_toolchain_dir}"
    HOST_ARCH "${_aros_host_arch}"
    HOST_CPU "${_aros_host_cpu}"
  )
  file(WRITE "${_aros_bootstrap_snapshot_state_file}" "${_aros_bootstrap_snapshot_state}\n")
endif()

add_custom_command(
  OUTPUT "${AROS_CONFIGURE_STAMP}"
  COMMAND "${CMAKE_COMMAND}"
          "-DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}"
          "-DAROS_ACTIVE_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}"
          "-DAROS_CONFIGURE_ARGS_ENCODED=${_aros_configure_cli_args_encoded}"
          "-DAROS_REQUIRED_OUTPUTS_ENCODED=${_aros_configure_required_outputs_encoded}"
          "-DAROS_LIST_SEP=${_aros_list_sep}"
          -P "${_aros_run_legacy_configure_script}"
  COMMAND "${CMAKE_COMMAND}" -E touch "${AROS_CONFIGURE_STAMP}"
  DEPENDS
    "${CMAKE_SOURCE_DIR}/configure"
    "${CMAKE_SOURCE_DIR}/configure.in"
    "${CMAKE_SOURCE_DIR}/Makefile.in"
    "${_aros_append_mmake_ignoredirs_script}"
    "${_aros_run_legacy_configure_script}"
    "${_aros_configure_args_file}"
  BYPRODUCTS
    ${_aros_configure_required_outputs}
  COMMENT "Configuring AROS in ${AROS_LEGACY_BUILD_DIR} (target: ${AROS_TARGET})"
  VERBATIM
)

add_custom_target(
  aros-configure
  DEPENDS
    "${AROS_CONFIGURE_STAMP}"
    "${AROS_CONFIGURE_MMAKE_CONFIG}"
    "${AROS_CONFIGURE_TARGET_CFG}"
)

set(AROS_NATIVE_INCLUDE_DIR "${CMAKE_BINARY_DIR}/native-includes")
set(AROS_NATIVE_GENERATED_INCLUDE_DIR "${CMAKE_BINARY_DIR}/native-generated-includes")
add_custom_target(aros-generated-includes-native)
set_target_properties(aros-generated-includes-native PROPERTIES
  FOLDER "aros/internal/includes"
  AROS_GENERATED_INCLUDE_FILES ""
)
set(AROS_NATIVE_OUTPUT_ROOT "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}")
set(AROS_NATIVE_SYSTEM_DIR "${AROS_NATIVE_OUTPUT_ROOT}/AROS")
set(AROS_NATIVE_DEVELOPER_DIR "${AROS_NATIVE_SYSTEM_DIR}/Development")
set(AROS_NATIVE_PUBLIC_LIB_DIR "${AROS_NATIVE_DEVELOPER_DIR}/lib")
set(AROS_NATIVE_BUILD_SDKS_DIR "${AROS_NATIVE_OUTPUT_ROOT}/gen/buildsdks")
set(AROS_NATIVE_PRIVATE_DEVELOPER_DIR "${AROS_NATIVE_BUILD_SDKS_DIR}/private")
set(AROS_NATIVE_PRIVATE_LIB_DIR "${AROS_NATIVE_PRIVATE_DEVELOPER_DIR}/lib")
set(AROS_NATIVE_REL_LIB_DIR "${AROS_NATIVE_BUILD_SDKS_DIR}/rel/lib")
set(_aros_native_include_deps aros-configure)
set(_aros_native_target_cc "")
if(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR AND AROS_CROSSTOOLS_TARGET_CPU)
  foreach(_candidate IN ITEMS
      "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}/bin/${AROS_CROSSTOOLS_TARGET_CPU}-aros-gcc"
      "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}/${AROS_CROSSTOOLS_TARGET_CPU}-aros-gcc")
    if(EXISTS "${_candidate}")
      set(_aros_native_target_cc "${_candidate}")
      break()
    endif()
  endforeach()
endif()
if(TARGET aros-crosstools-toolchain AND NOT _aros_native_target_cc)
  list(APPEND _aros_native_include_deps aros-crosstools-toolchain)
endif()
file(GLOB_RECURSE _aros_native_include_inputs CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/compiler/include/*"
  "${CMAKE_SOURCE_DIR}/compiler/arossupport/include/*"
  "${CMAKE_SOURCE_DIR}/compiler/autoinit/*.h"
  "${CMAKE_SOURCE_DIR}/compiler/startup/*"
  "${CMAKE_SOURCE_DIR}/compiler/dynmodule/include/*"
  "${CMAKE_SOURCE_DIR}/compiler/pthread/pthread.h"
  "${CMAKE_SOURCE_DIR}/compiler/pthread/sched.h"
  "${CMAKE_SOURCE_DIR}/compiler/pthread/semaphore.h"
  "${CMAKE_SOURCE_DIR}/compiler/crt/include/*"
  "${CMAKE_SOURCE_DIR}/compiler/crt/posixc/include/*"
  "${CMAKE_SOURCE_DIR}/compiler/crt/stdc/include/*"
  "${CMAKE_SOURCE_DIR}/rom/*/include/*"
  "${CMAKE_SOURCE_DIR}/arch/*/include/*"
)
set(AROS_NATIVE_INCLUDES_STAMP "${CMAKE_BINARY_DIR}/.cmake-aros-native-includes.stamp")
add_custom_command(
  OUTPUT "${AROS_NATIVE_INCLUDES_STAMP}"
  COMMAND "${CMAKE_COMMAND}"
          -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
          -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
          -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
          "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
          -DAROS_TARGET=${AROS_TARGET}
          -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
          -DAROS_NATIVE_GENERATED_INCLUDE_DIR=${AROS_NATIVE_GENERATED_INCLUDE_DIR}
          -DAROS_HOST_CC=${CMAKE_C_COMPILER}
          -DAROS_TARGET_CC=${_aros_native_target_cc}
          -DAROS_TARGET_TOOLCHAIN_DIR=${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}
          -DAROS_TARGET_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros
          -P "${CMAKE_SOURCE_DIR}/cmake/stage_native_includes.cmake"
  COMMAND "${CMAKE_COMMAND}" -E touch "${AROS_NATIVE_INCLUDES_STAMP}"
  DEPENDS
    ${_aros_native_include_deps}
    ${AROS_NATIVE_CONFIG_FILE}
    "${CMAKE_SOURCE_DIR}/cmake/AROSNativeConfig.cmake"
    aros-generated-includes-native
    "$<TARGET_PROPERTY:aros-generated-includes-native,AROS_GENERATED_INCLUDE_FILES>"
    "${CMAKE_SOURCE_DIR}/cmake/stage_native_includes.cmake"
    ${_aros_native_include_inputs}
  COMMENT "Staging native AROS developer includes for CMake-native module builds"
  VERBATIM
)
add_custom_target(aros-native-includes DEPENDS "${AROS_NATIVE_INCLUDES_STAMP}")
add_custom_target(aros-sdk-interfaces-native)

add_subdirectory(compiler)
include("${CMAKE_SOURCE_DIR}/cmake/AROSMmakeEntrypoints.cmake")
add_custom_target(aros-arch-linklibs-native)
# Transitional host-tool/SDK generator registration; not yet manifest-owned.
if(AROS_BUILD_UDIS86)
  add_subdirectory(arch/all-pc/udis86)
endif()
aros_layering_get_active_alias_layers(_aros_crt_aliases)
set(_aros_crt_entrypoints linklibs-romhack)
foreach(_alias IN LISTS _aros_crt_aliases)
  list(APPEND _aros_crt_entrypoints "linklibs-romhack-${_alias}")
endforeach()
aros_find_mmake_entrypoint(_aros_romhack OPTIONAL NAMES ${_aros_crt_entrypoints} KINDS build_linklib)
if(_aros_romhack_FOUND)
  aros_register_mmake_linklib(aros-arch-crt-romhack-linklib-native
    MODULE_PATH "${_aros_romhack_MODULE_PATH}" MMAKE_NAME "${_aros_romhack_mmake}"
    MMAKEFILE_SRC "${_aros_romhack_MANIFEST}")
  add_dependencies(aros-arch-linklibs-native aros-arch-crt-romhack-linklib-native)
endif()
if(DEFINED AROS_ARCH_NATIVE_MODULES AND NOT AROS_ARCH_NATIVE_MODULES STREQUAL "all-hosted/hostlib")
  message(FATAL_ERROR "AROS_ARCH_NATIVE_MODULES directory overrides are retired; hosted modules are discovered from the boot configuration")
endif()
unset(AROS_ARCH_NATIVE_MODULES CACHE)
include("${CMAKE_SOURCE_DIR}/cmake/AROSHosted.cmake")
if(AROS_BUILD_HOSTED_BOOTSTRAP)
  include("${CMAKE_SOURCE_DIR}/cmake/AROSHostedModules.cmake")
  include("${CMAKE_SOURCE_DIR}/cmake/AROSProgramTargets.cmake")
  if(DEFINED AROS_NATIVE_PROGRAM_RULES)
    message(STATUS "Removing obsolete AROS_NATIVE_PROGRAM_RULES allowlist; programs now follow the metadata graph")
    unset(AROS_NATIVE_PROGRAM_RULES CACHE)
    unset(AROS_NATIVE_PROGRAM_RULES)
  endif()
  set(AROS_NATIVE_PROGRAM_ROOT "" CACHE STRING
    "Optional metadata root for program discovery; empty uses mmake.config.in defaulttarget")
  aros_add_program_graph(aros-programs-native ROOT "${AROS_NATIVE_PROGRAM_ROOT}")
  cmake_language(DEFER CALL aros_finalize_program_dependencies)
  add_custom_target(aros-programs-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/native-config"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_native_config.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/graph-metadata"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_graph_metadata.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/program-discovery"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_program_discovery.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/programs"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_programs.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/program-objdir"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_program_objdir.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/program-dependencies"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_program_dependencies.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/program-static"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_program_static.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/detached-programs"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_detached_programs.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/programs-nix"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_nix_programs.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/linklibs"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_linklibs.cmake" VERBATIM)
  set_target_properties(aros-programs-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-fetch-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/fetch"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_fetch.cmake" VERBATIM)
  set_target_properties(aros-fetch-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-includes-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/includes"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_includes.cmake" VERBATIM)
  set_target_properties(aros-includes-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-include-transforms-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/include-transforms"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_include_transforms.cmake" VERBATIM)
  set_target_properties(aros-include-transforms-check PROPERTIES FOLDER "aros/tests")
  add_dependencies(aros-includes-check aros-include-transforms-check)
  add_dependencies(aros-programs-check aros-fetch-check aros-includes-check)
  add_custom_target(aros-catalogs-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/catalogs"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_catalogs.cmake" VERBATIM)
  set_target_properties(aros-catalogs-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-program-codegen-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/program-codegen"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_program_codegen.cmake" VERBATIM)
  set_target_properties(aros-program-codegen-check PROPERTIES FOLDER "aros/tests")
  include("${CMAKE_SOURCE_DIR}/cmake/AROSStaticTargets.cmake")
  set(_aros_static_defaults "workbench-s;workbench-devs-mountlist;workbench-directories")
  if(DEFINED AROS_NATIVE_STATIC_RULES AND
     (AROS_NATIVE_STATIC_RULES STREQUAL "workbench-s" OR
      AROS_NATIVE_STATIC_RULES STREQUAL "workbench-s;workbench-devs-mountlist"))
    set(AROS_NATIVE_STATIC_RULES "${_aros_static_defaults}" CACHE STRING
      "Migrated static-data entrypoints; files and dependencies come from mmake manifests" FORCE)
  endif()
  set(AROS_NATIVE_STATIC_RULES "${_aros_static_defaults}" CACHE STRING
    "Migrated static-data entrypoints; files and dependencies come from mmake manifests")
  add_custom_target(aros-runtime-data-native)
  set_target_properties(aros-runtime-data-native PROPERTIES FOLDER "aros/packaging")
  foreach(_rule IN LISTS AROS_NATIVE_STATIC_RULES)
    set(_target "aros-data-${_rule}-native")
    aros_add_mmake_static_target("${_target}" MMAKE_NAME "${_rule}")
    add_dependencies(aros-runtime-data-native "${_target}")
  endforeach()
  set(_aros_local_static_defaults "boot;workbench-fonts-quick")
  if(DEFINED AROS_NATIVE_LOCAL_STATIC_RULES AND AROS_NATIVE_LOCAL_STATIC_RULES STREQUAL "boot")
    set(AROS_NATIVE_LOCAL_STATIC_RULES "${_aros_local_static_defaults}" CACHE STRING
      "Migrated local static rules only; not their global MetaMake aggregates" FORCE)
  endif()
  set(AROS_NATIVE_LOCAL_STATIC_RULES "${_aros_local_static_defaults}" CACHE STRING
    "Migrated local static rules only; not their global MetaMake aggregates")
  foreach(_rule IN LISTS AROS_NATIVE_LOCAL_STATIC_RULES)
    set(_target "aros-data-local-${_rule}-native")
    aros_add_mmake_local_static_target("${_target}" MMAKE_NAME "${_rule}")
    add_dependencies(aros-runtime-data-native "${_target}")
  endforeach()
  add_custom_target(aros-static-graph-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/static-graph"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_static_graph.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/directory-copies"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_directory_copies.cmake"
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/static-patterns"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_static_patterns.cmake" VERBATIM)
  set_target_properties(aros-static-graph-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-static-text-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/static-text"
      "-DTEST_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_static_text.cmake" VERBATIM)
  set_target_properties(aros-static-text-check PROPERTIES FOLDER "aros/tests")
  add_custom_target(aros-text-transforms-check
    COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${CMAKE_BINARY_DIR}/tests/text-transforms"
      -P "${CMAKE_SOURCE_DIR}/cmake/tests/mmake_text_transforms.cmake" VERBATIM)
  set_target_properties(aros-text-transforms-check PROPERTIES FOLDER "aros/tests")
endif()

function(_aros_finalize_native_kernel_package_base_target)
  if(TARGET aros-rom-kernel-package-base-native AND TARGET aros-workbench-libs-gadtools-native)
    add_dependencies(aros-rom-kernel-package-base-native aros-workbench-libs-gadtools-native)
  endif()
  if(TARGET kernel-package-base AND TARGET aros-workbench-libs-gadtools-native)
    add_dependencies(kernel-package-base aros-workbench-libs-gadtools-native)
  endif()
endfunction()

# START LEGACY: temporary wrapper graph until full native CMake replacement.
if(NOT AROS_ENABLE_LEGACY_PIPELINE)
  add_subdirectory(rom)
  add_subdirectory(workbench)
  _aros_finalize_native_kernel_package_base_target()
  if(COMMAND aros_finalize_registered_hidd_stub_linklib)
    aros_finalize_registered_hidd_stub_linklib()
  endif()
  if(COMMAND aros_finalize_module_interfaces)
    aros_finalize_module_interfaces()
  endif()
  add_custom_target(aros-default ALL DEPENDS aros-crosstools-toolchain)
  return()
endif()

function(_aros_get_legacy_wrapper_target_name logical_target_name out_var)
  if("${logical_target_name}" MATCHES "^aros-(.+)$")
    set(_legacy_target_name "mmake-${CMAKE_MATCH_1}")
  else()
    set(_legacy_target_name "mmake-${logical_target_name}")
  endif()
  set(${out_var} "${_legacy_target_name}" PARENT_SCOPE)
endfunction()

function(aros_register_legacy_make_target target_name make_target)
  set(_deps ${ARGN})
  list(APPEND _deps ${_aros_make_common_deps})
  _aros_get_legacy_wrapper_target_name("${target_name}" _legacy_target_name)
  add_custom_target(
    "${_legacy_target_name}"
    COMMAND "${CMAKE_COMMAND}" -E chdir "${AROS_LEGACY_BUILD_DIR}"
            "${_aros_make_program}" ${_aros_make_job_args} ${_aros_make_var_args} "${make_target}"
    DEPENDS aros-configure ${_deps}
    COMMENT "Running legacy mmake target ${make_target}"
    VERBATIM
  )
endfunction()

_aros_get_legacy_wrapper_target_name("aros-all" _aros_legacy_all_target)
_aros_get_legacy_wrapper_target_name("aros-aros" _aros_legacy_aros_target)
_aros_get_legacy_wrapper_target_name("aros-tools" _aros_legacy_tools_target)

aros_register_legacy_make_target(aros-all all ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-aros AROS ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-complete AROS-complete ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-tools tools)
aros_register_legacy_make_target(aros-mmake mmake ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-sdk sdk ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-query query)
aros_register_legacy_make_target(aros-clean clean)
aros_register_legacy_make_target(aros-install install)
aros_register_legacy_make_target(aros-kernel kernel ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-compiler compiler ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-contrib contrib ${_aros_legacy_crosstools_dep})
aros_register_legacy_make_target(aros-ports ports ${_aros_legacy_crosstools_dep})

add_subdirectory(rom)
add_subdirectory(workbench)
_aros_finalize_native_kernel_package_base_target()

if(COMMAND aros_finalize_registered_hidd_stub_linklib)
  aros_finalize_registered_hidd_stub_linklib()
endif()
if(COMMAND aros_finalize_module_interfaces)
  aros_finalize_module_interfaces()
endif()

add_custom_target(
  aros-layering-report
  COMMAND "${CMAKE_COMMAND}"
          -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
          -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
          -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
          "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
          -DAROS_TARGET=${AROS_TARGET}
          -P "${CMAKE_SOURCE_DIR}/cmake/print_aros_layering.cmake"
  DEPENDS aros-configure
  COMMENT "Printing MetaMake layer chain for target ${AROS_TARGET}"
  VERBATIM
)

add_custom_target(
  aros-rom-debug-layering-report
  COMMAND "${CMAKE_COMMAND}"
          -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
          -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
          -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
          "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
          -DAROS_TARGET=${AROS_TARGET}
          -DMODULE_PATH=rom/debug
          -P "${CMAKE_SOURCE_DIR}/cmake/report_layered_module.cmake"
  DEPENDS aros-configure
  COMMENT "Printing layered source report for rom/debug"
  VERBATIM
)

add_custom_target(
  aros-rom-utility-layering-report
  COMMAND "${CMAKE_COMMAND}"
          -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
          -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
          -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
          "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
          -DAROS_TARGET=${AROS_TARGET}
          -DMODULE_PATH=rom/utility
          -P "${CMAKE_SOURCE_DIR}/cmake/report_layered_module.cmake"
  DEPENDS aros-configure
  COMMENT "Printing layered source report for rom/utility"
  VERBATIM
)

if(AROS_ENABLE_COEXIST_COMPARE)
  set(_aros_compare_legacy_tooldir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/tools")
  set(_aros_compare_specs)
  set(_aros_compare_native_deps)

  if(TARGET metamake)
    list(APPEND _aros_compare_specs "mmake::$<TARGET_FILE:metamake>::mmake")
    list(APPEND _aros_compare_native_deps metamake)
  endif()
  if(TARGET setrev)
    list(APPEND _aros_compare_specs "setrev::$<TARGET_FILE:setrev>::setrev")
    list(APPEND _aros_compare_native_deps setrev)
  endif()
  if(TARGET archtool)
    list(APPEND _aros_compare_specs "archtool::$<TARGET_FILE:archtool>::archtool")
    list(APPEND _aros_compare_native_deps archtool)
  endif()
  if(TARGET elf2hunk)
    list(APPEND _aros_compare_specs "elf2hunk::$<TARGET_FILE:elf2hunk>::elf2hunk")
    list(APPEND _aros_compare_native_deps elf2hunk)
  endif()
  if(TARGET ilbmtoc)
    list(APPEND _aros_compare_specs "ilbmtoc::$<TARGET_FILE:ilbmtoc>::ilbmtoc")
    list(APPEND _aros_compare_native_deps ilbmtoc)
  endif()
  if(TARGET fd2pragma)
    list(APPEND _aros_compare_specs "fd2pragma::$<TARGET_FILE:fd2pragma>::fd2pragma")
    list(APPEND _aros_compare_native_deps fd2pragma)
  endif()
  if(TARGET genctbl)
    list(APPEND _aros_compare_specs "genctbl::$<TARGET_FILE:genctbl>::genctbl")
    list(APPEND _aros_compare_native_deps genctbl)
  endif()
  if(TARGET flexcat)
    list(APPEND _aros_compare_specs "flexcat::$<TARGET_FILE:flexcat>::flexcat")
    list(APPEND _aros_compare_native_deps flexcat)
  endif()
  if(TARGET mkamikeymap)
    list(APPEND _aros_compare_specs "mkamikeymap::$<TARGET_FILE:mkamikeymap>::mkamikeymap")
    list(APPEND _aros_compare_native_deps mkamikeymap)
  endif()
  if(TARGET createdtdesc)
    list(APPEND _aros_compare_specs "createdtdesc::$<TARGET_FILE:createdtdesc>::createdtdesc")
    list(APPEND _aros_compare_native_deps createdtdesc)
  endif()
  if(TARGET examinedtdesc)
    list(APPEND _aros_compare_specs "examinedtdesc::$<TARGET_FILE:examinedtdesc>::examinedtdesc")
    list(APPEND _aros_compare_native_deps examinedtdesc)
  endif()

  if(_aros_compare_native_deps)
    add_custom_target(aros-tools-native DEPENDS ${_aros_compare_native_deps})
  else()
    add_custom_target(aros-tools-native)
  endif()

  if(_aros_compare_specs)
    string(REPLACE ";" "|" _aros_compare_specs_text "${_aros_compare_specs}")
    add_custom_target(
      aros-coexist-compare
      COMMAND "${CMAKE_COMMAND}"
              -DLEGACY_TOOLDIR=${_aros_compare_legacy_tooldir}
              -DSTRICT_COMPARE=${AROS_COEXIST_STRICT_COMPARE}
              -DSPECS_TEXT=${_aros_compare_specs_text}
              -P "${CMAKE_SOURCE_DIR}/cmake/compare_legacy_cmake_tools.cmake"
      DEPENDS ${_aros_legacy_tools_target} aros-tools-native
      COMMENT "Comparing CMake and legacy tool outputs"
      VERBATIM
    )
  else()
    add_custom_target(aros-coexist-compare DEPENDS ${_aros_legacy_tools_target})
  endif()
endif()

if(AROS_ENABLE_OUTPUT_PARITY_CHECK)
  string(REPLACE "/" "_" _aros_parity_target_safe "${AROS_TARGET}")
  set(_aros_parity_legacy_build_default "/tmp/aros-legacy-reference-${_aros_parity_target_safe}")
  set(AROS_PARITY_LEGACY_BUILD_DIR "${_aros_parity_legacy_build_default}" CACHE PATH "Build directory used for legacy-reference parity build")
  if(AROS_PARITY_LEGACY_BUILD_DIR STREQUAL "${CMAKE_BINARY_DIR}/legacy-reference")
    set(AROS_PARITY_LEGACY_BUILD_DIR "${_aros_parity_legacy_build_default}" CACHE PATH "Build directory used for legacy-reference parity build" FORCE)
  endif()
  set(AROS_PARITY_LEGACY_MAKE_TARGET "AROS" CACHE STRING "Legacy make target used to build the reference tree for parity checks")
  set(AROS_PARITY_LEGACY_TOOLCHAIN_INSTALL_DIR "" CACHE PATH "Toolchain install path passed only to legacy-reference configure. Empty uses legacy configure defaults.")
  set(AROS_PARITY_REFERENCE_DIR "${AROS_PARITY_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/AROS" CACHE PATH "Legacy reference output tree to compare against (typically <legacy-build>/bin/<target>/AROS)")
  set(AROS_PARITY_CMAKE_OUTPUT_DIR "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/AROS" CACHE PATH "CMake-driven output tree to compare")
  set(_aros_parity_effective_legacy_toolchain_install_dir "${AROS_PARITY_LEGACY_TOOLCHAIN_INSTALL_DIR}")
  if(NOT _aros_parity_effective_legacy_toolchain_install_dir AND _aros_effective_toolchain_install_dir)
    set(_aros_parity_effective_legacy_toolchain_install_dir "${_aros_effective_toolchain_install_dir}")
  endif()

  set(_aros_legacy_reference_configure_args "--target=${AROS_TARGET}")
  if(_aros_parity_effective_legacy_toolchain_install_dir)
    list(APPEND _aros_legacy_reference_configure_args "--with-aros-toolchain-install=${_aros_parity_effective_legacy_toolchain_install_dir}")
  endif()
  if(AROS_PORTS_SOURCES_DIR)
    list(APPEND _aros_legacy_reference_configure_args "--with-portssources=${AROS_PORTS_SOURCES_DIR}")
  endif()
  list(APPEND _aros_legacy_reference_configure_args ${_aros_configure_args})

  set(_aros_legacy_reference_stamp "${CMAKE_BINARY_DIR}/.cmake-aros-legacy-reference.stamp")
  set(_aros_parity_make_job_args ${_aros_make_job_args})
  if(AROS_PARITY_LEGACY_SERIAL_MAKE)
    set(_aros_parity_make_job_args -j1)
  endif()
  set(_aros_parity_make_var_args)
  list(APPEND _aros_parity_make_var_args "MMAKE_CONFIG=${AROS_PARITY_LEGACY_BUILD_DIR}/mmake.config")
  set(_aros_parity_env_args)
  add_custom_command(
    OUTPUT "${_aros_legacy_reference_stamp}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${AROS_PARITY_LEGACY_BUILD_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E chdir "${AROS_PARITY_LEGACY_BUILD_DIR}" "${CMAKE_SOURCE_DIR}/configure" ${_aros_legacy_reference_configure_args}
    # START LEGACY: avoid MetaMake source scan picking stale source-tree build dirs.
    COMMAND "${CMAKE_COMMAND}"
            -DMMAKE_CONFIG_PATH=${AROS_PARITY_LEGACY_BUILD_DIR}/mmake.config
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_ACTIVE_BUILD_DIR=${AROS_PARITY_LEGACY_BUILD_DIR}
            -P "${_aros_append_mmake_ignoredirs_script}"
    # END LEGACY
    COMMAND "${CMAKE_COMMAND}" -E env ${_aros_parity_env_args}
            "${CMAKE_COMMAND}" -E chdir "${AROS_PARITY_LEGACY_BUILD_DIR}"
            "${_aros_make_program}" ${_aros_parity_make_job_args} ${_aros_parity_make_var_args} "${AROS_PARITY_LEGACY_MAKE_TARGET}"
    COMMAND "${CMAKE_COMMAND}" -E touch "${_aros_legacy_reference_stamp}"
    DEPENDS
      "${CMAKE_SOURCE_DIR}/configure"
      "${CMAKE_SOURCE_DIR}/configure.in"
      "${CMAKE_SOURCE_DIR}/Makefile.in"
      "${_aros_configure_args_file}"
      ${_aros_legacy_crosstools_dep}
    COMMENT "Building legacy reference output in ${AROS_PARITY_LEGACY_BUILD_DIR}"
    VERBATIM
  )

  add_custom_target(aros-legacy-reference-build DEPENDS "${_aros_legacy_reference_stamp}")

  add_custom_target(
    aros-output-parity-compare
    COMMAND "${CMAKE_COMMAND}"
            -DLEFT_DIR=${AROS_PARITY_CMAKE_OUTPUT_DIR}
            -DRIGHT_DIR=${AROS_PARITY_REFERENCE_DIR}
            -DFAIL_ON_DIFF=${AROS_OUTPUT_PARITY_STRICT}
            -P "${CMAKE_SOURCE_DIR}/cmake/compare_output_trees.cmake"
    DEPENDS ${_aros_legacy_aros_target} aros-legacy-reference-build
    COMMENT "Comparing full AROS output tree against legacy reference"
    VERBATIM
  )
endif()

add_custom_target(aros-default ALL DEPENDS ${_aros_legacy_all_target})
# END LEGACY
