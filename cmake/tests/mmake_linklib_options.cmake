cmake_minimum_required(VERSION 3.20)
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
set(_config "${_src}/config-snapshot/bin/linux-x86_64/gen/config")
file(MAKE_DIRECTORY "${_src}/library" "${_src}/config" "${_src}/config-snapshot/config" "${_config}")
configure_file("${CMAKE_CURRENT_LIST_DIR}/linklibs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
configure_file("${_repo}/config/make.tmpl" "${_src}/config/make.tmpl" COPYONLY)
file(CREATE_LINK "${_repo}/cmake" "${_src}/cmake" SYMBOLIC)
file(WRITE "${_src}/core.h" "")
file(WRITE "${_src}/config-snapshot/config/make.cfg" "")
file(WRITE "${_config}/target.cfg" "FAMILY := unix\n")
file(WRITE "${_config}/compiler.cfg" "")
file(WRITE "${_config}/build.cfg" "")
set(_options [=[
OPTIONS_SRC := $(SRCDIR)/library
OPTIONS_FILES := first
OPTIONS_VALUE := 7
OPTIONS_SNAPSHOT := $(BEFORE_INCLUDE)
USER_CPPFLAGS := -DOPTIONS_VALUE=$(OPTIONS_VALUE) \
    -DOPTIONS_SNAPSHOT=$(OPTIONS_SNAPSHOT)
]=])
# This input is outside the library glob, so only parsed dependency tracking
# can rebuild the archive after its contents change.
file(WRITE "${_src}/compile.settings" "${_options}")
file(WRITE "${_src}/late.settings" "USER_CPPFLAGS := -DLATE_OPTIONS\n")
file(WRITE "${_src}/library/first.c" [=[
#if OPTIONS_SNAPSHOT != 19 || defined(LATE_OPTIONS)
#error options were not evaluated at their declaration
#endif
int first(void) { return OPTIONS_VALUE; }
]=])
file(WRITE "${_src}/library/replacement.c" "int replacement(void) { return OPTIONS_VALUE; }\n")
file(WRITE "${_src}/library/second.c" "int second(void) { return 2; }\n")
set(_manifest [=[
include $(SRCDIR)/config/aros.cfg
BEFORE_INCLUDE := 19
include $(SRCDIR)/compile.settings
BEFORE_INCLUDE := 99
ifeq ($(OPTIONS_SNAPSHOT),19)
%build_linklib mmake=fixture-library libname=fixture files="$(addprefix $(OPTIONS_SRC)/,$(OPTIONS_FILES))"
else
%build_linklib mmake=fixture-library libname=fixture files=absent-snapshot
endif
%build_linklib mmake=fixture-second libname=second files=second
include $(SRCDIR)/late.settings
ifeq (yes,no)
include $(SRCDIR)/absent-inactive.settings
endif
]=])
file(WRITE "${_src}/library/mmakefile.src" "${_manifest}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}\n${_out}${_err}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2)
endfunction()
function(noop)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do" OR _out MATCHES "Re-running CMake")
    message(FATAL_ERROR "Options did not settle to a no-op: ${_out}${_err}")
  endif()
endfunction()
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}" "-DAROS_TEST_SOURCE=${_repo}")
build()
noop()
set(_archive "${_build}/lib/libfixture.a")
file(SHA256 "${_archive}" _before)
string(REPLACE "OPTIONS_VALUE := 7" "OPTIONS_VALUE := 8" _edited "${_options}")
file(WRITE "${_src}/compile.settings" "${_edited}")
build()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Option flags edit did not rebuild the archive")
endif()
noop()
string(REPLACE "OPTIONS_FILES := first" "OPTIONS_FILES := replacement" _edited "${_edited}")
file(WRITE "${_src}/compile.settings" "${_edited}")
build()
find_program(_ar NAMES ar REQUIRED)
execute_process(COMMAND "${_ar}" t "${_archive}" OUTPUT_VARIABLE _members COMMAND_ERROR_IS_FATAL ANY)
if(NOT _members MATCHES "replacement.o" OR _members MATCHES "first.o")
  message(FATAL_ERROR "Option source-selection edit retained the old archive members: ${_members}")
endif()
noop()
file(REMOVE "${_archive}")
build()
noop()
foreach(_bad IN ITEMS recipe metadata nested condition shell)
  if(_bad STREQUAL "recipe")
    set(_invalid "\tOPTIONS_VALUE := 3\n")
  elseif(_bad STREQUAL "metadata")
    set(_invalid "#MM fixture-library: ignored-producer\n")
  elseif(_bad STREQUAL "nested")
    set(_invalid "include $(SRCDIR)/late.settings\n")
  elseif(_bad STREQUAL "condition")
    set(_invalid "ifeq (yes,yes)\nOPTIONS_VALUE := 3\nendif\n")
  else()
    set(_invalid "OPTIONS_VALUE := $(shell touch ${_root}/must-not-exist)\n")
  endif()
  file(WRITE "${_src}/compile.settings" "${_invalid}")
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Unsupported options include")
    message(FATAL_ERROR "Invalid ${_bad} option was not rejected: ${_out}${_err}")
  endif()
endforeach()
if(EXISTS "${_root}/must-not-exist")
  message(FATAL_ERROR "Option fragment executed a shell command")
endif()
file(REMOVE "${_src}/compile.settings")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "(owned source file|missing and no known rule)")
  message(FATAL_ERROR "Missing options were not rejected: ${_out}${_err}")
endif()
file(WRITE "${_root}/escaped.settings" "${_options}")
file(CREATE_LINK "${_root}/escaped.settings" "${_src}/compile.settings" SYMBOLIC)
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "owned source file")
  message(FATAL_ERROR "Escaped options were not rejected: ${_out}${_err}")
endif()
file(REMOVE "${_src}/compile.settings")
file(WRITE "${_src}/compile.settings" "${_options}")
build()
noop()
message(STATUS "Linklib ordered options, depfiles, source selection and rejection checks passed: ${_root}")
