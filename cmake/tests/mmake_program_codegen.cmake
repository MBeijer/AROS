cmake_minimum_required(VERSION 3.20)
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
set(_obj "${_build}/programs/fixture-programs/obj")
find_program(_bison bison REQUIRED)
file(MAKE_DIRECTORY "${_src}/commands" "${_src}/include"
  "${_src}/config-snapshot/bin/linux-x86_64/gen/config")
configure_file("${CMAKE_CURRENT_LIST_DIR}/programs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
file(WRITE "${_src}/config-snapshot/bin/linux-x86_64/gen/config/target.cfg" [=[
FAMILY := unix
CPPFLAGS = $(USER_CPPFLAGS)
CFLAGS = $(USER_CFLAGS) $(USER_INCLUDES)
LDFLAGS = $(USER_LDFLAGS)
NOSTARTUP_LDFLAGS := -nostartfiles
]=])
file(WRITE "${_src}/extra.h" "#define EXTRA_VALUE 4\n")
file(WRITE "${_src}/support.c" "int support(void) { return 5; }\n")
file(MAKE_DIRECTORY "${_src}/config")
file(WRITE "${_src}/config/aros.cfg" "include $(TOP)/config/make.cfg\n")
file(WRITE "${_src}/commands/First.c" [=[
#include "parser.tab.c"
volatile int result;
void _start(void) { result = yyparse(); }
]=])
file(WRITE "${_src}/commands/Second.c" "volatile int result; void _start(void) { result = 2; }\n")
set(_grammar [=[
%{
#include <proto/extra.h>
#define YYMALLOC(n) ((void *)0)
#define YYFREE(p) ((void)0)
#define YYSTACK_USE_ALLOCA 0
static int yylex(void) { return EXTRA_VALUE == 4 ? 0 : 1; }
static void yyerror(const char *s) { (void)s; }
%}
%%
input: %empty { $$ = 1; };
%%
]=])
file(WRITE "${_src}/commands/parser.y" "${_grammar}")
set(_manifest [=[
include $(SRCDIR)/config/aros.cfg
USER_INCLUDES := -I$(OBJDIR)
USER_CFLAGS := -O2
USER_LDFLAGS := -nostdlib -no-pie
$(OBJDIR)/parser.tab.c : parser.y
	@$(ECHO) Generating $(notdir $@) from $<...
	@$(BISON) -o $@ $<
%build_progs mmake=fixture-commands files="First Second" targetdir=$(AROSDIR)/C usestartup=no
$(OBJDIR)/First.d : $(OBJDIR)/parser.tab.c
BISON := @BISON@
%build_prog mmake=unselected progname=Unused cxxfiles=unsupported
$(unselected_DEPS) : $(OBJDIR)/unsupported.c
$(OBJDIR)/unsupported.c : parser.y
	$(EXECUTE_ARBITRARY_RECIPE)
]=])
file(CREATE_LINK "${_bison}" "${_root}/selected-bison" SYMBOLIC)
string(REPLACE "@BISON@" "${_root}/selected-bison" _manifest "${_manifest}")
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs -j 4)
endfunction()
function(stamps out)
  set(_stamps)
  foreach(_path IN ITEMS "${_obj}/parser.tab.c" "${_obj}/0.o" "${_obj}/1.o"
      "${_build}/output/AROS/C/First" "${_build}/output/AROS/C/Second")
    if(NOT EXISTS "${_path}")
      message(FATAL_ERROR "Missing generated/program output: ${_path}")
    endif()
    file(TIMESTAMP "${_path}" _stamp "%s")
    list(APPEND _stamps "${_stamp}")
  endforeach()
  set(${out} "${_stamps}" PARENT_SCOPE)
endfunction()
function(expect_rejected manifest reason)
  file(WRITE "${_src}/commands/mmakefile.src" "${manifest}")
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  string(REGEX REPLACE "[ \t\r\n]+" " " _diagnostic "${_out}${_err}")
  if(_result EQUAL 0 OR NOT _diagnostic MATCHES "${reason}")
    message(FATAL_ERROR "Expected rejection (${reason}), got ${_result}: ${_out}${_err}")
  endif()
endfunction()
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}" "-DAROS_TEST_SOURCE=${_repo}")
build()
file(READ "${_build}/build.ninja" _ninja)
if(NOT _ninja MATCHES "-DBISON=${_root}/selected-bison")
  message(FATAL_ERROR "Recipe did not use the late-bound BISON assignment")
endif()
stamps(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
build()
stamps(_after)
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "No-op build changed codegen/program outputs")
endif()
file(APPEND "${_src}/commands/parser.y" "/* grammar edit */\n")
build()
stamps(_after)
foreach(_index RANGE 0 4)
  list(GET _before ${_index} _old)
  list(GET _after ${_index} _new)
  if(_index EQUAL 2 OR _index EQUAL 4)
    if(NOT _old STREQUAL _new)
      message(FATAL_ERROR "Grammar edit rebuilt unrelated program")
    endif()
  elseif(_old STREQUAL _new)
    message(FATAL_ERROR "Grammar edit did not regenerate/rebuild consumer")
  endif()
endforeach()
file(REMOVE "${_obj}/parser.tab.c")
build()
stamps(_after)

# Group variables published by build_prog(s) retain their hyphenated names.
string(REPLACE "$(OBJDIR)/First.d :" "$(fixture-commands_DEPS) :" _group "${_manifest}")
file(WRITE "${_src}/commands/mmakefile.src" "${_group}")
build()
file(READ "${_build}/build.ninja" _ninja)
if(NOT _ninja MATCHES "obj/1[.]o: CUSTOM_COMMAND [^\n]*obj/parser[.]tab[.]c")
  message(FATAL_ERROR "Group compile dependency did not reach all objects")
endif()

string(REPLACE "\t@$(BISON) -o $@ $<" "\t@$(BISON) -d -o $@ $<" _bad "${_manifest}")
expect_rejected("${_bad}" "Unsupported program code-generation recipe")
string(REPLACE "\t@$(BISON) -o $@ $<" "" _bad "${_manifest}")
expect_rejected("${_bad}" "Expected one Bison command")
string(REPLACE "parser.tab.c : parser.y" "parser.tab.c : parser.y extra.y" _bad "${_manifest}")
expect_rejected("${_bad}" "requires one static grammar")
set(_bad "${_manifest}\n\$(OBJDIR)/First.d : alias-a\nalias-a : alias-b\nalias-b : alias-a\n")
expect_rejected("${_bad}" "Cyclic program compile prerequisites")
string(REPLACE "$(OBJDIR)/parser.tab.c : parser.y" "$(OBJDIR)/unused.tab.c : parser.y" _bad "${_manifest}")
expect_rejected("${_bad}" "owned static source")
expect_rejected("${_manifest}\n\$(OBJDIR)/parser.tab.c :\n" "Ambiguous or unsupported program code-generation rules")
expect_rejected("${_manifest}\nparser.y :\n\t\$(CP) seed.y parser.y\n" "cannot adopt a generated grammar")
file(WRITE "${_src}/commands/parser.y" "%defines\n${_grammar}")
expect_rejected("${_manifest}" "Unsupported Bison output/tool directive")
file(WRITE "${_src}/commands/parser.y" "${_grammar}")
file(WRITE "${_src}/config-snapshot/stale.y" "${_grammar}")
string(REPLACE "parser.tab.c : parser.y" "parser.tab.c : ${_src}/config-snapshot/stale.y" _bad "${_manifest}")
expect_rejected("${_bad}" "owned static source")
file(CREATE_LINK "${_root}" "${_src}/commands/escape" SYMBOLIC)
string(REPLACE "parser.tab.c : parser.y" "parser.tab.c : escape/stale.y" _bad "${_manifest}")
file(WRITE "${_root}/stale.y" "${_grammar}")
expect_rejected("${_bad}" "owned static source")
string(REPLACE "$(OBJDIR)/parser.tab.c" "${_src}/commands/parser.tab.c" _bad "${_manifest}")
expect_rejected("${_bad}" "outside the native build tree")
file(WRITE "${_src}/commands/extra.opts" "BISON := bison\n")
expect_rejected("${_manifest}\ninclude extra.opts\n" "needs included-manifest support")
file(CREATE_LINK "${_root}" "${_obj}/escape" SYMBOLIC)
string(REPLACE "$(OBJDIR)/parser.tab.c" "$(OBJDIR)/escape/parser.tab.c" _bad "${_manifest}")
expect_rejected("${_bad}" "outside the native build tree")

find_program(_true true REQUIRED)
file(WRITE "${_root}/stale-parser.c" "stale output\n")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DBISON=${_true}" "-DSOURCE_FILE=${_src}/commands/parser.y"
  "-DOUTPUT_FILE=${_root}/stale-parser.c" "-DBISON_DATA_DIR=${_root}"
  -P "${_repo}/cmake/build_mmake_bison.cmake" RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR EXISTS "${_root}/stale-parser.c" OR NOT _err MATCHES "Bison failed to generate")
  message(FATAL_ERROR "Successful tool exit without output must fail and remove stale output: ${_out}${_err}")
endif()

# A failed generator must not leave its old successful output available.
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
build()
file(WRITE "${_src}/commands/parser.y" "not a grammar\n")
expect_rejected("${_manifest}" "Bison failed to generate")
if(EXISTS "${_obj}/parser.tab.c")
  message(FATAL_ERROR "Failed generator retained a stale parser")
endif()
file(WRITE "${_src}/commands/parser.y" "${_grammar}")
build()
stamps(_before)
run("${CMAKE_COMMAND}" -E sleep 1)
build()
stamps(_after)
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "Final no-op build changed outputs")
endif()
# Explicit objdir must drive both named compile prerequisites and macro-owned
# OBJDIR/OBJS/DEPS variables without changing the manifest's global OBJDIR.
set(_custom [=[
CUSTOM := $(OBJDIR)/custom
USER_INCLUDES := -I$(CUSTOM) -I$(OBJDIR)
USER_CFLAGS := -O2
USER_LDFLAGS := -nostdlib -no-pie
%build_progs mmake=fixture-commands files="First Second" objdir=$(CUSTOM) targetdir=$(AROSDIR)/C usestartup=no
$(fixture-commands_OBJDIR)/First.d : $(fixture-commands_OBJDIR)/parser.tab.c
$(fixture-commands_OBJDIR)/parser.tab.c : parser.y
	@$(BISON) -o $@ $<
CUSTOM := $(OBJDIR)/wrong-later-directory
]=])
file(WRITE "${_src}/commands/mmakefile.src" "${_custom}")
file(REMOVE "${_obj}/parser.tab.c")
build()
set(_custom_obj "${_obj}/custom")
foreach(_path IN ITEMS parser.tab.c First.o First.d Second.o Second.d)
  if(NOT EXISTS "${_custom_obj}/${_path}")
    message(FATAL_ERROR "Explicit program objdir lost generated/compile output: ${_path}")
  endif()
endforeach()
if(EXISTS "${_obj}/wrong-later-directory")
  message(FATAL_ERROR "Later assignment changed the program's captured objdir")
endif()
file(TIMESTAMP "${_custom_obj}/First.o" _before "%s")
file(TIMESTAMP "${_custom_obj}/Second.o" _other_before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
file(APPEND "${_src}/commands/parser.y" "/* custom directory grammar edit */\n")
build()
file(TIMESTAMP "${_custom_obj}/First.o" _after "%s")
file(TIMESTAMP "${_custom_obj}/Second.o" _other_after "%s")
if(_before STREQUAL _after OR NOT _other_before STREQUAL _other_after)
  message(FATAL_ERROR "Named custom depfile did not isolate the generated-input rebuild")
endif()
file(REMOVE "${_custom_obj}/parser.tab.c" "${_custom_obj}/First.o")
build()
foreach(_group IN ITEMS OBJS DEPS)
  string(REPLACE "$(fixture-commands_OBJDIR)/First.d :" "$(fixture-commands_${_group}) :" _grouped "${_custom}")
  file(WRITE "${_src}/commands/mmakefile.src" "${_grouped}")
  build()
  file(READ "${_build}/build.ninja" _ninja)
  if(NOT _ninja MATCHES "custom/Second[.]o: CUSTOM_COMMAND [^\n]*custom/parser[.]tab[.]c")
    message(FATAL_ERROR "Custom ${_group} list did not reach every compiled object")
  endif()
endforeach()
# Global OBJDIR can still own generated data consumed from a custom object
# directory. The two namespaces must not be accidentally conflated.
string(REPLACE "$(fixture-commands_OBJDIR)/parser.tab.c" "$(OBJDIR)/parser.tab.c" _global "${_custom}")
file(WRITE "${_src}/commands/mmakefile.src" "${_global}")
file(REMOVE "${_custom_obj}/parser.tab.c")
build()
if(NOT EXISTS "${_obj}/parser.tab.c")
  message(FATAL_ERROR "Explicit objdir lost global generated-input ownership")
endif()
foreach(_suffix IN ITEMS o d)
  expect_rejected("${_custom}\n\$(fixture-commands_OBJDIR)/Second.${_suffix} : parser.y\n\t@\$(BISON) -o \$@ \$<\n"
    "Duplicate program producer")
endforeach()
file(WRITE "${_src}/commands/mmakefile.src" "${_custom}")
build()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do" OR _out MATCHES "Re-running CMake")
  message(FATAL_ERROR "Custom objdir no-op regenerated or rebuilt: ${_out}${_err}")
endif()
message(STATUS "Program code-generation and custom object-directory regression passed: ${_root}")
