include(ExternalProject)

set(AROS_CROSSTOOLS_NATIVE ON CACHE BOOL "Build crosstools with native CMake/ExternalProject instead of delegating to legacy make targets")
set(AROS_CROSSTOOLS_FAMILY "gnu" CACHE STRING "Crosstools family to build (gnu or llvm)")
set_property(CACHE AROS_CROSSTOOLS_FAMILY PROPERTY STRINGS gnu llvm)

if(NOT DEFINED AROS_CROSSTOOLS_TARGET_CPU OR AROS_CROSSTOOLS_TARGET_CPU STREQUAL "")
  string(REGEX REPLACE "^[^-]+-" "" _aros_target_cpu_guess "${AROS_TARGET}")
  set(AROS_CROSSTOOLS_TARGET_CPU "${_aros_target_cpu_guess}" CACHE STRING "Target CPU used for crosstools triplet prefix (<cpu>-aros)" FORCE)
endif()

if(AROS_TOOLCHAIN_INSTALL_DIR)
  set(_aros_crosstools_install_default "${AROS_TOOLCHAIN_INSTALL_DIR}")
else()
  set(_aros_crosstools_install_default "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools")
endif()
set(AROS_CROSSTOOLS_INSTALL_DIR "${_aros_crosstools_install_default}" CACHE PATH "Install location for crosstools")

set(_aros_crosstools_legacy_install_default "${CMAKE_BINARY_DIR}/toolchain")
if("${AROS_CROSSTOOLS_INSTALL_DIR}" STREQUAL "${_aros_crosstools_legacy_install_default}")
  message(STATUS "Updating legacy crosstools install default to ${_aros_crosstools_install_default}")
  set(AROS_CROSSTOOLS_INSTALL_DIR "${_aros_crosstools_install_default}" CACHE PATH "Install location for crosstools" FORCE)
  set(AROS_CROSSTOOLS_INSTALL_DIR "${_aros_crosstools_install_default}")
endif()

if(AROS_CROSSTOOLS_SYSROOT)
  set(_aros_crosstools_sysroot_default "${AROS_CROSSTOOLS_SYSROOT}")
elseif(AROS_PORTS_SOURCES_DIR)
  set(_aros_crosstools_sysroot_default "${AROS_PORTS_SOURCES_DIR}")
else()
  set(_aros_crosstools_sysroot_default "")
endif()
set(AROS_CROSSTOOLS_SYSROOT "${_aros_crosstools_sysroot_default}" CACHE PATH "Sysroot path passed to binutils/gcc")

set(AROS_CROSSTOOLS_BUILD_VASM ON CACHE BOOL "Build and install vasm m68k tools")
set(AROS_CROSSTOOLS_UPDATE_DISCONNECTED ON CACHE BOOL "Skip ExternalProject update/fetch on rebuilds when sources already exist")
set(AROS_CROSSTOOLS_LEGACY_REUSE_EXISTING ON CACHE BOOL "In legacy fallback mode, reuse an existing crosstools install when the target compiler already exists")
set(AROS_CROSSTOOLS_SOURCE_CACHE_DIR "" CACHE PATH "Optional directory containing pre-downloaded GNU source archives for native crosstools")

set(AROS_BINUTILS_VERSION "2.32" CACHE STRING "Binutils version")
set(AROS_GCC_VERSION "10.5.0" CACHE STRING "GCC version")
set(AROS_GMP_VERSION "6.3.0" CACHE STRING "GMP version")
set(AROS_ISL_VERSION "0.27" CACHE STRING "ISL version")
set(AROS_MPFR_VERSION "4.2.2" CACHE STRING "MPFR version")
set(AROS_MPC_VERSION "1.3.1" CACHE STRING "MPC version")

set(AROS_GCC_LANGUAGES "c,c++" CACHE STRING "GCC enabled languages")
option(AROS_CROSSTOOLS_BUILD_TARGET_LIBSTDCXX "Build and install target libstdc++ runtime+headers in native crosstools mode" ON)
set(AROS_CROSSTOOLS_ENABLE_LTO OFF CACHE BOOL "Enable LTO/plugins for binutils/gcc build")
set(AROS_CROSSTOOLS_HOST_CFLAGS "-std=gnu17" CACHE STRING "Host CFLAGS passed to GNU dependency configure steps")
set(AROS_CROSSTOOLS_HOST_CXXFLAGS "-std=gnu++17" CACHE STRING "Host CXXFLAGS passed to GNU dependency configure steps")
set(AROS_CROSSTOOLS_WORK_ROOT "${CMAKE_BINARY_DIR}/_deps/crosstools-gnu" CACHE PATH "Working directory for crosstools source/build trees (set to fast local storage to speed extraction/build)")

if(AROS_CROSSTOOLS_NATIVE)
  if(NOT AROS_CROSSTOOLS_FAMILY STREQUAL "gnu")
    message(FATAL_ERROR "Native CMake crosstools currently supports only AROS_CROSSTOOLS_FAMILY=gnu")
  endif()

  find_program(_aros_patch_program NAMES patch REQUIRED)
  find_program(_aros_make_program_local NAMES gmake make REQUIRED)
  find_program(_aros_git_program NAMES git)
  set(_aros_native_make_build_args)
  if(AROS_MAKE_JOBS)
    list(APPEND _aros_native_make_build_args -j "${AROS_MAKE_JOBS}")
  endif()

  set(_aros_triplet "${AROS_CROSSTOOLS_TARGET_CPU}-aros")
  get_filename_component(_aros_gnu_root "${AROS_CROSSTOOLS_WORK_ROOT}" ABSOLUTE)
  set(_aros_src_dir "${_aros_gnu_root}/src")
  set(_aros_build_dir "${_aros_gnu_root}/build")

  if(NOT AROS_CROSSTOOLS_SYSROOT)
    message(WARNING "AROS_CROSSTOOLS_SYSROOT is empty. GCC/binutils will be configured without an explicit sysroot path.")
  endif()

  file(MAKE_DIRECTORY "${AROS_CROSSTOOLS_INSTALL_DIR}")
  file(MAKE_DIRECTORY "${_aros_src_dir}")
  file(MAKE_DIRECTORY "${_aros_build_dir}")
  set(_aros_target_tool_bindir "${AROS_CROSSTOOLS_INSTALL_DIR}")

  function(_aros_crosstools_external_source out_var source_dir)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs URLS ARCHIVE_NAMES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(_args SOURCE_DIR "${source_dir}")
    if(EXISTS "${source_dir}/configure")
      list(APPEND _args DOWNLOAD_COMMAND "" UPDATE_COMMAND "")
    else()
      set(_archive "")
      set(_cache_roots)
      if(AROS_CROSSTOOLS_SOURCE_CACHE_DIR)
        list(APPEND _cache_roots "${AROS_CROSSTOOLS_SOURCE_CACHE_DIR}")
      endif()
      list(APPEND _cache_roots "${_aros_src_dir}")

      foreach(_cache_root IN LISTS _cache_roots)
        foreach(_archive_name IN LISTS ARG_ARCHIVE_NAMES)
          if(EXISTS "${_cache_root}/${_archive_name}")
            set(_archive "${_cache_root}/${_archive_name}")
            break()
          endif()
        endforeach()
        if(_archive)
          break()
        endif()
      endforeach()

      if(_archive)
        list(APPEND _args URL "file://${_archive}")
      else()
        list(APPEND _args URL ${ARG_URLS})
      endif()
    endif()

    set(${out_var} "${_args}" PARENT_SCOPE)
  endfunction()

  function(_aros_crosstools_live_log_command out_var log_dir log_name)
    set(_cmd /bin/bash "${CMAKE_SOURCE_DIR}/cmake/run_with_live_log.sh" "${log_dir}/${log_name}.log")
    list(APPEND _cmd ${ARGN})
    set(${out_var} "${_cmd}" PARENT_SCOPE)
  endfunction()

  _aros_crosstools_external_source(
    _aros_gmp_source_args
    "${_aros_src_dir}/gmp-${AROS_GMP_VERSION}"
    URLS "https://ftp.gnu.org/gnu/gmp/gmp-${AROS_GMP_VERSION}.tar.xz"
    ARCHIVE_NAMES "gmp-${AROS_GMP_VERSION}.tar.xz" "gmp-${AROS_GMP_VERSION}.tar.bz2"
  )
  set(_aros_gmp_log_dir "${_aros_gnu_root}/logs/gmp")
  _aros_crosstools_live_log_command(
    _aros_gmp_configure_cmd
    "${_aros_gmp_log_dir}"
    configure
    <SOURCE_DIR>/configure
    --prefix=${AROS_CROSSTOOLS_INSTALL_DIR}
    --disable-shared
    --enable-static
    --bindir=${AROS_CROSSTOOLS_INSTALL_DIR}/bin
    --libdir=${AROS_CROSSTOOLS_INSTALL_DIR}/lib
  )
  _aros_crosstools_live_log_command(
    _aros_gmp_build_cmd
    "${_aros_gmp_log_dir}"
    build
    "${_aros_make_program_local}" -j1
  )
  _aros_crosstools_live_log_command(
    _aros_gmp_install_cmd
    "${_aros_gmp_log_dir}"
    install
    "${_aros_make_program_local}" -j1 install
  )
  ExternalProject_Add(crosstools_gmp
    ${_aros_gmp_source_args}
    PREFIX "${_aros_gnu_root}/gmp"
    BINARY_DIR "${_aros_build_dir}/gmp-${AROS_GMP_VERSION}"
    CONFIGURE_COMMAND
      "${CMAKE_COMMAND}" -E env
      "CFLAGS=${AROS_CROSSTOOLS_HOST_CFLAGS}"
      "CXXFLAGS=${AROS_CROSSTOOLS_HOST_CXXFLAGS}"
      ${_aros_gmp_configure_cmd}
    BUILD_COMMAND ${_aros_gmp_build_cmd}
    INSTALL_COMMAND ${_aros_gmp_install_cmd}
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE OFF
    LOG_DOWNLOAD ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )

  _aros_crosstools_external_source(
    _aros_isl_source_args
    "${_aros_src_dir}/isl-${AROS_ISL_VERSION}"
    URLS
      "https://libisl.sourceforge.io/isl-${AROS_ISL_VERSION}.tar.xz"
      "https://gcc.gnu.org/pub/gcc/infrastructure/isl-${AROS_ISL_VERSION}.tar.xz"
    ARCHIVE_NAMES "isl-${AROS_ISL_VERSION}.tar.xz"
  )
  set(_aros_isl_log_dir "${_aros_gnu_root}/logs/isl")
  _aros_crosstools_live_log_command(
    _aros_isl_configure_cmd
    "${_aros_isl_log_dir}"
    configure
    <SOURCE_DIR>/configure
    --prefix=${AROS_CROSSTOOLS_INSTALL_DIR}
    --disable-shared
    --enable-static
    --without-piplib
    --bindir=${AROS_CROSSTOOLS_INSTALL_DIR}/bin
    --libdir=${AROS_CROSSTOOLS_INSTALL_DIR}/lib
    CPPFLAGS=-I${AROS_CROSSTOOLS_INSTALL_DIR}/include
    LDFLAGS=-L${AROS_CROSSTOOLS_INSTALL_DIR}/lib
  )
  _aros_crosstools_live_log_command(
    _aros_isl_build_cmd
    "${_aros_isl_log_dir}"
    build
    "${_aros_make_program_local}" -j1
  )
  _aros_crosstools_live_log_command(
    _aros_isl_install_cmd
    "${_aros_isl_log_dir}"
    install
    "${_aros_make_program_local}" -j1 install
  )
  ExternalProject_Add(crosstools_isl
    ${_aros_isl_source_args}
    PREFIX "${_aros_gnu_root}/isl"
    BINARY_DIR "${_aros_build_dir}/isl-${AROS_ISL_VERSION}"
    CONFIGURE_COMMAND
      "${CMAKE_COMMAND}" -E env
      "CFLAGS=${AROS_CROSSTOOLS_HOST_CFLAGS}"
      "CXXFLAGS=${AROS_CROSSTOOLS_HOST_CXXFLAGS}"
      ${_aros_isl_configure_cmd}
    BUILD_COMMAND ${_aros_isl_build_cmd}
    INSTALL_COMMAND ${_aros_isl_install_cmd}
    DEPENDS crosstools_gmp
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE OFF
    LOG_DOWNLOAD ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )

  _aros_crosstools_external_source(
    _aros_mpfr_source_args
    "${_aros_src_dir}/mpfr-${AROS_MPFR_VERSION}"
    URLS "https://ftp.gnu.org/gnu/mpfr/mpfr-${AROS_MPFR_VERSION}.tar.xz"
    ARCHIVE_NAMES "mpfr-${AROS_MPFR_VERSION}.tar.xz"
  )
  set(_aros_mpfr_log_dir "${_aros_gnu_root}/logs/mpfr")
  _aros_crosstools_live_log_command(
    _aros_mpfr_configure_cmd
    "${_aros_mpfr_log_dir}"
    configure
    <SOURCE_DIR>/configure
    --prefix=${AROS_CROSSTOOLS_INSTALL_DIR}
    --disable-shared
    --enable-static
    --bindir=${AROS_CROSSTOOLS_INSTALL_DIR}/bin
    --libdir=${AROS_CROSSTOOLS_INSTALL_DIR}/lib
    CPPFLAGS=-I${AROS_CROSSTOOLS_INSTALL_DIR}/include
    LDFLAGS=-L${AROS_CROSSTOOLS_INSTALL_DIR}/lib
  )
  _aros_crosstools_live_log_command(
    _aros_mpfr_build_cmd
    "${_aros_mpfr_log_dir}"
    build
    "${_aros_make_program_local}" -j1
  )
  _aros_crosstools_live_log_command(
    _aros_mpfr_install_cmd
    "${_aros_mpfr_log_dir}"
    install
    "${_aros_make_program_local}" -j1 install
  )
  ExternalProject_Add(crosstools_mpfr
    ${_aros_mpfr_source_args}
    PREFIX "${_aros_gnu_root}/mpfr"
    BINARY_DIR "${_aros_build_dir}/mpfr-${AROS_MPFR_VERSION}"
    CONFIGURE_COMMAND
      "${CMAKE_COMMAND}" -E env
      "CFLAGS=${AROS_CROSSTOOLS_HOST_CFLAGS}"
      "CXXFLAGS=${AROS_CROSSTOOLS_HOST_CXXFLAGS}"
      ${_aros_mpfr_configure_cmd}
    BUILD_COMMAND ${_aros_mpfr_build_cmd}
    INSTALL_COMMAND ${_aros_mpfr_install_cmd}
    DEPENDS crosstools_gmp
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE OFF
    LOG_DOWNLOAD ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )

  _aros_crosstools_external_source(
    _aros_mpc_source_args
    "${_aros_src_dir}/mpc-${AROS_MPC_VERSION}"
    URLS "https://ftp.gnu.org/gnu/mpc/mpc-${AROS_MPC_VERSION}.tar.gz"
    ARCHIVE_NAMES "mpc-${AROS_MPC_VERSION}.tar.gz"
  )
  set(_aros_mpc_log_dir "${_aros_gnu_root}/logs/mpc")
  _aros_crosstools_live_log_command(
    _aros_mpc_configure_cmd
    "${_aros_mpc_log_dir}"
    configure
    <SOURCE_DIR>/configure
    --prefix=${AROS_CROSSTOOLS_INSTALL_DIR}
    --disable-shared
    --enable-static
    --bindir=${AROS_CROSSTOOLS_INSTALL_DIR}/bin
    --libdir=${AROS_CROSSTOOLS_INSTALL_DIR}/lib
    CPPFLAGS=-I${AROS_CROSSTOOLS_INSTALL_DIR}/include
    LDFLAGS=-L${AROS_CROSSTOOLS_INSTALL_DIR}/lib
  )
  _aros_crosstools_live_log_command(
    _aros_mpc_build_cmd
    "${_aros_mpc_log_dir}"
    build
    "${_aros_make_program_local}" -j1
  )
  _aros_crosstools_live_log_command(
    _aros_mpc_install_cmd
    "${_aros_mpc_log_dir}"
    install
    "${_aros_make_program_local}" -j1 install
  )
  ExternalProject_Add(crosstools_mpc
    ${_aros_mpc_source_args}
    PREFIX "${_aros_gnu_root}/mpc"
    BINARY_DIR "${_aros_build_dir}/mpc-${AROS_MPC_VERSION}"
    CONFIGURE_COMMAND
      "${CMAKE_COMMAND}" -E env
      "CFLAGS=${AROS_CROSSTOOLS_HOST_CFLAGS}"
      "CXXFLAGS=${AROS_CROSSTOOLS_HOST_CXXFLAGS}"
      ${_aros_mpc_configure_cmd}
    BUILD_COMMAND ${_aros_mpc_build_cmd}
    INSTALL_COMMAND ${_aros_mpc_install_cmd}
    DEPENDS crosstools_gmp crosstools_mpfr
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE OFF
    LOG_DOWNLOAD ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )

  set(_aros_binutils_extra
    --target=${_aros_triplet}
    --bindir=${_aros_target_tool_bindir}
    --libdir=${AROS_CROSSTOOLS_INSTALL_DIR}/lib
    --disable-werror
    --disable-nls
  )
  if(AROS_CROSSTOOLS_SYSROOT)
    list(APPEND _aros_binutils_extra --with-sysroot=${AROS_CROSSTOOLS_SYSROOT})
  endif()
  if(AROS_CROSSTOOLS_ENABLE_LTO)
    list(APPEND _aros_binutils_extra --enable-plugins --enable-lto)
  endif()
  if(AROS_CROSSTOOLS_TARGET_CPU STREQUAL "i386" OR AROS_CROSSTOOLS_TARGET_CPU STREQUAL "x86_64")
    list(APPEND _aros_binutils_extra --enable-separate-code=no)
  endif()

  set(_aros_binutils_patch "${CMAKE_SOURCE_DIR}/tools/crosstools/gnu/binutils-${AROS_BINUTILS_VERSION}-aros.diff")
  if(EXISTS "${_aros_binutils_patch}")
    set(_aros_binutils_patch_cmd
      "${_aros_patch_program}" -N -p1 -i "${_aros_binutils_patch}"
    )
  else()
    set(_aros_binutils_patch_cmd "${CMAKE_COMMAND}" -E true)
    message(WARNING "No binutils patch found for version ${AROS_BINUTILS_VERSION}: ${_aros_binutils_patch}")
  endif()

  _aros_crosstools_external_source(
    _aros_binutils_source_args
    "${_aros_src_dir}/binutils-${AROS_BINUTILS_VERSION}"
    URLS "https://ftp.gnu.org/gnu/binutils/binutils-${AROS_BINUTILS_VERSION}.tar.xz"
    ARCHIVE_NAMES "binutils-${AROS_BINUTILS_VERSION}.tar.xz" "binutils-${AROS_BINUTILS_VERSION}.tar.bz2"
  )
  set(_aros_binutils_log_dir "${_aros_gnu_root}/logs/binutils")
  _aros_crosstools_live_log_command(
    _aros_binutils_configure_cmd
    "${_aros_binutils_log_dir}"
    configure
    <SOURCE_DIR>/configure --prefix=${AROS_CROSSTOOLS_INSTALL_DIR} ${_aros_binutils_extra}
  )
  _aros_crosstools_live_log_command(
    _aros_binutils_build_cmd
    "${_aros_binutils_log_dir}"
    build
    "${_aros_make_program_local}" ${_aros_native_make_build_args} MAKEINFO=true
  )
  _aros_crosstools_live_log_command(
    _aros_binutils_install_cmd
    "${_aros_binutils_log_dir}"
    install
    "${_aros_make_program_local}" -j1 MAKEINFO=true install
  )
  ExternalProject_Add(crosstools_binutils
    ${_aros_binutils_source_args}
    PREFIX "${_aros_gnu_root}/binutils"
    BINARY_DIR "${_aros_build_dir}/binutils-${AROS_BINUTILS_VERSION}"
    PATCH_COMMAND ${_aros_binutils_patch_cmd}
    CONFIGURE_COMMAND
      "${CMAKE_COMMAND}" -E env
      "CFLAGS=${AROS_CROSSTOOLS_HOST_CFLAGS}"
      "CXXFLAGS=${AROS_CROSSTOOLS_HOST_CXXFLAGS}"
      ${_aros_binutils_configure_cmd}
    BUILD_COMMAND ${_aros_binutils_build_cmd}
    INSTALL_COMMAND ${_aros_binutils_install_cmd}
    DEPENDS crosstools_gmp crosstools_isl crosstools_mpfr crosstools_mpc
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE OFF
    LOG_DOWNLOAD ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )

  set(_aros_gcc_patch "${CMAKE_SOURCE_DIR}/tools/crosstools/gnu/gcc-${AROS_GCC_VERSION}-aros.diff")
  if(EXISTS "${_aros_gcc_patch}")
    set(_aros_gcc_patch_cmd
      "${_aros_patch_program}" -N -p1 -i "${_aros_gcc_patch}"
    )
  else()
    set(_aros_gcc_patch_cmd "${CMAKE_COMMAND}" -E true)
    message(WARNING "No gcc patch found for version ${AROS_GCC_VERSION}: ${_aros_gcc_patch}")
  endif()

  set(_aros_gcc_extra
    --target=${_aros_triplet}
    --bindir=${_aros_target_tool_bindir}
    --libdir=${AROS_CROSSTOOLS_INSTALL_DIR}/lib
    --with-native-system-header-dir=/include
    --enable-languages=${AROS_GCC_LANGUAGES}
    --enable-long-long
    --enable-version-specific-runtime-libs
    --enable-frame-pointer
    --disable-isl-version-check
    --disable-bootstrap
    --disable-sjlj-exceptions
    --disable-tls
    --disable-nls
    --disable-libssp
    --enable-threads=single
    --disable-libstdcxx-pch
    --disable-build-with-cxx
    --disable-build-poststage1-with-cxx
    --disable-libatomic
    --with-gmp=${AROS_CROSSTOOLS_INSTALL_DIR}
    --with-mpfr=${AROS_CROSSTOOLS_INSTALL_DIR}
    --with-mpc=${AROS_CROSSTOOLS_INSTALL_DIR}
    --with-isl=${AROS_CROSSTOOLS_INSTALL_DIR}
  )
  if(AROS_CROSSTOOLS_SYSROOT)
    list(APPEND _aros_gcc_extra --with-sysroot=${AROS_CROSSTOOLS_SYSROOT})
  endif()
  if(NOT AROS_CROSSTOOLS_ENABLE_LTO)
    list(APPEND _aros_gcc_extra --disable-plugins)
  endif()

  set(_aros_gcc_url_hash_arg)
  if(AROS_GCC_VERSION STREQUAL "10.5.0")
    # Pinned to avoid unnecessary re-downloads and guarantee source integrity.
    set(_aros_gcc_url_hash_arg URL_HASH "SHA256=25109543fdf46f397c347b5d8b7a2c7e5694a5a51cce4b9c6e1ea8a71ca307c1")
  endif()

  set(_aros_collect_aros_gen_dir "${CMAKE_CURRENT_BINARY_DIR}/collect-aros")
  set(_aros_collect_aros_install_dir "${AROS_CROSSTOOLS_INSTALL_DIR}/${_aros_triplet}/bin")
  set(_aros_collect_aros_alias "${AROS_CROSSTOOLS_INSTALL_DIR}/${_aros_triplet}-collect-aros")
  set(_aros_collect_aros_toolchain_ld "${_aros_target_tool_bindir}/${_aros_triplet}-ld")
  set(_aros_collect_aros_toolchain_strip "${_aros_target_tool_bindir}/${_aros_triplet}-strip")
  set(_aros_collect_aros_toolchain_nm "${_aros_target_tool_bindir}/${_aros_triplet}-nm")
  set(_aros_collect_aros_toolchain_objdump "${_aros_target_tool_bindir}/${_aros_triplet}-objdump")
  set(AROS_CROSSTOOLSDIR "${AROS_CROSSTOOLS_INSTALL_DIR}")
  set(aros_target_cpu "${AROS_CROSSTOOLS_TARGET_CPU}")
  set(aros_toolchain_ld "${_aros_collect_aros_toolchain_ld}")
  set(orig_target_ld "${_aros_collect_aros_toolchain_ld}")
  set(aros_target_strip "${_aros_collect_aros_toolchain_strip}")
  set(aros_target_nm "${_aros_collect_aros_toolchain_nm}")
  set(aros_target_objdump "${_aros_collect_aros_toolchain_objdump}")
  file(MAKE_DIRECTORY "${_aros_collect_aros_gen_dir}")
  configure_file(
    "${CMAKE_SOURCE_DIR}/tools/collect-aros/env.h.in"
    "${_aros_collect_aros_gen_dir}/env.h"
    @ONLY
  )

  add_executable(
    aros-collect-aros
    "${CMAKE_SOURCE_DIR}/tools/collect-aros/collect-aros.c"
    "${CMAKE_SOURCE_DIR}/tools/collect-aros/gensets.c"
    "${CMAKE_SOURCE_DIR}/tools/collect-aros/misc.c"
    "${CMAKE_SOURCE_DIR}/tools/collect-aros/backend-generic.c"
    "${CMAKE_SOURCE_DIR}/tools/collect-aros/docommand-exec.c"
  )
  target_include_directories(
    aros-collect-aros
    PRIVATE
      "${CMAKE_SOURCE_DIR}/tools/collect-aros"
      "${_aros_collect_aros_gen_dir}"
  )
  target_compile_definitions(aros-collect-aros PRIVATE _CROSS_)

  set(_aros_collect_aros_stamp "${CMAKE_BINARY_DIR}/.cmake-aros-crosstools-collect-aros.stamp")
  add_custom_command(
    OUTPUT "${_aros_collect_aros_stamp}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_aros_collect_aros_install_dir}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "$<TARGET_FILE:aros-collect-aros>"
            "${_aros_collect_aros_install_dir}/collect-aros"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${_aros_collect_aros_install_dir}/collect-aros"
            "${_aros_collect_aros_alias}"
    COMMAND "${CMAKE_COMMAND}" -E touch "${_aros_collect_aros_stamp}"
    DEPENDS aros-collect-aros crosstools_binutils
    COMMENT "Installing AROS collect-aros into the native crosstools tree"
    VERBATIM
  )
  add_custom_target(aros-crosstools-collect-aros DEPENDS "${_aros_collect_aros_stamp}")

  set(_aros_gcc_build_targets all-gcc all-target-libgcc)
  set(_aros_gcc_install_targets install-gcc install-target-libgcc)

  _aros_crosstools_external_source(
    _aros_gcc_source_args
    "${_aros_src_dir}/gcc-${AROS_GCC_VERSION}"
    URLS
      "https://ftp.gnu.org/gnu/gcc/gcc-${AROS_GCC_VERSION}/gcc-${AROS_GCC_VERSION}.tar.xz"
      "https://ftp.mirrorservice.org/sites/sourceware.org/pub/gcc/releases/gcc-${AROS_GCC_VERSION}/gcc-${AROS_GCC_VERSION}.tar.xz"
    ARCHIVE_NAMES "gcc-${AROS_GCC_VERSION}.tar.xz"
  )
  set(_aros_gcc_log_dir "${_aros_gnu_root}/logs/gcc")
  _aros_crosstools_live_log_command(
    _aros_gcc_configure_cmd
    "${_aros_gcc_log_dir}"
    configure
    <SOURCE_DIR>/configure --prefix=${AROS_CROSSTOOLS_INSTALL_DIR} ${_aros_gcc_extra}
  )
  _aros_crosstools_live_log_command(
    _aros_gcc_build_cmd
    "${_aros_gcc_log_dir}"
    build
    "${_aros_make_program_local}" ${_aros_native_make_build_args} ${_aros_gcc_build_targets}
  )
  _aros_crosstools_live_log_command(
    _aros_gcc_install_cmd
    "${_aros_gcc_log_dir}"
    install
    "${_aros_make_program_local}" -j1 ${_aros_gcc_install_targets}
  )
  ExternalProject_Add(crosstools_gcc
    ${_aros_gcc_source_args}
    ${_aros_gcc_url_hash_arg}
    PREFIX "${_aros_gnu_root}/gcc"
    BINARY_DIR "${_aros_build_dir}/gcc-${AROS_GCC_VERSION}"
    PATCH_COMMAND ${_aros_gcc_patch_cmd}
    CONFIGURE_COMMAND
      "${CMAKE_COMMAND}" -E env
      "CFLAGS=${AROS_CROSSTOOLS_HOST_CFLAGS}"
      "CXXFLAGS=${AROS_CROSSTOOLS_HOST_CXXFLAGS}"
      ${_aros_gcc_configure_cmd}
    BUILD_COMMAND ${_aros_gcc_build_cmd}
    INSTALL_COMMAND ${_aros_gcc_install_cmd}
    DEPENDS crosstools_binutils aros-crosstools-collect-aros crosstools_gmp crosstools_isl crosstools_mpfr crosstools_mpc
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE OFF
    LOG_DOWNLOAD ON
    USES_TERMINAL_CONFIGURE ON
    USES_TERMINAL_BUILD ON
    USES_TERMINAL_INSTALL ON
  )

  add_custom_target(
    aros-crosstools-toolchain
    DEPENDS crosstools_gcc
  )

  if(AROS_CROSSTOOLS_BUILD_TARGET_LIBSTDCXX)
    set(_aros_crosstools_libstdcxx_stamp
      "${CMAKE_BINARY_DIR}/.cmake-aros-crosstools-target-libstdcxx.stamp"
    )
    add_custom_command(
      OUTPUT "${_aros_crosstools_libstdcxx_stamp}"
      COMMAND "${CMAKE_COMMAND}" -E chdir "${_aros_build_dir}/gcc-${AROS_GCC_VERSION}"
              "${_aros_make_program_local}" ${_aros_native_make_build_args} all-target-libstdc++-v3
      COMMAND "${CMAKE_COMMAND}" -E chdir "${_aros_build_dir}/gcc-${AROS_GCC_VERSION}"
              "${_aros_make_program_local}" -j1 install-target-libstdc++-v3
      COMMAND "${CMAKE_COMMAND}" -E touch "${_aros_crosstools_libstdcxx_stamp}"
      DEPENDS crosstools_gcc
      COMMENT "Building optional AROS target libstdc++ runtime"
      VERBATIM
    )
    add_custom_target(
      aros-crosstools-target-libstdcxx
      DEPENDS "${_aros_crosstools_libstdcxx_stamp}"
    )
  endif()

  if(AROS_CROSSTOOLS_BUILD_VASM)
    if(NOT _aros_git_program)
      message(WARNING "git not found, disabling vasm build")
    else()
      set(_aros_vasm_log_dir "${_aros_gnu_root}/logs/vasm")
      _aros_crosstools_live_log_command(
        _aros_vasm_build_cmd
        "${_aros_vasm_log_dir}"
        build
        "${_aros_make_program_local}" ${_aros_native_make_build_args} CPU=m68k SYNTAX=mot
      )
      _aros_crosstools_live_log_command(
        _aros_vasm_install_cmd
        "${_aros_vasm_log_dir}"
        install
        "${CMAKE_COMMAND}" -E copy_if_different <SOURCE_DIR>/vasmm68k_mot "${AROS_CROSSTOOLS_INSTALL_DIR}/vasmm68k_mot"
      )
      ExternalProject_Add(crosstools_vasm
        GIT_REPOSITORY "https://github.com/leffmann/vasm"
        GIT_TAG "master"
        GIT_SHALLOW ON
        UPDATE_DISCONNECTED ${AROS_CROSSTOOLS_UPDATE_DISCONNECTED}
        PREFIX "${_aros_gnu_root}/vasm"
        SOURCE_DIR "${_aros_src_dir}/vasm"
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ${_aros_vasm_build_cmd}
        INSTALL_COMMAND
          /bin/bash "${CMAKE_SOURCE_DIR}/cmake/run_with_live_log.sh" "${_aros_vasm_log_dir}/install.log"
          "${CMAKE_COMMAND}" -E copy_if_different <SOURCE_DIR>/vasmm68k_mot "${AROS_CROSSTOOLS_INSTALL_DIR}/vasmm68k_mot"
          COMMAND "${CMAKE_COMMAND}" -E copy_if_different <SOURCE_DIR>/vobjdump "${AROS_CROSSTOOLS_INSTALL_DIR}/vobjdump"
        BUILD_IN_SOURCE ON
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        LOG_DOWNLOAD ON
        USES_TERMINAL_BUILD ON
        USES_TERMINAL_INSTALL ON
      )
      add_dependencies(aros-crosstools-toolchain crosstools_vasm)
    endif()
  endif()

  if(TARGET aros-crosstools-target-libstdcxx)
    add_custom_target(aros-crosstools DEPENDS aros-crosstools-toolchain aros-crosstools-target-libstdcxx)
  else()
    add_custom_target(aros-crosstools DEPENDS aros-crosstools-toolchain)
  endif()
else()
  # START LEGACY: transitional fallback while native conversion for all families/stages is still in progress.
  if(NOT DEFINED _aros_make_program OR _aros_make_program STREQUAL "")
    find_program(_aros_make_program NAMES gmake make REQUIRED)
  endif()
  if(NOT DEFINED _aros_make_job_args)
    set(_aros_make_job_args)
  endif()
  set(_aros_legacy_crosstools_make_args -j1)
  set(_aros_legacy_make_build_dir "${CMAKE_BINARY_DIR}")
  if(DEFINED AROS_LEGACY_BUILD_DIR AND NOT AROS_LEGACY_BUILD_DIR STREQUAL "")
    set(_aros_legacy_make_build_dir "${AROS_LEGACY_BUILD_DIR}")
  endif()
  set(_aros_legacy_triplet "${AROS_CROSSTOOLS_TARGET_CPU}-aros")
  set(_aros_legacy_toolchain_gcc "${AROS_CROSSTOOLS_INSTALL_DIR}/bin/${_aros_legacy_triplet}-gcc")
  set(_aros_legacy_toolchain_gcc_top "${AROS_CROSSTOOLS_INSTALL_DIR}/${_aros_legacy_triplet}-gcc")
  set(_aros_legacy_reuse_install FALSE)
  if(AROS_CROSSTOOLS_LEGACY_REUSE_EXISTING AND (EXISTS "${_aros_legacy_toolchain_gcc}" OR EXISTS "${_aros_legacy_toolchain_gcc_top}"))
    set(_aros_legacy_reuse_install TRUE)
  endif()

  set(AROS_CROSSTOOLS_TOOLCHAIN_STAMP
    "${CMAKE_BINARY_DIR}/.cmake-aros-crosstools-toolchain.stamp"
  )
  set(AROS_CROSSTOOLS_STAMP
    "${CMAKE_BINARY_DIR}/.cmake-aros-crosstools.stamp"
  )
  set(_aros_sync_legacy_crosstools_flags
    "${CMAKE_SOURCE_DIR}/cmake/sync_legacy_crosstools_flags.cmake"
  )

  if(_aros_legacy_reuse_install)
    add_custom_command(
      OUTPUT "${AROS_CROSSTOOLS_TOOLCHAIN_STAMP}"
      COMMAND "${CMAKE_COMMAND}"
              -DAROS_CROSSTOOLS_INSTALL_DIR=${AROS_CROSSTOOLS_INSTALL_DIR}
              -DAROS_CROSSTOOLS_TARGET_CPU=${AROS_CROSSTOOLS_TARGET_CPU}
              -DAROS_BINUTILS_VERSION=${AROS_BINUTILS_VERSION}
              -DAROS_GCC_VERSION=${AROS_GCC_VERSION}
              -DAROS_GMP_VERSION=${AROS_GMP_VERSION}
              -DAROS_ISL_VERSION=${AROS_ISL_VERSION}
              -DAROS_MPFR_VERSION=${AROS_MPFR_VERSION}
              -DAROS_MPC_VERSION=${AROS_MPC_VERSION}
              -DAROS_TOUCH_CROSSTOOLS_FLAG=ON
              -P "${_aros_sync_legacy_crosstools_flags}"
      COMMAND "${CMAKE_COMMAND}" -E touch "${AROS_CROSSTOOLS_TOOLCHAIN_STAMP}"
      DEPENDS aros-configure "${_aros_sync_legacy_crosstools_flags}"
      COMMENT "Reusing existing AROS crosstoolchain install at ${AROS_CROSSTOOLS_INSTALL_DIR}"
      VERBATIM
    )
  else()
    add_custom_command(
      OUTPUT "${AROS_CROSSTOOLS_TOOLCHAIN_STAMP}"
      COMMAND "${CMAKE_COMMAND}"
              -DAROS_CROSSTOOLS_INSTALL_DIR=${AROS_CROSSTOOLS_INSTALL_DIR}
              -DAROS_CROSSTOOLS_TARGET_CPU=${AROS_CROSSTOOLS_TARGET_CPU}
              -DAROS_BINUTILS_VERSION=${AROS_BINUTILS_VERSION}
              -DAROS_GCC_VERSION=${AROS_GCC_VERSION}
              -DAROS_GMP_VERSION=${AROS_GMP_VERSION}
              -DAROS_ISL_VERSION=${AROS_ISL_VERSION}
              -DAROS_MPFR_VERSION=${AROS_MPFR_VERSION}
              -DAROS_MPC_VERSION=${AROS_MPC_VERSION}
              -P "${_aros_sync_legacy_crosstools_flags}"
      COMMAND "${CMAKE_COMMAND}" -E env "MMAKE_CONFIG=${_aros_legacy_make_build_dir}/mmake.config"
              "${CMAKE_COMMAND}" -E chdir "${_aros_legacy_make_build_dir}"
              "${_aros_make_program}" ${_aros_legacy_crosstools_make_args} crosstools-toolchain
      COMMAND "${CMAKE_COMMAND}" -E touch "${AROS_CROSSTOOLS_TOOLCHAIN_STAMP}"
      DEPENDS
        aros-configure
        "${_aros_sync_legacy_crosstools_flags}"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/mmakefile.src"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/gnu/mmakefile.src"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/llvm/mmakefile.src"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/vasm/mmakefile.src"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/gnu.cfg"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/gnu.deps"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/llvm.cfg"
        "${CMAKE_SOURCE_DIR}/tools/crosstools/llvm.deps"
      COMMENT "Bootstrapping AROS crosstoolchain (legacy make crosstools-toolchain)"
      VERBATIM
    )
  endif()

  add_custom_target(
    aros-crosstools-toolchain
    DEPENDS "${AROS_CROSSTOOLS_TOOLCHAIN_STAMP}"
  )

  if(_aros_legacy_reuse_install)
    add_custom_command(
      OUTPUT "${AROS_CROSSTOOLS_STAMP}"
      COMMAND "${CMAKE_COMMAND}"
              -DAROS_CROSSTOOLS_INSTALL_DIR=${AROS_CROSSTOOLS_INSTALL_DIR}
              -DAROS_CROSSTOOLS_TARGET_CPU=${AROS_CROSSTOOLS_TARGET_CPU}
              -DAROS_BINUTILS_VERSION=${AROS_BINUTILS_VERSION}
              -DAROS_GCC_VERSION=${AROS_GCC_VERSION}
              -DAROS_GMP_VERSION=${AROS_GMP_VERSION}
              -DAROS_ISL_VERSION=${AROS_ISL_VERSION}
              -DAROS_MPFR_VERSION=${AROS_MPFR_VERSION}
              -DAROS_MPC_VERSION=${AROS_MPC_VERSION}
              -DAROS_TOUCH_CROSSTOOLS_FLAG=ON
              -P "${_aros_sync_legacy_crosstools_flags}"
      COMMAND "${CMAKE_COMMAND}" -E touch "${AROS_CROSSTOOLS_STAMP}"
      DEPENDS aros-crosstools-toolchain "${_aros_sync_legacy_crosstools_flags}"
      COMMENT "Reusing existing AROS crosstools runtime install at ${AROS_CROSSTOOLS_INSTALL_DIR}"
      VERBATIM
    )
  else()
    add_custom_command(
      OUTPUT "${AROS_CROSSTOOLS_STAMP}"
      COMMAND "${CMAKE_COMMAND}" -E env "MMAKE_CONFIG=${_aros_legacy_make_build_dir}/mmake.config"
              "${CMAKE_COMMAND}" -E chdir "${_aros_legacy_make_build_dir}"
              "${_aros_make_program}" ${_aros_legacy_crosstools_make_args} crosstools
      COMMAND "${CMAKE_COMMAND}" -E touch "${AROS_CROSSTOOLS_STAMP}"
      DEPENDS aros-crosstools-toolchain
      COMMENT "Building AROS crosstools runtime link libraries (legacy make crosstools)"
      VERBATIM
    )
  endif()

  add_custom_target(
    aros-crosstools
    DEPENDS "${AROS_CROSSTOOLS_STAMP}"
  )
  # END LEGACY
endif()
