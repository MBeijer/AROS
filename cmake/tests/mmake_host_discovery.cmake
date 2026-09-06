cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass an isolated TEST_BINARY_DIR")
endif()
get_filename_component(_cmake_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
string(RANDOM LENGTH 12 ALPHABET 0123456789abcdef _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/source")
set(_build "${_root}/build")
set(_config "${_root}/configuration")
file(MAKE_DIRECTORY "${_src}/launcher" "${_src}/loader" "${_src}/boot" "${_config}/config")
configure_file("${CMAKE_CURRENT_LIST_DIR}/host-discovery/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
file(WRITE "${_config}/config/make.cfg" "TAG := first\n")
file(MAKE_DIRECTORY "${_config}/bin/linux-x86_64/gen/config")
file(WRITE "${_config}/bin/linux-x86_64/gen/config/target.cfg" "FAMILY := unix\n")
file(WRITE "${_src}/launcher/main.c" "int loader(void); int main(void) { return loader(); }\n")
file(WRITE "${_src}/loader/loader.c" "int loader(void) { return 0; }\n")
file(WRITE "${_src}/launcher/mmakefile.src" [=[
#MM example-launcher : example-loader
%build_prog mmake=example-launcher progname=run files=main compiler=host uselibs=loader targetdir=$(AROSDIR)/Commands
]=])
set(_library [=[
ifeq ($(filter x86_%,$(AROS_TARGET_CPU)),x86_64)
%build_linklib mmake=example-loader libname=loader files=loader compiler=host libdir=$(GENDIR)/host
else
%build_linklib mmake=example-loader libname=wrong files=absent compiler=host libdir=$(GENDIR)/host
endif
%build_linklib mmake=unrelated-loader libname=loader files=absent compiler=host libdir=$(GENDIR)/other
]=])
file(WRITE "${_src}/loader/mmakefile.src" "${_library}")
set(_rules [=[
OUTPUT := $(AROSDIR)/Boot/settings
#MM example-boot : example-launcher
#MM
example-boot : $(OUTPUT)
$(OUTPUT): INPUT := $(SRCDIR)/$(CURDIR)/normal.conf
$(OUTPUT): normal.conf
ifeq ($(AROS_TARGET_CPU),other)
$(OUTPUT): INPUT := nonexistent
endif
$(OUTPUT): generate.sh | $(AROSDIR)/Boot
	@$(ECHO) "Writing $@..."
	@$(SRCDIR)/$(CURDIR)/generate.sh $(INPUT) $(TAG) >$@
$(AROSDIR)/Boot:
	@$(ECHO) "Making $@..."
	@mkdir -p $@
INPUT = wrong
]=])
set(_manifest "${_src}/boot/mmakefile.src")
file(WRITE "${_manifest}" "${_rules}")
file(WRITE "${_src}/boot/normal.conf" "configured\n")
set(_script "#!/bin/sh\ncat \"$1\"\nprintf '%s\\n' \"$2\"\n")
file(WRITE "${_src}/boot/generate.sh" "${_script}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target check -j 6)
endfunction()
function(check expected)
  foreach(_file IN ITEMS native/runtime/Boot/settings selected-config)
    file(READ "${_build}/${_file}" _actual)
    if(NOT _actual STREQUAL expected)
      message(FATAL_ERROR "Wrong configuration ${_file}: ${_actual}")
    endif()
  endforeach()
endfunction()
function(noop)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target check
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  message("${_out}${_err}")
  if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do" OR _out MATCHES "Re-running CMake")
    message(FATAL_ERROR "Unchanged host graph rebuilt or reconfigured")
  endif()
endfunction()
set(_generator_args -G Ninja)
if(TEST_MAKE_PROGRAM)
  list(APPEND _generator_args "-DCMAKE_MAKE_PROGRAM=${TEST_MAKE_PROGRAM}")
endif()
run("${CMAKE_COMMAND}" ${_generator_args} -S "${_src}" -B "${_build}"
  "-DAROS_CMAKE_DIR=${_cmake_dir}" "-DAROS_LEGACY_BUILD_DIR=${_config}")
build()
check("configured\nfirst\n")
run("${_build}/native/runtime/Commands/run")
noop()
file(REMOVE "${_build}/native/runtime/Boot/settings" "${_build}/native/gen/host/libloader.a")
build()
check("configured\nfirst\n")
file(WRITE "${_src}/boot/normal.conf" "edited\n")
file(WRITE "${_config}/config/make.cfg" "TAG := second\n")
build()
check("edited\nsecond\n")
file(WRITE "${_src}/boot/generate.sh" "${_script}printf 'script edit\\n'\n")
build()
check("edited\nsecond\nscript edit\n")
file(WRITE "${_src}/boot/generate.sh" "${_script}")
file(WRITE "${_src}/boot/alternate.conf" "alternate\n")
string(REPLACE "normal.conf" "alternate.conf" _updated "${_rules}")
file(WRITE "${_manifest}" "${_updated}")
build()
check("alternate\nsecond\n")
file(WRITE "${_manifest}" "${_rules}")
# Discovery must survive relocation to a new top-level directory and plain
# mmakefile fallback, without any OS-local CMakeLists files.
file(RENAME "${_src}/loader" "${_src}/incoming-loader")
file(RENAME "${_src}/incoming-loader/mmakefile.src" "${_src}/incoming-loader/mmakefile")
build()
noop()
file(WRITE "${_src}/incoming-loader/loader.c" "int loader(void) { return 7; }\n")
build()
execute_process(COMMAND "${_build}/native/runtime/Commands/run" RESULT_VARIABLE _exit)
if(NOT _exit EQUAL 7)
  message(FATAL_ERROR "Discovered archive source edit did not relink the launcher")
endif()
function(expect_failure diagnostic)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target check
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "${diagnostic}")
    message(FATAL_ERROR "Expected '${diagnostic}', got (${_result}): ${_out}${_err}")
  endif()
endfunction()
string(REPLACE " >$@" " >>$@" _bad "${_rules}")
file(WRITE "${_manifest}" "${_bad}")
expect_failure("Unsupported script-output")
file(WRITE "${_manifest}" "${_rules}\nexample-boot: TAG := inherited\n")
expect_failure("Unsupported inherited script-output target variables")
file(WRITE "${_manifest}" "${_rules}\n$(AROSDIR)/Boot/settings: TAG += appended\n")
expect_failure("owned static source")
file(WRITE "${_manifest}" "${_rules}\nexample-boot: missing\n")
expect_failure("owned static source")
file(WRITE "${_manifest}" "${_rules}\nexample-boot: loop\nloop: example-boot\n")
expect_failure("dependency cycle")
file(WRITE "${_manifest}" "${_rules}")
file(WRITE "${_src}/incoming-loader/mmakefile" "${_library}\n%build_linklib mmake=example-loader libname=loader files=loader compiler=host libdir=$(GENDIR)/duplicate\n")
expect_failure("Expected one native manifest entrypoint")
file(WRITE "${_src}/incoming-loader/mmakefile" "${_library}")
file(WRITE "${_manifest}" "#MM example-boot : example-launcher\n")
expect_failure("Expected one local script-output producer")
file(WRITE "${_manifest}" "${_rules}")
build()
noop()
# A failed generator must not leave a partial or stale success artifact.
file(WRITE "${_root}/fail.sh" "#!/bin/sh\necho partial\nexit 1\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -DPROGRAM=/bin/sh
  "-DCOMMAND_ARGS=${_root}/fail.sh" "-DOUTPUT_FILE=${_build}/native/runtime/Boot/settings"
  -P "${_cmake_dir}/emit_tool_stdout_to_file.cmake" RESULT_VARIABLE _result
  OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR EXISTS "${_build}/native/runtime/Boot/settings"
   OR EXISTS "${_build}/native/runtime/Boot/settings.tmp")
  message(FATAL_ERROR "Failed generator retained an invalid output")
endif()
build()
noop()
message(STATUS "Host producer discovery and script-output graph checks passed")
