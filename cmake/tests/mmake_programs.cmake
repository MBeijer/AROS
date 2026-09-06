cmake_minimum_required(VERSION 3.20)
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
file(MAKE_DIRECTORY "${_src}/commands" "${_src}/include"
  "${_src}/config-snapshot/bin/linux-x86_64/gen/config")
configure_file("${CMAKE_CURRENT_LIST_DIR}/programs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
file(WRITE "${_src}/config-snapshot/bin/linux-x86_64/gen/config/target.cfg" [=[
FAMILY := unix
CPPFLAGS = $(USER_CPPFLAGS)
CFLAGS = $(USER_CFLAGS)
LDFLAGS = $(USER_LDFLAGS)
NOSTARTUP_LDFLAGS := -nostartfiles
TARGET_STRIP := test-aros-strip --strip-unneeded -R.comment
]=])
file(WRITE "${_src}/include/value.h" "#define VALUE 1\n")
file(WRITE "${_src}/extra.h" "#define EXTRA_VALUE 4\n")
file(WRITE "${_src}/support.c" "int support(void) { return 5; }\n")
file(WRITE "${_src}/commands/First.c" [=[
#include <value.h>
#include <proto/extra.h>
#ifndef RULE_FLAG
#error missing rule flag
#endif
#ifdef LATER_FLAG
#error later rule leaked
#endif
#if SECOND_FLAG != 2
#error missing bare flag with equals
#endif
volatile int result;
extern int support(void);
void _start(void) { result = VALUE + EXTRA_VALUE + support(); }
]=])
file(WRITE "${_src}/commands/Second.c" "volatile int second; void _start(void) { second = 2; }\n")
set(_manifest [=[
FILES := \
    First
USER_CPPFLAGS := -DRULE_FLAG="\"quoted value\"" -DSECOND_FLAG=2
USER_CFLAGS := -O2
include flags.opts
USER_LDFLAGS := -nostdlib -no-pie
%build_progs mmake=fixture-commands \
    files=$(FILES) targetdir=$(AROSDIR)/C \
    usestartup=no uselibs=fixture
USER_CPPFLAGS := -DLATER_FLAG
%build_prog mmake=unselected progname=Unused cxxfiles=unsupported
]=])
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
file(WRITE "${_src}/commands/flags.opts" "USER_CPPFLAGS += -DOPTION_INITIAL\n")

function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs -j 2)
endfunction()
set(_output "${_build}/output/AROS/C/First")
function(timestamp out)
  file(TIMESTAMP "${_output}" _stamp "%s")
  set(${out} "${_stamp}" PARENT_SCOPE)
endfunction()
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}" "-DAROS_TEST_SOURCE=${_repo}")
build()
if(NOT EXISTS "${_output}")
  message(FATAL_ERROR "Manifest program was not built")
endif()
timestamp(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
build()
timestamp(_after)
if(NOT _after STREQUAL _before)
  message(FATAL_ERROR "No-op build relinked the program")
endif()
file(WRITE "${_src}/commands/flags.opts" "USER_CPPFLAGS += -DOPTION_UPDATED\n")
build()
include("${_build}/programs/fixture-programs/program.cmake")
if(NOT "-DOPTION_UPDATED" IN_LIST MMAKE_PROGRAM_COMPILE_FLAGS
   OR NOT "${_src}/commands/flags.opts" IN_LIST MMAKE_PROGRAM_INPUTS)
  message(FATAL_ERROR "Options edit did not update program metadata dependencies")
endif()
run("${CMAKE_COMMAND}" -E sleep 1)
file(APPEND "${_src}/config-snapshot/bin/linux-x86_64/gen/config/target.cfg" "SAFETY_CFLAGS := -DCONFIG_CHANGED\n")
build()
include("${_build}/programs/fixture-programs/program.cmake")
if(NOT "-DCONFIG_CHANGED" IN_LIST MMAKE_PROGRAM_COMPILE_FLAGS)
  message(FATAL_ERROR "Configuration edit did not regenerate program flags")
endif()
timestamp(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
file(WRITE "${_src}/include/value.h" "#define VALUE 3\n")
build()
timestamp(_after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "SDK header edit did not rebuild the program")
endif()
timestamp(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
file(WRITE "${_src}/extra.h" "#define EXTRA_VALUE 6\n")
build()
timestamp(_after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Header-only SDK interface edit did not rebuild the program")
endif()
timestamp(_before)
file(TIMESTAMP "${_build}/programs/fixture-programs/obj/0.o" _object_before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
file(WRITE "${_src}/support.c" "int support(void) { return 9; }\n")
build()
timestamp(_after)
file(TIMESTAMP "${_build}/programs/fixture-programs/obj/0.o" _object_after "%s")
if(_after STREQUAL _before OR NOT _object_before STREQUAL _object_after)
  message(FATAL_ERROR "Archive edit must relink, not recompile, the program")
endif()
string(REPLACE "    First\n" "    First \\\n    Second\n" _manifest "${_manifest}")
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
build()
if(NOT EXISTS "${_build}/output/AROS/C/Second")
  message(FATAL_ERROR "Manifest edit did not add a program through ordinary build")
endif()
file(REMOVE "${_output}")
build()
if(NOT EXISTS "${_output}")
  message(FATAL_ERROR "Deleted output was not recreated")
endif()

set(_context "${_build}/programs/fixture-programs/context.cmake")
function(expect_rejected text reason)
  file(WRITE "${_src}/commands/mmakefile.src" "${text}\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" "-DCONTEXT_FILE=${_context}"
    "-DOUTPUT_FILE=${_root}/rejected.cmake" -P "${_repo}/cmake/collect_mmake_program.cmake"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  string(REGEX REPLACE "[ \t\r\n]+" " " _diagnostic "${_out}${_err}")
  if(_result EQUAL 0 OR NOT _diagnostic MATCHES "${reason}")
    message(FATAL_ERROR "Expected rejection (${reason}), got ${_result}: ${_out}${_err}")
  endif()
endfunction()
set(_rule "%build_prog mmake=fixture-commands progname=First targetdir=\$(AROSDIR)/C uselibs=fixture")
expect_rejected("${_rule} usestartup=maybe" "Invalid usestartup")
expect_rejected("${_rule} usestartup=no cxxfiles=First" "cxxfiles needs native implementation")
expect_rejected("${_rule} usestartup=no dflags=-M" "dflags needs native implementation")
expect_rejected("DEBUG := yes\n${_rule} usestartup=no" "needs native debug sidecar support")
expect_rejected("${_rule} usestartup=no lto=yes" "lto=yes needs native implementation")
expect_rejected("${_rule} usestartup=no nonexistent=value" "Unsupported program argument")
expect_rejected("${_rule} usestartup=no files=Missing" "missing or unsupported C source")
expect_rejected("${_rule} usestartup=no\n${_rule} usestartup=no" "Multiple active program rules")
file(WRITE "${_build}/generated.c" "void _start(void) {}\n")
expect_rejected("${_rule} usestartup=no files=${_build}/generated.c" "source needs a native producer")

function(expect_config_rejected text reason)
  file(WRITE "${_src}/commands/mmakefile.src" "USER_LDFLAGS := -nostdlib -no-pie\n${text}\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_build}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  string(REGEX REPLACE "[ \t\r\n]+" " " _diagnostic "${_out}${_err}")
  if(_result EQUAL 0 OR NOT _diagnostic MATCHES "${reason}")
    message(FATAL_ERROR "Expected configure rejection (${reason}), got ${_result}: ${_out}${_err}")
  endif()
endfunction()
expect_config_rejected("${_rule} usestartup=no\n#MM fixture-commands : missing-codegen\n%unsupported_codegen mmake=missing-codegen" "needs native support for %unsupported_codegen")
expect_config_rejected("${_rule} usestartup=no\n#MM fixture-commands : local-codegen\nlocal-codegen :\n\t@echo unsupported" "Unsupported static prerequisite recipe")
expect_config_rejected("%build_prog mmake=fixture-commands progname=First targetdir=/outside usestartup=no" "destination outside native runtime tree")
expect_config_rejected("%build_prog mmake=fixture-commands progname=First usestartup=no uselibs=missing" "needs a native archive producer")
expect_config_rejected("ifdef UNKNOWN\n${_rule} usestartup=no\nendif" "Unsupported rule conditional")

# build_prog defaults to progname.c and links all explicitly listed objects.
file(WRITE "${_src}/commands/helper.c" "int helper(void) { return 7; }\n")
file(WRITE "${_src}/commands/mmakefile.src" "${_rule} usestartup=no files=First helper ldflags=\"-nostdlib -no-pie\" cppflags=-DRULE_FLAG -DSECOND_FLAG=2\n")
build()
include("${_build}/programs/fixture-programs/program.cmake")
list(LENGTH MMAKE_PROGRAM_SOURCES _count)
if(NOT _count EQUAL 2 OR NOT MMAKE_PROGRAM_KIND STREQUAL "prog")
  message(FATAL_ERROR "build_prog lost its explicit multi-object source list")
endif()
file(WRITE "${_src}/commands/mmakefile.src" "${_rule} usestartup=no ldflags=\"-nostdlib -no-pie\" cppflags=-DRULE_FLAG -DSECOND_FLAG=2\n")
build()
include("${_build}/programs/fixture-programs/program.cmake")
if(NOT MMAKE_PROGRAM_SOURCES STREQUAL "${_src}/commands/First.c")
  message(FATAL_ERROR "build_prog did not default to progname.c")
endif()

# Compiler-default libraries must select native producers too, without an
# explicit uselibs entry or a dependency on unrelated SDK interfaces.
set(_specs "${_src}/compiler.specs")
set(_spec_text "*lib:\n-lfixture\n\n*libgcc:\n-lgcc\n\n*link_gcc_c_sequence:\n%G %L %G\n\n")
file(WRITE "${_specs}" "${_spec_text}")
set(_default_rule "%build_prog mmake=fixture-commands progname=First targetdir=\$(AROSDIR)/C usestartup=no ldflags=\"-specs=${_specs} -no-pie\" cppflags=-DRULE_FLAG -DSECOND_FLAG=2")
file(WRITE "${_src}/commands/mmakefile.src" "${_default_rule}\n")
build()
timestamp(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
file(WRITE "${_src}/support.c" "int support(void) { return 11; }\n")
build()
timestamp(_after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Compiler-default archive change did not relink")
endif()
string(REPLACE "-lfixture" "-lmissingdefault" _missing_specs "${_spec_text}")
file(WRITE "${_specs}" "${_missing_specs}")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(REGEX REPLACE "[ \t\r\n]+" " " _diagnostic "${_out}${_err}")
if(_result EQUAL 0 OR NOT _diagnostic MATCHES "native archive producer for missingdefault")
  message(FATAL_ERROR "Specs edit did not validate new compiler defaults: ${_out}${_err}")
endif()
file(WRITE "${_specs}" "${_spec_text}")
build()
timestamp(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
string(REPLACE "%G %L %G" "%G %L %G --defsym=SPEC_EDIT=1" _edited_specs "${_spec_text}")
file(WRITE "${_specs}" "${_edited_specs}")
build()
timestamp(_after)
if(_after STREQUAL _before)
  message(FATAL_ERROR "Specs edit with unchanged library names did not relink")
endif()

# Clean configuration may precede compiler installation. Installing it later
# must activate the real program graph on an ordinary build, without caching
# a dummy success or requiring the entire configure to fail first.
set(_empty_build "${_root}/before-toolchain")
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_empty_build}"
  "-DAROS_TEST_SOURCE=${_repo}" -DAROS_TEST_INSTALL_COMPILER=OFF)
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_empty_build}" --target fixture-programs
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "build/install the target compiler")
  message(FATAL_ERROR "Missing compiler did not produce an actionable build failure: ${_out}${_err}")
endif()
foreach(_tool IN ITEMS gcc strip)
  file(REAL_PATH "${_build}/toolchain/test-aros-${_tool}" _real_tool)
  file(CREATE_LINK "${_real_tool}" "${_empty_build}/toolchain/test-aros-${_tool}" SYMBOLIC)
endforeach()
run("${CMAKE_COMMAND}" --build "${_empty_build}" --target fixture-programs -j 2)
if(NOT EXISTS "${_empty_build}/output/AROS/C/First")
  message(FATAL_ERROR "Compiler installation did not activate program registration")
endif()

# Even a registered library must not be shadowed by an external/toolchain copy.
file(MAKE_DIRECTORY "${_root}/external")
configure_file("${_build}/output/AROS/Development/lib/libfixture.a"
  "${_root}/external/libfixture.a" COPYONLY)
set(_external_metadata "${_root}/external/program.cmake")
file(WRITE "${_external_metadata}" "include([==[${_build}/programs/fixture-programs/program.cmake]==])\nlist(PREPEND MMAKE_PROGRAM_LINK_FLAGS [==[-L${_root}/external]==])\n")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DCONTEXT_FILE=${_context}"
  "-DMETADATA_FILE=${_external_metadata}" -DMODE=LINK
  "-DOBJECT_FILES=${_build}/programs/fixture-programs/obj/0.o"
  "-DOUTPUT_FILE=${_root}/external/Rejected" -P "${_repo}/cmake/build_mmake_program.cmake"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
string(REGEX REPLACE "[ \t\r\n]+" " " _diagnostic "${_out}${_err}")
if(_result EQUAL 0 OR NOT _diagnostic MATCHES "archive outside the native SDK"
    OR EXISTS "${_root}/external/Rejected")
  message(FATAL_ERROR "External archive fallback was not rejected: ${_out}${_err}")
endif()
# Startup objects are selected by compiler specs and built from manifest rules,
# not copied from an installed SDK. Later rule flags must remain local.
file(MAKE_DIRECTORY "${_src}/runtime")
file(WRITE "${_src}/runtime/entry.h" "#define ENTRY_VALUE 3\n")
file(WRITE "${_src}/runtime/entry.c" [=[
#include "entry.h"
#include <proto/extra.h>
#if !defined(ENTRY_FLAG) || defined(LATER_ENTRY_FLAG)
#error wrong rule-local startup flags
#endif
extern int main(void);
volatile int result;
void _start(void) { result = main() + ENTRY_VALUE + EXTRA_VALUE; }
]=])
file(WRITE "${_src}/commands/First.c" "int main(void) { return 9; }\n")
file(REMOVE "${_src}/include/proto/extra.h")
set(_entry_manifest [=[
FILES := entry
ifneq (,$(findstring arm,$(AROS_TARGET_CPU)))
FILES += absent-arm
endif
OBJS := $(addprefix $(AROS_LIB)/,$(addsuffix .o,$(FILES)))
runtime-objects: $(OBJS)
$(AROS_LIB)/%.o: $(GENDIR)/$(CURDIR)/%.o
	@$(CP) $< $@
USER_CPPFLAGS := -DENTRY_FLAG
%rule_compile basename=% targetdir=$(GENDIR)/$(CURDIR)
USER_CPPFLAGS := -DLATER_ENTRY_FLAG
%rule_compile basename=% targetdir=$(GENDIR)/$(CURDIR)/later
]=])
file(WRITE "${_src}/runtime/mmakefile.src" "${_entry_manifest}")
set(_entry_specs "${_spec_text}*startfile:\nentry.o%s\n\n*endfile:\n\n\n")
file(WRITE "${_specs}" "${_entry_specs}")
file(WRITE "${_src}/commands/mmakefile.src"
  "%build_prog mmake=fixture-commands progname=First targetdir=\$(AROSDIR)/C ldflags=\"-specs=${_specs} -no-pie\"\n")
build()
set(_entry "${_build}/output/AROS/Development/lib/entry.o")
if(NOT EXISTS "${_entry}")
  message(FATAL_ERROR "Compiler-selected native startup object was not built")
endif()
timestamp(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
build()
timestamp(_after)
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "Startup program no-op build relinked")
endif()
foreach(_change IN ITEMS header source manifest missing-object)
  timestamp(_before)
  run("${CMAKE_COMMAND}" -E sleep 1)
  if(_change STREQUAL "header")
    file(WRITE "${_src}/runtime/entry.h" "#define ENTRY_VALUE 7\n")
  elseif(_change STREQUAL "source")
    file(APPEND "${_src}/runtime/entry.c" "int added_entry_data = 12;\n")
  elseif(_change STREQUAL "manifest")
    string(REPLACE "-DENTRY_FLAG" "-DENTRY_FLAG -DENTRY_CHANGED" _entry_manifest "${_entry_manifest}")
    file(WRITE "${_src}/runtime/mmakefile.src" "${_entry_manifest}")
  else()
    file(REMOVE "${_entry}")
  endif()
  build()
  timestamp(_after)
  if(_before STREQUAL _after)
    message(FATAL_ERROR "Startup ${_change} did not rebuild/relink")
  endif()
endforeach()
# An absolute startup path in specs must not bypass native object ownership.
configure_file("${_entry}" "${_root}/external/entry.o" COPYONLY)
string(REPLACE "entry.o%s" "${_root}/external/entry.o" _external_specs "${_entry_specs}")
file(WRITE "${_root}/external/startup.specs" "${_external_specs}")
file(WRITE "${_root}/external/startup.cmake"
  "include([==[${_build}/programs/fixture-programs/program.cmake]==])\nset(MMAKE_PROGRAM_LINK_FLAGS -specs=${_root}/external/startup.specs -no-pie)\n")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DCONTEXT_FILE=${_context}"
  "-DMETADATA_FILE=${_root}/external/startup.cmake" -DMODE=LINK "-DSTARTUP_OBJECTS=${_entry}"
  "-DOBJECT_FILES=${_build}/programs/fixture-programs/obj/0.o"
  "-DOUTPUT_FILE=${_root}/external/RejectedStartup" -P "${_repo}/cmake/build_mmake_program.cmake"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "unowned startup/object input"
   OR EXISTS "${_root}/external/RejectedStartup")
  message(FATAL_ERROR "External startup fallback was not rejected: ${_out}${_err}")
endif()

# Exercise icon input/output discovery and prerequisite ordering with a tiny
# deterministic stand-in. Real ilbmtoicon output parity is checked in AROS.
file(WRITE "${_src}/test-icon.c" [=[
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 4) return 1;
    FILE *out = fopen(argv[3], "wb");
    if (!out) return 2;
    for (int i = 1; i < 3; ++i) {
        FILE *in = fopen(argv[i], "rb");
        if (!in) return 3;
        int ch;
        while ((ch = fgetc(in)) != EOF) fputc(ch, out);
        fclose(in);
    }
    return fclose(out);
}
]=])
file(MAKE_DIRECTORY "${_src}/art")
file(WRITE "${_src}/art/Monitor.info.src" "TYPE=TOOL\n")
file(WRITE "${_src}/art/picture.png" "first image\n")
file(WRITE "${_src}/art/alternate.png" "alternate image\n")
file(WRITE "${_src}/config-snapshot/Makefile" "export ICON_TAG := one\n")
file(WRITE "${_src}/art/mmakefile.src" [=[
ICONS := Monitor
%build_icons mmake=fixture-icons-one icons=$(ICONS) dir=$(AROSDIR)/Devs/Monitors image=picture.png
%build_icons mmake=fixture-icons-two icons=$(ICONS) dir=$(AROSDIR)/Devs/Monitors image=alternate.png
]=])
file(APPEND "${_src}/commands/mmakefile.src" "#MM fixture-commands : fixture-icons-$(ICON_TAG)\n")
build()
set(_icon "${_build}/output/AROS/Devs/Monitors/Monitor.info")
file(READ "${_icon}" _icon_data)
if(NOT _icon_data STREQUAL "TYPE=TOOL\nfirst image\n")
  message(FATAL_ERROR "Icon macro lost its input paths or argument ordering")
endif()
timestamp(_before)
foreach(_change IN ITEMS image metadata missing-icon)
  run("${CMAKE_COMMAND}" -E sleep 1)
  if(_change STREQUAL "image")
    file(WRITE "${_src}/art/picture.png" "new image\n")
  elseif(_change STREQUAL "metadata")
    file(WRITE "${_src}/art/Monitor.info.src" "TYPE=PROJECT\n")
  else()
    file(REMOVE "${_icon}")
  endif()
  build()
  if(NOT EXISTS "${_icon}")
    message(FATAL_ERROR "Icon ${_change} did not generate its output")
  endif()
  file(READ "${_icon}" _icon_data)
  if(_change STREQUAL "image" AND NOT _icon_data STREQUAL "TYPE=TOOL\nnew image\n")
    message(FATAL_ERROR "Image edit did not regenerate the icon")
  endif()
endforeach()
file(READ "${_icon}" _icon_data)
timestamp(_after)
if(NOT _icon_data STREQUAL "TYPE=PROJECT\nnew image\n" OR NOT _before STREQUAL _after)
  message(FATAL_ERROR "Icon-only changes must rebuild the icon without relinking its consumer")
endif()
file(TIMESTAMP "${_icon}" _icon_before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
build()
file(TIMESTAMP "${_icon}" _icon_after "%s")
if(NOT _icon_before STREQUAL _icon_after)
  message(FATAL_ERROR "No-op build regenerated an icon")
endif()
file(WRITE "${_src}/config-snapshot/Makefile" "export ICON_TAG := two\n")
build()
file(READ "${_icon}" _icon_data)
timestamp(_after)
if(NOT _icon_data STREQUAL "TYPE=PROJECT\nalternate image\n" OR NOT _before STREQUAL _after)
  message(FATAL_ERROR "Exported icon configuration change did not select the new native producer")
endif()
file(READ "${_src}/art/mmakefile.src" _icon_manifest)
configure_file("${_src}/art/Monitor.info.src" "${_src}/config-snapshot/Monitor.info.src" COPYONLY)
configure_file("${_src}/art/alternate.png" "${_src}/config-snapshot/Monitor.png" COPYONLY)
file(WRITE "${_src}/art/mmakefile.src"
  "%build_icons mmake=fixture-icons-two icons=Monitor dir=$(AROSDIR)/Devs/Monitors srcdir=${_src}/config-snapshot\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_build}"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Icon requires an owned static source")
  message(FATAL_ERROR "Generated icon input was silently adopted: ${_out}${_err}")
endif()
file(WRITE "${_src}/art/mmakefile.src" "${_icon_manifest}")
foreach(_constraint IN ITEMS
    "$(AROS_LIB)/entry.o: extra-input"
    "$(GENDIR)/$(CURDIR)/entry.o: extra-input")
  file(WRITE "${_src}/runtime/mmakefile.src" "${_entry_manifest}\n${_constraint}\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_build}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "SDK object (copy rule|compile prerequisites)")
    message(FATAL_ERROR "SDK object constraint was silently ignored: ${_out}${_err}")
  endif()
endforeach()
file(WRITE "${_src}/runtime/mmakefile.src" "${_entry_manifest}")
file(WRITE "${_src}/runtime/mmakefile.src" "# no native producer\n")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "native SDK object producer")
  message(FATAL_ERROR "Existing startup object hid a missing producer: ${_out}${_err}")
endif()
message(STATUS "Target-program rules, compiler-selected startup objects, rebuilds and no-op checks passed")
