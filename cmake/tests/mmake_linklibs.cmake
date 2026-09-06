cmake_minimum_required(VERSION 3.20)
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
set(_external "${_root}/source-cache")
set(_config "${_src}/config-snapshot/bin/linux-x86_64/gen/config")
file(MAKE_DIRECTORY "${_src}/library" "${_src}/config" "${_src}/config-snapshot/config" "${_config}" "${_external}")
configure_file("${CMAKE_CURRENT_LIST_DIR}/linklibs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
configure_file("${_repo}/config/make.tmpl" "${_src}/config/make.tmpl" COPYONLY)
file(CREATE_LINK "${_repo}/cmake" "${_src}/cmake" SYMBOLIC)
file(WRITE "${_src}/config-snapshot/config/make.cfg" "")
file(WRITE "${_config}/target.cfg" "FAMILY := unix\nPORTSDIR := $(SRCDIR)/../source-cache\nGENINCDIR := $(GENDIR)/include\nAROS_DIR_INCLUDE := include\n")
file(WRITE "${_config}/compiler.cfg" "")
file(WRITE "${_config}/build.cfg" "")
file(WRITE "${_external}/value.h" "#define VALUE 1\n")
file(WRITE "${_external}/first.c" [=[
#include "value.h"
#include "rule.h"
#include <fixture/public.h>
#if !defined(RULE_CPP) || !defined(RULE_C) || defined(LATER_RULE)
#error wrong rule-local linklib flags
#endif
#if !defined(NESTED_MATCH) || !defined(EMPTY_EQUAL) || !defined(EMPTY_RIGHT) || defined(INACTIVE_BRANCH)
#error wrong linklib conditional selection
#endif
int first(void) { return VALUE + HEADER_VALUE + CORE_VALUE; }
]=])
file(WRITE "${_src}/core.h" "#define CORE_VALUE 5\n")
file(MAKE_DIRECTORY "${_src}/library/headers")
file(WRITE "${_src}/library/headers/public.h" "#include <fixture/core.h>\n#define HEADER_VALUE 10\n")
file(WRITE "${_src}/library/headers/private.h" "#define PRIVATE_VALUE 7\n")
file(WRITE "${_src}/library/headers/unlisted.h" "#error must not be staged\n")
file(MAKE_DIRECTORY "${_src}/library/selected" "${_src}/library/later")
file(WRITE "${_src}/library/selected/rule.h" "")
file(WRITE "${_src}/library/later/rule.h" "#error wrong rule-local include directory\n")
file(WRITE "${_external}/second.c" "int second(void) { return 2; }\n")
file(WRITE "${_external}/asmvalue.h" "#define ASM_VALUE 7\n")
file(WRITE "${_external}/data.S" "#include \"asmvalue.h\"\n#ifndef RULE_ASM\n#error wrong rule-local assembly flags\n#endif\n.data\n.long ASM_VALUE\n")
file(WRITE "${_src}/library/mmakefile.src" [=[
FILES := first second
#MM fixture-headers: fixture-core-includes
%copy_includes mmake=fixture-headers includes=public.h dir=headers path=fixture
%copy_includes mmake=fixture-headers includes=private.h dir=headers path=fixture sdk=private
%build_linklib mmake=earlier-library libname=earlier files=absent cppflags=-DEARLIER_RULE cflags=-DEARLIER_RULE aflags=-DEARLIER_RULE
USER_CPPFLAGS := -DRULE_CPP
ifneq (,$(findstring x86_64,$(addprefix linux-,x86_64)))
USER_CPPFLAGS += -DNESTED_MATCH
else
FILES += absent-nested-match
endif
ifeq ($(findstring arm,linux-x86_64),)
USER_CPPFLAGS += -DEMPTY_RIGHT
else
FILES += absent-empty-right
endif
ifeq (,)
USER_CPPFLAGS += -DEMPTY_EQUAL
endif
ifneq (,$(findstring arm,linux-x86_64))
ifeq ($(findstring x86_64,linux-x86_64),x86_64)
USER_CPPFLAGS += -DINACTIVE_BRANCH
FILES += absent-inactive-parent
else
FILES += absent-inactive-else
endif
endif
USER_CFLAGS := -DRULE_C
USER_AFLAGS := -DRULE_ASM
USER_INCLUDES := -I$(SRCDIR)/library/selected
%build_linklib mmake=fixture-library libname=fixture \
    files="$(addprefix $(PORTSDIR)/,$(addsuffix .c,$(FILES)))" \
    asmfiles=$(PORTSDIR)/data.S objs=$(PORTSDIR)/extra.o
%build_linklib mmake=fixture-second libname=second files=$(PORTSDIR)/second.c
USER_CPPFLAGS := -DLATER_RULE
USER_CFLAGS := -DLATER_RULE
USER_AFLAGS := -DLATER_RULE
USER_INCLUDES := -I$(SRCDIR)/library/later
%build_linklib mmake=later-library libname=later files=absent
]=])
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2)
endfunction()
find_program(_cc NAMES cc gcc REQUIRED)
file(WRITE "${_external}/extra.c" "int extra(void) { return 8; }\n")
run("${_cc}" -c "${_external}/extra.c" -o "${_external}/extra.o")
set(_archive "${_build}/lib/libfixture.a")
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}" "-DAROS_TEST_SOURCE=${_repo}")
build()
set(_public "${_build}/include/fixture/public.h")
set(_host "${_build}/output/gen/include/fixture/public.h")
set(_private "${_build}/sdks/private/include/fixture/private.h")
foreach(_header IN ITEMS "${_public}" "${_host}" "${_private}")
  if(NOT EXISTS "${_header}")
    message(FATAL_ERROR "Missing manifest header: ${_header}")
  endif()
endforeach()
if(EXISTS "${_build}/include/fixture/unlisted.h" OR EXISTS "${_build}/include/fixture/private.h")
  message(FATAL_ERROR "Header list or per-declaration SDK was ignored")
endif()
file(SHA256 "${_archive}" _before)
file(TIMESTAMP "${_archive}" _stamp_before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
build()
file(TIMESTAMP "${_archive}" _stamp_after "%s")
if(NOT _stamp_before STREQUAL _stamp_after)
  message(FATAL_ERROR "No-op build rebuilt the linklib")
endif()
file(WRITE "${_src}/library/headers/public.h" "#include <fixture/core.h>\n#define HEADER_VALUE 11\n")
build()
file(SHA256 "${_archive}" _after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Declared header edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(REMOVE "${_public}" "${_host}")
run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklib-includes -j 2)
foreach(_header IN ITEMS "${_public}" "${_host}")
  file(SHA256 "${_header}" _copied)
  file(SHA256 "${_src}/library/headers/public.h" _source)
  if(NOT _copied STREQUAL _source)
    message(FATAL_ERROR "Missing header was not restored correctly: ${_header}")
  endif()
endforeach()
build()
file(WRITE "${_src}/core.h" "#define CORE_VALUE 6\n")
build()
file(SHA256 "${_archive}" _after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Late-registered interface edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_external}/value.h" "#define VALUE 3\n")
build()
file(SHA256 "${_archive}" _after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "External header edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_external}/second.c" "int second(void) { return 4; }\n")
build()
file(SHA256 "${_archive}" _after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Second external source edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_external}/asmvalue.h" "#define ASM_VALUE 9\n")
build()
file(SHA256 "${_archive}" _after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Assembly header edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_external}/extra.c" "int extra(void) { return 10; }\n")
run("${_cc}" -c "${_external}/extra.c" -o "${_external}/extra.o")
build()
file(SHA256 "${_archive}" _after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Explicit object edit did not rebuild the linklib")
endif()
file(REMOVE "${_archive}")
build()
if(NOT EXISTS "${_archive}")
  message(FATAL_ERROR "Missing archive was not recreated")
endif()
set(_native "${_root}/native.cfg")
file(WRITE "${_external}/second.c" "int second(void) { return LIB_VALUE; }\n")
file(READ "${_src}/library/mmakefile.src" _manifest)
string(REPLACE "USER_CFLAGS := -DRULE_C" "USER_CFLAGS := -DRULE_C -DLIB_VALUE=$(LIB_VALUE)" _manifest "${_manifest}")
file(WRITE "${_src}/library/mmakefile.src" "${_manifest}")
file(WRITE "${_native}" "LIB_VALUE=12\n")
run("${CMAKE_COMMAND}" -S "${_src}" -B "${_build}" "-DAROS_NATIVE_CONFIG_FILE=${_native}")
build()
file(SHA256 "${_archive}" _before)
file(WRITE "${_native}" "LIB_VALUE=13\n")
build()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Native config edit did not rebuild linklib flags")
endif()
file(TIMESTAMP "${_archive}" _stamp_before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
build()
file(TIMESTAMP "${_archive}" _stamp_after "%s")
if(NOT _stamp_before STREQUAL _stamp_after)
  message(FATAL_ERROR "Native config caused a no-op linklib rebuild")
endif()
file(WRITE "${_src}/library/headers/added.h" "#define ADDED 1\n")
file(APPEND "${_src}/library/mmakefile.src"
  "\n%copy_includes mmake=fixture-added includes=added.h dir=headers path=fixture\n")
build()
if(NOT EXISTS "${_build}/include/fixture/added.h")
  message(FATAL_ERROR "Manifest edit did not discover the new header declaration")
endif()
file(TIMESTAMP "${_archive}" _stamp_before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
build()
file(TIMESTAMP "${_archive}" _stamp_after "%s")
if(NOT _stamp_before STREQUAL _stamp_after)
  message(FATAL_ERROR "Shared header producers caused a no-op archive rebuild")
endif()
# A pre-existing generated header must not become an owned source by accident.
file(WRITE "${_build}/output/gen/rogue.h" "#define ROGUE 1\n")
file(APPEND "${_src}/library/mmakefile.src"
  "\n%copy_includes mmake=fixture-rogue includes=$(GENDIR)/rogue.h path=fixture\n")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "(Unowned|unowned|Unsafe|unsafe)")
  message(FATAL_ERROR "Unowned generated header was not rejected: ${_out}${_err}")
endif()
# Preserve explicitly marked existing codegen adapters, without automatic
# fallback from strict header discovery to the legacy glob stager.
file(WRITE "${_src}/library/mmakefile.src" "${_manifest}\n%copy_includes mmake=fixture-generated includes=fixture-generated.h dir=$(GENDIR)/$(CURDIR)/generated path=generated\n")
file(WRITE "${_src}/generated-input.h" "#define GENERATED_VALUE 7\n")
set(_build "${_root}/legacy-adapter-build")
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}"
  "-DAROS_TEST_SOURCE=${_repo}" "-DAROS_NATIVE_CONFIG_FILE=${_native}"
  -DTEST_LEGACY_GENERATED_HEADERS=ON)
build()
file(SHA256 "${_build}/include/generated/fixture-generated.h" _before)
file(WRITE "${_src}/generated-input.h" "#define GENERATED_VALUE 8\n")
build()
file(SHA256 "${_build}/include/generated/fixture-generated.h" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Explicit legacy codegen dependency did not restage its header")
endif()
file(MAKE_DIRECTORY "${_src}/archive-input/pkg" "${_src}/archives")
file(WRITE "${_src}/archive-input/pkg/public.h" "#include <fixture/core.h>\n#define HEADER_VALUE 40\n")
file(WRITE "${_src}/archive-input/pkg/fetched.c" "int fetched(void) { return 25; }\n")
file(WRITE "${_src}/archive-input/pkg/fetched.S" ".data\n.long 31\n")
file(WRITE "${_src}/fetch-object.c" "int fetched_object(void) { return 35; }\n")
run("${_cc}" -c "${_src}/fetch-object.c" -o "${_src}/archive-input/pkg/fetched-object.o")
function(pack_headers)
  execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_src}/archives/pkg.tar.gz"
    --format=gnutar pkg WORKING_DIRECTORY "${_src}/archive-input" COMMAND_ERROR_IS_FATAL ANY)
endfunction()
pack_headers()
file(APPEND "${_config}/target.cfg" [=[
WILDCARD = $(shell cd $(SRCDIR)/$(CURDIR); for file in $(1); do if [ -f $$file ]; then printf "%s" "$$file "; fi; done)
]=])
string(REPLACE "includes=public.h dir=headers"
  "includes=\"$(call WILDCARD, $(TARGETDIR)/Ports/pkg/pkg/*.h)\" dir=$(TARGETDIR)/Ports/pkg/pkg"
  _fetch_manifest "${_manifest}")
file(COPY "${_external}/" DESTINATION "${_src}/local-sources")
string(REPLACE "$(PORTSDIR)/" "$(SRCDIR)/local-sources/" _fetch_manifest "${_fetch_manifest}")
string(REPLACE "$(addprefix $(SRCDIR)/local-sources/,$(addsuffix .c,$(FILES)))"
  "$(addprefix $(SRCDIR)/local-sources/,$(addsuffix .c,$(FILES))) $(TARGETDIR)/Ports/pkg/pkg/fetched.c"
  _fetch_manifest "${_fetch_manifest}")
string(REPLACE "asmfiles=$(SRCDIR)/local-sources/data.S"
  "asmfiles=$(SRCDIR)/local-sources/data.S $(TARGETDIR)/Ports/pkg/pkg/fetched.S"
  _fetch_manifest "${_fetch_manifest}")
string(REPLACE "objs=$(SRCDIR)/local-sources/extra.o"
  "objs=$(SRCDIR)/local-sources/extra.o $(TARGETDIR)/Ports/pkg/pkg/fetched-object.o"
  _fetch_manifest "${_fetch_manifest}")
file(WRITE "${_src}/library/mmakefile.src" "${_fetch_manifest}\n")
file(APPEND "${_src}/library/mmakefile.src" [=[
#MM fixture-headers: fixture-bridge-includes
%fetch mmake=fixture-fetch archive=pkg suffixes=tar.gz location=$(SRCDIR)/archives destination=$(TARGETDIR)/Ports/pkg
]=])
file(MAKE_DIRECTORY "${_src}/fetch-bridge")
file(WRITE "${_src}/fetch-bridge/bridge.h" "#define FETCH_BRIDGE 1\n")
file(WRITE "${_src}/fetch-bridge/mmakefile.src" [=[
#MM fixture-bridge-includes: fixture-fetch-alias
#MM fixture-fetch-alias: fixture-fetch
%copy_includes mmake=fixture-bridge-includes includes=bridge.h path=bridge
]=])
set(_build "${_root}/fetched-headers-build")
set(_archive "${_build}/lib/libfixture.a")
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}"
  "-DAROS_TEST_SOURCE=${_repo}" "-DAROS_NATIVE_CONFIG_FILE=${_native}" -DTEST_FETCHED_HEADERS=ON)
function(build_prepared)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "native sources prepared; run the build again")
    message(FATAL_ERROR "Expected an explicit native preparation handoff: ${_out}${_err}")
  endif()
  build()
endfunction()
build_prepared()
file(SHA256 "${_archive}" _before)
file(WRITE "${_src}/archive-input/pkg/public.h" "#include <fixture/core.h>\n#define HEADER_VALUE 41\n")
pack_headers()
build_prepared()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Fetched header edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_src}/archive-input/pkg/fetched.c" "int fetched(void) { return 26; }\n")
pack_headers()
build_prepared()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Fetched C source edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_src}/archive-input/pkg/fetched.S" ".data\n.long 32\n")
pack_headers()
build_prepared()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Fetched assembly edit did not rebuild the linklib")
endif()
set(_before "${_after}")
file(WRITE "${_src}/fetch-object.c" "int fetched_object(void) { return 36; }\n")
run("${_cc}" -c "${_src}/fetch-object.c" -o "${_src}/archive-input/pkg/fetched-object.o")
pack_headers()
build_prepared()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Fetched object edit did not rebuild the linklib")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do")
  message(FATAL_ERROR "Fetched header linklib did not settle to a no-op: ${_out}${_err}")
endif()
# Replay Ninja's native archive command without configure/header-copy steps:
# the compiler entrypoint itself must verify the prepared source tree.
find_program(_ninja NAMES ninja REQUIRED)
execute_process(COMMAND "${_ninja}" -C "${_build}" -t commands lib/libfixture.a
  OUTPUT_VARIABLE _commands COMMAND_ERROR_IS_FATAL ANY)
string(REPLACE "\n" ";" _commands "${_commands}")
list(FILTER _commands INCLUDE REGEX "build_mmake_linklib[.]cmake")
list(GET _commands -1 _command)
file(WRITE "${_build}/output/Ports/pkg/pkg/fetched.c" "int fetched(void) { return 99; }\n")
execute_process(COMMAND sh -c "${_command}" WORKING_DIRECTORY "${_build}"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "(modified|changed|mismatch)")
  message(FATAL_ERROR "Archive compiler did not reject modified fetched source: ${_out}${_err}")
endif()
configure_file("${_src}/archive-input/pkg/fetched.c" "${_build}/output/Ports/pkg/pkg/fetched.c" COPYONLY)
# Keep the extracted source, but remove its manifest authorization. No legacy
# source path or old native file may satisfy the next archive build.
string(REPLACE "includes=\"$(call WILDCARD, $(TARGETDIR)/Ports/pkg/pkg/*.h)\" dir=$(TARGETDIR)/Ports/pkg/pkg"
  "includes=public.h dir=headers" _orphan_manifest "${_fetch_manifest}")
file(WRITE "${_src}/library/mmakefile.src" "${_orphan_manifest}\n")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Unowned native linklib source")
  message(FATAL_ERROR "Removed fetch edge did not reject old native source: ${_out}${_err}")
endif()
# Library-owned preparation must not depend on a local copy_includes macro.
file(WRITE "${_src}/local-sources/headerless-local.c" "int local_value(void) { return 5; }\n")
set(_headerless [=[
#MM fixture-library: library-source-alias
#MM library-source-alias: fixture-fetch
%fetch mmake=fixture-fetch archive=pkg suffixes=tar.gz location=$(SRCDIR)/archives destination=$(TARGETDIR)/Ports/pkg
%build_linklib mmake=fixture-library libname=fixture files=$(TARGETDIR)/Ports/pkg/pkg/fetched.c
%build_linklib mmake=fixture-second libname=second files=$(SRCDIR)/local-sources/headerless-local.c
]=])
file(WRITE "${_src}/library/mmakefile.src" "${_headerless}")
set(_build "${_root}/headerless-build")
set(_archive "${_build}/lib/libfixture.a")
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}"
  "-DAROS_TEST_SOURCE=${_repo}" "-DAROS_NATIVE_CONFIG_FILE=${_native}" -DTEST_FETCHED_HEADERS=ON)
build_prepared()
function(headerless_noop)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "no work to do"
      OR "${_out}${_err}" MATCHES "Re-running CMake")
    message(FATAL_ERROR "Expected settled headerless linklibs: ${_out}${_err}")
  endif()
endfunction()
function(headerless_build)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0)
    if(NOT "${_out}${_err}" MATCHES "native sources prepared; run the build again")
      message(FATAL_ERROR "Unexpected linklib failure: ${_out}${_err}")
    endif()
    build()
  endif()
endfunction()
headerless_noop()
file(SHA256 "${_archive}" _before)
file(WRITE "${_src}/archive-input/pkg/fetched.c" "int fetched(void) { return 53; }\n")
pack_headers()
build_prepared()
file(SHA256 "${_archive}" _after)
if(_before STREQUAL _after)
  message(FATAL_ERROR "Library-owned archive edit did not rebuild the linklib")
endif()
file(REMOVE "${_archive}")
build()
headerless_noop()
file(REMOVE_RECURSE "${_build}/output/Ports/pkg")
build_prepared()
headerless_noop()

# New top-level metadata augments the selected library, not a header identity.
file(MAKE_DIRECTORY "${_src}/archive-input/addition" "${_src}/library-augmentation")
file(WRITE "${_src}/archive-input/addition/extra.c" "int added(void) { return 7; }\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${_src}/archives/addition.tar.gz" addition
  WORKING_DIRECTORY "${_src}/archive-input" COMMAND_ERROR_IS_FATAL ANY)
set(_augmentation [=[
#MM fixture-library: additional-fetch
%fetch mmake=additional-fetch archive=addition suffixes=tar.gz location=$(SRCDIR)/archives destination=$(TARGETDIR)/Ports/addition
]=])
file(WRITE "${_src}/library-augmentation/mmakefile.src" "${_augmentation}")
string(REPLACE "files=$(TARGETDIR)/Ports/pkg/pkg/fetched.c"
  "files=\"$(TARGETDIR)/Ports/pkg/pkg/fetched.c $(TARGETDIR)/Ports/addition/addition/extra.c\""
  _multiple "${_headerless}")
file(WRITE "${_src}/library/mmakefile.src" "${_multiple}")
build_prepared()
headerless_noop()
execute_process(COMMAND "${_cc}" -print-prog-name=nm OUTPUT_VARIABLE _nm OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND "${_nm}" "${_archive}" OUTPUT_VARIABLE _symbols COMMAND_ERROR_IS_FATAL ANY)
if(NOT _symbols MATCHES "added" OR NOT _symbols MATCHES "fetched")
  message(FATAL_ERROR "Both receipt-owned source trees must contribute archive members: ${_symbols}")
endif()
file(REMOVE "${_src}/library-augmentation/mmakefile.src")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Unowned native linklib source")
  message(FATAL_ERROR "Removed library fetch edge adopted an old source tree: ${_out}${_err}")
endif()
file(WRITE "${_src}/library/mmakefile.src" "${_headerless}")
headerless_build()
headerless_noop()
file(APPEND "${_src}/library/mmakefile.src" "#MM library-source-alias: fixture-library\n")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "dependency cycle")
  message(FATAL_ERROR "Library source cycle was not rejected: ${_out}${_err}")
endif()
file(WRITE "${_src}/library/mmakefile.src" "${_headerless}")
headerless_build()
headerless_noop()

# A prerequisite library owns its receipt even before it is registered.
string(REPLACE "fixture-library: library-source-alias" "fixture-library: private-library"
  _private "${_headerless}")
string(APPEND _private [=[
#MM private-library: fixture-fetch
%build_linklib mmake=private-library libname=private files=$(TARGETDIR)/Ports/pkg/pkg/fetched.c
]=])
file(WRITE "${_src}/library/mmakefile.src" "${_private}")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-linklibs -j 2
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Unowned native linklib source")
  message(FATAL_ERROR "Prerequisite library granted private source ownership: ${_out}${_err}")
endif()
file(WRITE "${_src}/library/mmakefile.src" "${_headerless}")
headerless_build()
headerless_noop()
message(STATUS "Make linklib header/affix/depfile and library-owned fetch checks passed: ${_root}")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DTEST_BINARY_DIR=${TEST_BINARY_DIR}/options"
  -P "${CMAKE_CURRENT_LIST_DIR}/mmake_linklib_options.cmake" COMMAND_ERROR_IS_FATAL ANY)
