cmake_minimum_required(VERSION 3.20)

project(lha_external LANGUAGES NONE)

include(ExternalProject)

find_program(_aros_lha_aclocal NAMES aclocal REQUIRED)
find_program(_aros_lha_autoheader NAMES autoheader REQUIRED)
find_program(_aros_lha_automake NAMES automake REQUIRED)
find_program(_aros_lha_autoconf NAMES autoconf REQUIRED)
find_program(_aros_lha_make NAMES gmake make REQUIRED)
find_program(_aros_lha_git NAMES git REQUIRED)

set(AROS_LHA_GIT_REPOSITORY "https://github.com/jca02266/lha" CACHE STRING "Git repository used for lha external build")
set(AROS_LHA_GIT_TAG "master" CACHE STRING "Git tag/branch/commit for lha external build")
set(AROS_LHA_INSTALL_DIR "${CMAKE_BINARY_DIR}/external-tools/lha" CACHE PATH "Install prefix used for lha external build")

set(_aros_lha_prefix "${CMAKE_BINARY_DIR}/_deps/lha")
set(_aros_lha_source_dir "${_aros_lha_prefix}/src/lha")
set(_aros_lha_binary_dir "${_aros_lha_prefix}/build")
set(_aros_lha_log_dir "${_aros_lha_prefix}/logs")

ExternalProject_Add(aros_external_lha
  PREFIX "${_aros_lha_prefix}"
  GIT_REPOSITORY "${AROS_LHA_GIT_REPOSITORY}"
  GIT_TAG "${AROS_LHA_GIT_TAG}"
  GIT_SHALLOW ON
  SOURCE_DIR "${_aros_lha_source_dir}"
  BINARY_DIR "${_aros_lha_binary_dir}"
  UPDATE_DISCONNECTED ON
  CONFIGURE_COMMAND
    /bin/bash "${CMAKE_SOURCE_DIR}/cmake/run_with_live_log.sh" "${_aros_lha_log_dir}/configure.log"
    /bin/sh -c
    "set -e && cd '${_aros_lha_source_dir}' && '${_aros_lha_aclocal}' && '${_aros_lha_autoheader}' && '${_aros_lha_automake}' -a && '${_aros_lha_autoconf}' && cd '${_aros_lha_binary_dir}' && '${_aros_lha_source_dir}/configure' --prefix='${AROS_LHA_INSTALL_DIR}' --bindir='${AROS_LHA_INSTALL_DIR}/bin'"
  BUILD_COMMAND /bin/bash "${CMAKE_SOURCE_DIR}/cmake/run_with_live_log.sh" "${_aros_lha_log_dir}/build.log" "${_aros_lha_make}" -j1
  INSTALL_COMMAND /bin/bash "${CMAKE_SOURCE_DIR}/cmake/run_with_live_log.sh" "${_aros_lha_log_dir}/install.log" "${_aros_lha_make}" -j1 install
  BUILD_IN_SOURCE OFF
  LOG_DOWNLOAD ON
  USES_TERMINAL_CONFIGURE ON
  USES_TERMINAL_BUILD ON
  USES_TERMINAL_INSTALL ON
)

add_custom_target(lha DEPENDS aros_external_lha)
