cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
file(MAKE_DIRECTORY "${_src}/messages" "${_src}/config" "${_src}/sd")
configure_file("${CMAKE_CURRENT_LIST_DIR}/catalogs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
configure_file("${_repo}/config/make.tmpl" "${_src}/config/make.tmpl" COPYONLY)
file(WRITE "${_src}/sd/C_h_aros.sd" "header template\n")
file(WRITE "${_src}/messages/example.cd" "description\n")
file(WRITE "${_src}/messages/german.ct" "translation\n")
file(WRITE "${_src}/messages/russian.ct" "translation\n")
file(WRITE "${_src}/flexcat.c" [=[
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    const char *output = NULL, *sd = NULL;
    int catalog = 0, result = 0, missing = 0;
    char path[4096];
    for (int i = 1; i < argc; ++i) {
        const char *eq = strchr(argv[i], '=');
        if (!eq) continue;
        if (!strncmp(argv[i], "CATALOG=", 8)) { output = eq + 1; catalog = 1; }
        else {
            snprintf(path, sizeof(path), "%.*s", (int)(eq - argv[i]), argv[i]);
            output = path; sd = eq + 1;
        }
    }
    if (!output) return 20;
    FILE *out = fopen(output, "w");
    if (!out) return 20;
    for (int i = 1; i < argc; ++i) {
        if (strchr(argv[i], '=')) continue;
        if (!strcmp(argv[i], "win1251toamiga1251")) { fputs("converted\n", out); continue; }
        FILE *in = fopen(argv[i], "r");
        if (!in) return 20;
        char line[4096];
        while (fgets(line, sizeof(line), in)) {
            if (strstr(line, "WARNING")) result = 5;
            if (strstr(line, "ERROR")) result = 10;
            if (strstr(line, "MISSING")) missing = 1;
            fputs(line, out);
        }
        fclose(in);
    }
    if (!catalog) {
        FILE *in = fopen(sd, "r"); int ch;
        if (!in) return 20;
        while ((ch = fgetc(in)) != EOF) fputc(ch, out);
        fclose(in);
    }
    fclose(out);
    if (missing) remove(output);
    return result;
}
]=])
set(_rule [=[
LANGUAGES := german russian
ifeq ($(ARCH),linux)
%build_catalogs mmake=fixture-catalogs name=example subdir=System/Libs \
    catalogs=$(LANGUAGES)
else
%build_catalogs mmake=fixture-catalogs name=wrong subdir=Wrong description=absent
endif
]=])
file(WRITE "${_src}/messages/mmakefile.src" "${_rule}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target catalogs -j 3)
endfunction()
function(check file expected)
  file(READ "${file}" _actual)
  if(NOT _actual STREQUAL expected)
    message(FATAL_ERROR "Unexpected catalog content in ${file}: ${_actual}")
  endif()
endfunction()
function(noop)
  file(TIMESTAMP "${_german}" _before "%s")
  run("${CMAKE_COMMAND}" -E sleep 1)
  build()
  file(TIMESTAMP "${_german}" _after "%s")
  if(NOT _before STREQUAL _after)
    message(FATAL_ERROR "No-op build regenerated catalogs")
  endif()
endfunction()
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}" "-DAROS_TEST_SOURCE=${_repo}")
set(_catalogs "${_build}/output/AROS/Locale/Catalogs")
set(_german "${_catalogs}/german/System/Libs/example.catalog")
set(_russian "${_catalogs}/russian/System/Libs/example.catalog")
set(_header "${_build}/strings.h")
build()
check("${_german}" "description\ntranslation\n")
check("${_russian}" "converted\ndescription\ntranslation\n")
check("${_header}" "description\nheader template\n")
noop()
file(WRITE "${_src}/messages/german.ct" "WARNING\n")
build()
check("${_german}" "description\nWARNING\n")
file(WRITE "${_src}/messages/example.cd" "new description\n")
build()
check("${_russian}" "converted\nnew description\ntranslation\n")
check("${_header}" "new description\nheader template\n")
file(WRITE "${_src}/sd/C_h_aros.sd" "new template\n")
build()
check("${_header}" "new description\nnew template\n")
file(REMOVE "${_german}" "${_header}")
build()
check("${_german}" "new description\nWARNING\n")
check("${_header}" "new description\nnew template\n")
# Empty catalogs uses a configure-aware inventory. New languages need no edit.
string(REPLACE "catalogs=$(LANGUAGES)" "catalogs=" _glob_rule "${_rule}")
file(WRITE "${_src}/messages/mmakefile.src" "${_glob_rule}")
build()
file(WRITE "${_src}/messages/french.ct" "french\n")
file(WRITE "${_src}/messages/pt.br.ct" "portuguese\n")
build()
check("${_catalogs}/french/System/Libs/example.catalog" "new description\nfrench\n")
check("${_catalogs}/pt.br/System/Libs/example.catalog" "new description\nportuguese\n")
file(REMOVE "${_src}/messages/french.ct" "${_catalogs}/french/System/Libs/example.catalog")
build()
if(EXISTS "${_catalogs}/french/System/Libs/example.catalog")
  message(FATAL_ERROR "Removed translation retained a producer")
endif()
noop()
# Template defaults are inputs too, not a copied header output inventory.
file(READ "${_src}/config/make.tmpl" _template)
string(REPLACE "source=\"../strings.h\"" "source=\"../changed.h\"" _changed "${_template}")
file(WRITE "${_src}/config/make.tmpl" "${_changed}")
build()
check("${_build}/changed.h" "new description\nnew template\n")

function(reject rules diagnostic)
  file(WRITE "${_src}/messages/mmakefile.src" "${rules}\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_build}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  string(REGEX REPLACE "[ \t\r\n]+" " " _diagnostic "${_out}${_err}")
  if(_result EQUAL 0 OR NOT _diagnostic MATCHES "${diagnostic}")
    message(FATAL_ERROR "Expected ${diagnostic}, got (${_result}): ${_out}${_err}")
  endif()
endfunction()
set(_simple "%build_catalogs mmake=fixture-catalogs name=example subdir=System/Libs catalogs=german")
reject("${_simple} unknown=yes" "Unsupported catalog argument")
reject("${_simple} source=${_root}/outside.h" "outside the native build tree")
reject("${_simple} dir=${_root}/outside" "outside the native runtime tree")
file(MAKE_DIRECTORY "${_root}/outside-output")
file(CREATE_LINK "${_root}/outside-output" "${_build}/escape" SYMBOLIC)
reject("${_simple} source=${_build}/escape/generated.h" "outside the native build tree")
reject("${_simple} description=missing" "owned static source")
reject("${_simple}\n${_simple}" "one active catalog rule")
reject("${_simple}\n#MM fixture-catalogs : missing-generator" "Unhandled catalog prerequisites")
reject("${_simple}\nfixture-catalogs :\n\t@echo unsupported" "unsupported recipe")
reject("${_simple}\n$(SRCDIR)/$(CURDIR)/%.ct :\n\t@echo generate" "unsupported producer")
file(WRITE "${_root}/outside.cd" "external\n")
file(CREATE_LINK "${_root}/outside.cd" "${_src}/messages/external.cd" SYMBOLIC)
reject("${_simple} description=$(SRCDIR)/$(CURDIR)/external" "owned static source")
file(REMOVE "${_src}/messages/external.cd")
file(MAKE_DIRECTORY "${_src}/legacy")
file(WRITE "${_src}/legacy/stale.cd" "stale\n")
reject("${_simple} description=$(SRCDIR)/legacy/stale" "owned static source")
file(WRITE "${_src}/messages/extra.cd" "ambiguous\n")
reject("${_simple}" "exactly one description file")
file(REMOVE "${_src}/messages/extra.cd")
# Two metadata identities cannot own the same output, even in one manifest.
file(WRITE "${_src}/messages/mmakefile.src" "${_simple}\n%build_catalogs mmake=second-catalogs name=example subdir=System/Libs catalogs=german\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_build}" -DTEST_SECOND_PRODUCER=ON
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Duplicate catalog producer")
  message(FATAL_ERROR "Conflicting catalogs were not rejected: ${_out}${_err}")
endif()
file(WRITE "${_src}/messages/mmakefile.src" "${_simple} source=\"\"\n")
run("${CMAKE_COMMAND}" -S "${_src}" -B "${_build}" -DTEST_SECOND_PRODUCER=OFF)
foreach(_failure IN ITEMS ERROR MISSING)
  file(WRITE "${_src}/messages/german.ct" "${_failure}\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target catalogs
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR EXISTS "${_german}" OR EXISTS "${_german}.tmp"
     OR NOT "${_out}${_err}" MATCHES "Catalog generation failed")
    message(FATAL_ERROR "Failed generator left a usable stale output: ${_out}${_err}")
  endif()
endforeach()
file(WRITE "${_src}/messages/german.ct" "restored\n")
build()
check("${_german}" "new description\nrestored\n")
noop()
# A program dependency builds catalogs, but catalog-only edits do not relink.
file(MAKE_DIRECTORY "${_src}/commands" "${_src}/legacy/bin/linux-x86_64/gen/config")
file(WRITE "${_src}/legacy/bin/linux-x86_64/gen/config/target.cfg" "NOSTARTUP_LDFLAGS := -nostartfiles\n")
file(WRITE "${_src}/commands/Consumer.c" "void _start(void) {}\n")
file(WRITE "${_src}/commands/mmakefile.src" [=[
#MM fixture-program : fixture-catalogs
%build_prog mmake=fixture-program progname=Consumer targetdir=$(AROSDIR)/C \
    usestartup=no ldflags="-nostdlib -no-pie"
]=])
run("${CMAKE_COMMAND}" -S "${_src}" -B "${_build}" -DTEST_PROGRAM=ON)
file(REMOVE "${_german}")
run("${CMAKE_COMMAND}" --build "${_build}" --target consumer -j 3)
check("${_german}" "new description\nrestored\n")
set(_program "${_build}/output/AROS/C/Consumer")
file(TIMESTAMP "${_program}" _before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
file(WRITE "${_src}/messages/german.ct" "program dependency\n")
run("${CMAKE_COMMAND}" --build "${_build}" --target consumer -j 3)
check("${_german}" "new description\nprogram dependency\n")
file(TIMESTAMP "${_program}" _after "%s")
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "Catalog-only change relinked its program consumer")
endif()
file(REMOVE "${_src}/messages/mmakefile.src")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target consumer
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Missing fixture-catalogs producer")
  message(FATAL_ERROR "Removed manifest was satisfied by stale catalogs: ${_out}${_err}")
endif()
file(MAKE_DIRECTORY "${_src}/incoming/catalogs")
file(WRITE "${_src}/incoming/catalogs/mmakefile.src"
  "${_simple} source=\"\" srcdir=$(SRCDIR)/messages\n")
run("${CMAKE_COMMAND}" --build "${_build}" --target consumer -j 3)
check("${_german}" "new description\nprogram dependency\n")
noop()
message(STATUS "Native catalog generation, discovery, rebuild and failure checks passed: ${_root}")
