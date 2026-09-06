cmake_minimum_required(VERSION 3.20)
foreach(_required IN ITEMS TEST_BINARY_DIR AROS_CC AROS_NATIVE_INCLUDE_DIR AROS_SYSROOT)
  if(NOT ${_required})
    message(FATAL_ERROR "Pass ${_required} for the native CRT header check")
  endif()
endforeach()
get_filename_component(AROS_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include("${AROS_SOURCE_DIR}/cmake/AROSMmakeBuild.cmake")
file(GLOB _libc_headers "${AROS_NATIVE_INCLUDE_DIR}/aros/posixc/*.h"
  "${AROS_NATIVE_INCLUDE_DIR}/aros/stdc/*.h")
foreach(_header IN LISTS _libc_headers)
  get_filename_component(_name "${_header}" NAME)
  if(IS_SYMLINK "${AROS_NATIVE_INCLUDE_DIR}/${_name}")
    file(READ_SYMLINK "${AROS_NATIVE_INCLUDE_DIR}/${_name}" _alias)
    if(_alias MATCHES "^aros/(stdc|posixc)/")
      message(FATAL_ERROR "Synthetic flat libc alias shadows SDK search order: ${_name}")
    endif()
  endif()
endforeach()
file(MAKE_DIRECTORY "${TEST_BINARY_DIR}")
set(_probe "${TEST_BINARY_DIR}/headers.c")
file(WRITE "${_probe}" [=[
#include <float.h>
#include <stddef.h>
#include <errno.h>
#include <stdlib.h>
#include <setjmp.h>
#include <signal.h>
#include <time.h>
_Static_assert(LDBL_MAX == __LDBL_MAX__, "Compiler floating-point limit was overridden");
_Static_assert(LDBL_MANT_DIG == __LDBL_MANT_DIG__, "Compiler precision was overridden");
int probe(char *env) { sigjmp_buf buf; struct sigaction action; clockid_t clock; return putenv(env) + EISDIR + sizeof(buf) + sizeof(action) + sizeof(clock); }
]=])
_aros_compiler_builtin_include_dir("${AROS_CC}" _module_compiler_include_dir)
set(AROS_TARGET linux-x86_64)
set(AROS_CONFIG_BUILD_DIR "${TEST_BINARY_DIR}/config")
file(MAKE_DIRECTORY "${AROS_CONFIG_BUILD_DIR}/bin/linux-x86_64/gen/config")
file(WRITE "${AROS_CONFIG_BUILD_DIR}/bin/linux-x86_64/gen/config/target.cfg" "FAMILY := unix\n")
set(MODULE_PATH fixture)
set(MODULE_GENERATED_DIR "${TEST_BINARY_DIR}")
set(_module_source_dir "${TEST_BINARY_DIR}")
set(_module_generated_include_root "${AROS_NATIVE_INCLUDE_DIR}")
set(_module_deflibdefs "${TEST_BINARY_DIR}/libdefs.h")
file(WRITE "${_module_deflibdefs}" "")
set(_module_config_cppflags -D_GNU_SOURCE)
_aros_module_compile_args(TRUE _args)
execute_process(COMMAND "${AROS_CC}" ${_args} -Werror=implicit-function-declaration
  -Werror=overflow -MD -MF "${TEST_BINARY_DIR}/headers.d"
  -fsyntax-only "${_probe}" COMMAND_ERROR_IS_FATAL ANY)
file(READ "${TEST_BINARY_DIR}/headers.d" _deps)
foreach(_header IN ITEMS float.h stddef.h)
  string(FIND "${_deps}" "${_module_compiler_include_dir}/${_header}" _builtin)
  string(FIND "${_deps}" "${AROS_NATIVE_INCLUDE_DIR}/aros/stdc/${_header}" _fallback)
  if(_builtin EQUAL -1 OR NOT _fallback EQUAL -1)
    message(FATAL_ERROR "Module compile did not select compiler-owned ${_header}: ${_deps}")
  endif()
endforeach()
message(STATUS "Native SDK POSIX declarations and compiler-owned float.h/stddef.h passed with production module flags")
