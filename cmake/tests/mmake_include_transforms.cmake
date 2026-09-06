cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
file(MAKE_DIRECTORY "${_src}/config" "${_src}/sdk" "${_src}/edges" "${_src}/generator"
  "${_src}/downloads" "${_src}/archives" "${_src}/commands" "${_root}/upstream/pkg"
  "${_src}/config-snapshot/bin/linux-x86_64/gen/config")
configure_file("${CMAKE_CURRENT_LIST_DIR}/programs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
configure_file("${_repo}/config/make.tmpl" "${_src}/config/make.tmpl" COPYONLY)
file(WRITE "${_src}/support.c" "int support(void) { return 0; }\n")
file(WRITE "${_src}/extra.h" "#define EXTRA 1\n")
file(WRITE "${_src}/config-snapshot/bin/linux-x86_64/gen/config/target.cfg" [=[
FAMILY := unix
GENINCDIR := $(GENDIR)/include
AROS_DIR_INCLUDE := include
CPPFLAGS = $(USER_CPPFLAGS)
CFLAGS = $(USER_CFLAGS)
LDFLAGS = $(USER_LDFLAGS)
NOSTARTUP_LDFLAGS := -nostartfiles
]=])
file(WRITE "${_src}/commands/Main.c" "#include <fixture/public.h>\n#include <fixture/generated.h>\n#include <fixture/local.h>\nint _start(void) { return VALUE + GENERATED + LOCAL; }\n")
file(WRITE "${_src}/commands/mmakefile.src" [=[
#MM fixture-commands: fixture-includes
%build_prog mmake=fixture-commands progname=Main usestartup=no ldflags="-nostdlib -no-pie" targetdir=$(AROSDIR)/C
]=])
set(_sdk [=[
#MM
fixture-includes: $(TARGETDIR)/sdk/include/fixture/local.h
%copy_includes mmake=fixture-includes includes=public.h dir=$(TARGETDIR)/Ports/pkg/pkg path=fixture
$(TARGETDIR)/sdk/include/fixture/local.h: local.in
	@$(SED) -e 's/@LOCAL@/3/' $< > $@
]=])
file(WRITE "${_src}/sdk/mmakefile.src" "${_sdk}")
file(WRITE "${_src}/sdk/local.in" "#define LOCAL @LOCAL@\n")
set(_edges [=[
include $(SRCDIR)/edges/options
#MM fixture-includes: generated-alias $(SOURCE_EDGE)
#MM generated-alias: fixture-generated
]=])
file(WRITE "${_src}/edges/mmakefile.src" "${_edges}")
file(WRITE "${_src}/edges/options" "SOURCE_EDGE := fetch-alias\n")
file(WRITE "${_src}/downloads/mmakefile.src" [=[
#MM fetch-alias: fixture-fetch
%fetch mmake=fixture-fetch archive=fixture suffixes=tar.gz location=$(SRCDIR)/archives destination=$(TARGETDIR)/Ports/pkg
]=])
set(_generator [=[
include $(SRCDIR)/generator/options
#MM
fixture-generated: header-local
header-local: $(TARGETDIR)/sdk/include/fixture/generated.h
$(TARGETDIR)/sdk/include/fixture/generated.h: $(TARGETDIR)/Ports/pkg/pkg/input.in
	@$(SED) -e 's/@VALUE@/$(GENERATED)/' $< > $@
]=])
file(WRITE "${_src}/generator/mmakefile.src" "${_generator}")
file(WRITE "${_src}/generator/options" "GENERATED := 7\n")
# An undecodable macro identity is an inventory candidate, not permission to
# read another architecture's generated recipe includes while resolving this SDK.
file(MAKE_DIRECTORY "${_src}/unrelated")
file(WRITE "${_src}/unrelated/mmakefile.src" [=[
-include $(GENDIR)/unavailable.inc
#MM unrelated-architecture: setup
%include_deps $(foreach f,$(FILES),$(OBJDIR)/$(f).d) $(END_FILE).d
]=])
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Include transform command failed: ${ARGN}\n${_out}${_err}")
  endif()
endfunction()
function(build)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs -j 4
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0 AND "${_out}${_err}" MATCHES "native sources prepared; run the build again")
    run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs -j 4)
  elseif(NOT _result EQUAL 0)
    message(FATAL_ERROR "Include transform build failed: ${_out}${_err}")
  endif()
endfunction()
function(noop)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do" OR _out MATCHES "Re-running CMake")
    message(FATAL_ERROR "Include transforms did not settle: ${_out}${_err}")
  endif()
endfunction()
function(rejected reason)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  string(REGEX REPLACE "[ \t\r\n]+" " " _message "${_out}${_err}")
  if(_result EQUAL 0 OR NOT _message MATCHES "${reason}")
    message(FATAL_ERROR "Expected ${reason}: ${_out}${_err}")
  endif()
endfunction()
function(archive suffix)
  file(WRITE "${_root}/upstream/pkg/public.h" "#define VALUE 2\n")
  file(WRITE "${_root}/upstream/pkg/input.in" "#define GENERATED @VALUE@${suffix}\n")
  run("${CMAKE_COMMAND}" -E chdir "${_root}/upstream" "${CMAKE_COMMAND}" -E tar czf
    "${_src}/archives/fixture.tar.gz" pkg)
endfunction()
archive("")
set(_include "${_build}/output/sdk/include/fixture")
set(_program "${_build}/output/AROS/C/Main")
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}" "-DAROS_TEST_SOURCE=${_repo}"
  "-DAROS_TEST_INCLUDE_DIR=${_build}/output/sdk/include")
build()
noop()
foreach(_change IN ITEMS option archive local missing)
  file(TIMESTAMP "${_program}" _before "%s")
  run("${CMAKE_COMMAND}" -E sleep 1)
  if(_change STREQUAL option)
    file(WRITE "${_src}/generator/options" "GENERATED := 9\n")
  elseif(_change STREQUAL archive)
    archive(" + 1")
  elseif(_change STREQUAL local)
    file(WRITE "${_src}/sdk/local.in" "#define LOCAL @LOCAL@ + 1\n")
  else()
    file(REMOVE "${_include}/generated.h" "${_include}/local.h")
  endif()
  build()
  file(TIMESTAMP "${_program}" _after "%s")
  if(_before STREQUAL _after)
    message(FATAL_ERROR "Generated header ${_change} did not rebuild the program")
  endif()
  noop()
endforeach()
file(READ "${_include}/generated.h" _header)
if(NOT _header STREQUAL "#define GENERATED 9 + 1\n")
  message(FATAL_ERROR "Wrong generated header: ${_header}")
endif()
# A metadata option edit removes ownership even if all fetched files still exist.
file(WRITE "${_src}/edges/options" "SOURCE_EDGE :=\n")
rejected("requires an owned (static )?source")
file(WRITE "${_src}/edges/options" "SOURCE_EDGE := fetch-alias\n")
build()
noop()
file(APPEND "${_src}/edges/mmakefile.src" "#MM generated-alias: fixture-includes\n")
rejected("dependency cycle")
file(WRITE "${_src}/edges/mmakefile.src" "${_edges}")
string(REPLACE "-e 's/@VALUE@/$(GENERATED)/'" "-e 's/@VALUE@/$(GENERATED)/e'" _bad "${_generator}")
file(WRITE "${_src}/generator/mmakefile.src" "${_bad}")
rejected("Unsupported text substitution")
file(WRITE "${_src}/generator/mmakefile.src" "${_generator}")
file(APPEND "${_src}/generator/options" "#MM fixture-generated: ignored\n")
rejected("Unsupported options include")
file(WRITE "${_src}/generator/options" "GENERATED := 9\n")
build()
noop()
file(APPEND "${_src}/unrelated/mmakefile.src" "#MM fixture-includes: setup\n")
rejected("Options include needs an owned source file")
file(REMOVE "${_src}/unrelated/mmakefile.src")
build()
noop()
# An inner include producer must not borrow its caller's sibling fetch.
file(MAKE_DIRECTORY "${_src}/inner")
file(WRITE "${_src}/inner/marker.h" "#define MARKER 1\n")
file(WRITE "${_src}/inner/mmakefile.src" [=[
#MM isolated-includes: fixture-generated
%copy_includes mmake=isolated-includes includes=marker.h path=inner
]=])
file(APPEND "${_src}/edges/mmakefile.src" "#MM fixture-includes: isolated-includes\n")
rejected("requires an owned (static )?source")
file(WRITE "${_src}/edges/mmakefile.src" "${_edges}")
file(REMOVE "${_src}/inner/mmakefile.src")
build()
noop()
# A newly imported manifest can augment the same generator identity.
file(MAKE_DIRECTORY "${_src}/incoming")
file(WRITE "${_src}/incoming/extra.in" "extra=old\n")
file(WRITE "${_src}/incoming/mmakefile.src" [=[
#MM fixture-generated: extra-generator
#MM
extra-generator: $(TARGETDIR)/sdk/extra.txt
$(TARGETDIR)/sdk/extra.txt: extra.in
	@$(SED) -e 's/old/new/' $< > $@
]=])
build()
file(READ "${_build}/output/sdk/extra.txt" _extra)
if(NOT _extra STREQUAL "extra=new\n")
  message(FATAL_ERROR "New manifest did not augment the generator")
endif()
noop()
file(REMOVE "${_src}/incoming/mmakefile.src")
build()
file(READ "${_build}/build.ninja" _graph)
if(_graph MATCHES "build output/sdk/extra[.]txt:")
  message(FATAL_ERROR "Removed transform producer remains in the graph")
endif()
noop()
message(STATUS "Include-owned transforms, sibling fetches, option edges, program rebuilds and no-op checks passed")
