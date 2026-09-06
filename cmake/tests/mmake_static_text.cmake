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
file(MAKE_DIRECTORY "${_src}/data" "${_src}/other" "${_config}/config")
configure_file("${CMAKE_CURRENT_LIST_DIR}/static-files/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
file(WRITE "${_config}/config/make.cfg" "TAG = configured\n")
file(WRITE "${_src}/other/mmakefile.src" "#MM unrelated :\nunrelated :\n\t@echo unsupported\n")
set(_rules [=[
NAME := marker
TEXT = $(CPU) $(SUFFIX) $(TAG)
#MM example : unrelated
#MM
example : $(AROSDIR)/$(NAME) setup
$(AROSDIR)/$(NAME) :
	@$(ECHO) Writing $@...
	@$(ECHO) "$(TEXT)" > $(AROSDIR)/$(NAME)
setup :
	%mkdirs_q $(AROSDIR)/Empty
SUFFIX = final
]=])
set(_manifest "${_src}/data/mmakefile.src")
file(WRITE "${_manifest}" "${_rules}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target static-files -j 6)
endfunction()
function(check output expected)
  file(READ "${_build}/runtime/${output}" _actual)
  if(NOT _actual STREQUAL expected)
    message(FATAL_ERROR "Wrong generated text in ${output}: '${_actual}', expected '${expected}'")
  endif()
endfunction()
function(noop)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target static-files
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  message("${_out}${_err}")
  if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do" OR _out MATCHES "Re-running CMake")
    message(FATAL_ERROR "Unchanged text graph rebuilt or reconfigured")
  endif()
endfunction()
set(_generator_args -G Ninja)
if(TEST_MAKE_PROGRAM)
  list(APPEND _generator_args "-DCMAKE_MAKE_PROGRAM=${TEST_MAKE_PROGRAM}")
endif()
run("${CMAKE_COMMAND}" ${_generator_args} -S "${_src}" -B "${_build}"
  "-DAROS_CMAKE_DIR=${_cmake_dir}" "-DAROS_LEGACY_BUILD_DIR=${_config}" -DAROS_STATIC_LOCAL=ON)
build()
check(marker "x86_64 final configured\n")
if(NOT IS_DIRECTORY "${_build}/runtime/Empty")
  message(FATAL_ERROR "Local setup prerequisite was lost")
endif()
noop()
file(REMOVE "${_build}/runtime/marker")
build()
check(marker "x86_64 final configured\n")
file(WRITE "${_config}/config/make.cfg" "TAG = edited\n")
build()
check(marker "x86_64 final edited\n")
string(REPLACE "SUFFIX = final" "SUFFIX = updated" _updated "${_rules}")
file(WRITE "${_manifest}" "${_updated}")
build()
check(marker "x86_64 updated edited\n")
noop()

# Discover new local producers without importing #MM-only aggregate edges.
file(MAKE_DIRECTORY "${_src}/incoming/new")
file(WRITE "${_src}/incoming/new/mmakefile.src" [=[
#MM
example : $(AROSDIR)/additional
$(AROSDIR)/additional :
	@$(ECHO) "another producer" > "$@"
]=])
build()
check(additional "another producer\n")
noop()
file(REMOVE_RECURSE "${_src}/incoming")
build()
noop()

function(expect_failure rules diagnostic)
  file(WRITE "${_manifest}" "${rules}")
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target static-files
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "${diagnostic}")
    message(FATAL_ERROR "Expected '${diagnostic}', got (${_result}): ${_out}${_err}")
  endif()
endfunction()
string(REPLACE " > " " >> " _bad "${_rules}")
expect_failure("${_bad}" "Unsupported static text ECHO")
string(REPLACE "$(TEXT)" "-n" _bad "${_rules}")
expect_failure("${_bad}" "Unsupported static text expression")
foreach(_text IN ITEMS "$(shell touch unwanted)" "`touch unwanted`" "back\\slash" "bad;command" "$<" "$$HOME")
  string(REPLACE "$(TEXT)" "${_text}" _bad "${_rules}")
  expect_failure("${_bad}" "Unsupported static text")
endforeach()
string(REPLACE " > $(AROSDIR)/$(NAME)" " > $(AROSDIR)/wrong" _bad "${_rules}")
expect_failure("${_bad}" "redirection does not match")
string(REPLACE "$(AROSDIR)/$(NAME) :" "$(AROSDIR)/$(NAME) : absent" _bad "${_rules}")
expect_failure("${_bad}" "Unsupported static text rule or prerequisites")
expect_failure("${_rules}\nexample : missing\n" "Unhandled static prerequisite")
expect_failure("${_rules}\nexample : unrelated\n" "Unhandled static prerequisite")
expect_failure("${_rules}\nexample : loop\nloop : example\n" "static local dependency cycle")
expect_failure("#MM\nexample : $(AROSDIR)/marker\n" "without a native producer")
expect_failure("${_rules}\ninclude $(SRCDIR)/extra.opts\n" "included rules/options")
expect_failure("${_rules}\nexample : broken\nbroken :\n\t@echo side-effect\n" "Unsupported static prerequisite recipe")
string(REPLACE "NAME := marker" "NAME := ../escape" _bad "${_rules}")
expect_failure("${_bad}" "outside the native runtime tree")
file(MAKE_DIRECTORY "${_root}/outside")
file(CREATE_LINK "${_root}/outside" "${_build}/runtime/escape" SYMBOLIC)
string(REPLACE "NAME := marker" "NAME := escape/file" _bad "${_rules}")
expect_failure("${_bad}" "escapes the native runtime tree")
# Existing files cannot satisfy a removed native producer.
expect_failure("#MM example : unrelated\n" "No native local static manifest producer")
file(WRITE "${_manifest}" "${_rules}")
build()

# Empty text is a newline; target conditions still determine the active rule.
set(_conditional [=[
#MM
example : $(AROSDIR)/marker
ifeq ($(CPU),x86_64)
$(AROSDIR)/marker :
	$(ECHO) "" > $@
else
$(AROSDIR)/marker :
	$(ECHO) "incorrect" > $@
endif
]=])
file(WRITE "${_manifest}" "${_conditional}")
build()
check(marker "\n")
noop()
file(WRITE "${_manifest}" "${_rules}")

# Global mode still checks all metadata dependencies rather than dropping them.
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_src}" -B "${_build}"
  -DAROS_STATIC_LOCAL=OFF -DAROS_STATIC_GRAPH=ON
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "Unsupported static prerequisite recipe")
  message(FATAL_ERROR "Global static target silently dropped unsupported metadata: ${_out}${_err}")
endif()
run("${CMAKE_COMMAND}" -S "${_src}" -B "${_build}" -DAROS_STATIC_LOCAL=ON)
file(WRITE "${_src}/other/mmakefile.src" [=[
#MM
example : $(AROSDIR)/marker
$(AROSDIR)/marker :
	@$(ECHO) "conflict" > $@
]=])
expect_failure("${_rules}" "Conflicting static-file producers")
file(REMOVE "${_src}/other/mmakefile.src")

# Test the real upstream recipe, changing only its selected entrypoint name.
file(READ "${_cmake_dir}/../boot/mmakefile.src" _boot)
string(REGEX REPLACE "(^|\n)boot :" "\\1example :" _boot "${_boot}")
file(WRITE "${_manifest}" "${_boot}")
build()
check(AROS.boot "x86_64\n")
noop()
message(STATUS "Static text and local-rule graph regression passed")
