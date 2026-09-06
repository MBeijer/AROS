cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass an isolated TEST_BINARY_DIR")
endif()
get_filename_component(_cmake_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
string(RANDOM LENGTH 12 ALPHABET 0123456789abcdef _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/source")
set(_build "${_root}/build")
file(MAKE_DIRECTORY "${_src}/data")
configure_file("${CMAKE_CURRENT_LIST_DIR}/static-files/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
file(WRITE "${_src}/data/one.txt" "base\n")
file(WRITE "${_src}/data/two.txt" "changed\n")
set(_rules [=[
#MM example : example-$(ARCH)-$(CPU) \
#MM     setup
example : $(AROSDIR)/S/Startup
$(AROSDIR)/S/Startup : one.txt
	@$(CP) $^ $@
#MM
setup :
	@$(IF) $(TEST) ! -d $(AROSDIR)/Empty ; then \
	    $(MKDIR) $(AROSDIR)/Empty ; \
	else $(NOP) ; fi
]=])
file(WRITE "${_src}/data/mmakefile" "${_rules}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result COMMAND_ECHO STDOUT)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target static-files -j 6)
endfunction()
function(compare input output)
  run("${CMAKE_COMMAND}" -E compare_files "${_src}/${input}" "${_build}/runtime/${output}")
endfunction()
function(noop)
  file(TIMESTAMP "${_build}/runtime/S/Startup" _before "%s")
  run("${CMAKE_COMMAND}" -E sleep 1)
  build()
  file(TIMESTAMP "${_build}/runtime/S/Startup" _after "%s")
  if(NOT _before STREQUAL _after)
    message(FATAL_ERROR "Unchanged static graph rebuilt")
  endif()
endfunction()
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}"
  "-DAROS_CMAKE_DIR=${_cmake_dir}" -DAROS_STATIC_GRAPH=ON)
build()
compare(data/one.txt S/Startup)
if(NOT IS_DIRECTORY "${_build}/runtime/Empty")
  message(FATAL_ERROR "Continued metadata setup prerequisite was lost")
endif()
noop()
file(APPEND "${_src}/data/one.txt" "source edit\n")
build()
compare(data/one.txt S/Startup)
string(REPLACE one.txt two.txt _updated "${_rules}")
file(WRITE "${_src}/data/mmakefile" "${_updated}")
build()
compare(data/two.txt S/Startup)
file(REMOVE "${_build}/runtime/S/Startup")
build()
compare(data/two.txt S/Startup)
# A newly supplied optional layer must become a dependency on an ordinary build.
file(MAKE_DIRECTORY "${_src}/incoming/port")
file(WRITE "${_src}/incoming/port/layer.txt" "layer\n")
set(_layer [=[
ifeq ($(ARCH),linux)
#MM example-$(ARCH)-$(CPU) :
example-$(ARCH)-$(CPU) : $(AROSDIR)/S/Layer
$(AROSDIR)/S/Layer : layer.txt
	$(CP) $^ $@
else
#MM example-linux-x86_64 :
example-linux-x86_64 : $(AROSDIR)/S/Invalid
$(AROSDIR)/S/Invalid : absent.txt
	$(CP) $^ $@
endif
]=])
file(WRITE "${_src}/incoming/port/mmakefile.src" "${_layer}")
build()
compare(incoming/port/layer.txt S/Layer)
noop()
file(APPEND "${_src}/incoming/port/layer.txt" "changed layer\n")
build()
compare(incoming/port/layer.txt S/Layer)
file(REMOVE_RECURSE "${_build}/runtime/S")
file(REMOVE_RECURSE "${_build}/runtime/Empty")
build()
if(NOT IS_DIRECTORY "${_build}/runtime/Empty")
  message(FATAL_ERROR "Missing setup-only directory was not recreated")
endif()
compare(data/two.txt S/Startup)
compare(incoming/port/layer.txt S/Layer)
noop()

function(expect_failure rules diagnostic)
  file(WRITE "${_src}/data/mmakefile" "${rules}")
  execute_process(COMMAND "${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "${diagnostic}")
    message(FATAL_ERROR "Expected '${diagnostic}', got (${_result}): ${_out}${_err}")
  endif()
endfunction()
string(REPLACE "one.txt" "one.txt two.txt" _bad "${_rules}")
expect_failure("${_bad}" "CP \\$\\^ copy needs exactly one source")
string(REPLACE " : one.txt" " : | one.txt" _bad "${_rules}")
expect_failure("${_bad}" "needs at least one normal source")
expect_failure("${_rules}\nexample : missing-input\n" "Unhandled static prerequisite")
string(REPLACE "else $(NOP)" "else echo unexpected" _bad "${_rules}")
expect_failure("${_bad}" "Unsupported static prerequisite recipe")
expect_failure("${_rules}\nexample :\n\t@echo unexpected\n" "Unsupported static prerequisite recipe")
expect_failure("${_rules}\none.txt : two.txt\n" "cannot adopt a generated prerequisite")
file(WRITE "${_root}/external.txt" "unowned\n")
string(REPLACE one.txt "${_root}/external.txt" _bad "${_rules}")
expect_failure("${_bad}" "requires an owned source")
file(CREATE_LINK "${_root}/external.txt" "${_src}/data/external-link.txt" SYMBOLIC)
string(REPLACE one.txt external-link.txt _bad "${_rules}")
expect_failure("${_bad}" "requires an owned source")
file(MAKE_DIRECTORY "${_src}/generated/CMakeFiles")
file(WRITE "${_src}/generated/stale.txt" "old build\n")
file(WRITE "${_src}/CMakeLists.txt" "set(AROS_LEGACY_BUILD_DIR \"${_src}/generated\")\n")
file(READ "${CMAKE_CURRENT_LIST_DIR}/static-files/CMakeLists.txt" _fixture)
file(APPEND "${_src}/CMakeLists.txt" "${_fixture}")
string(REPLACE one.txt ../generated/stale.txt _bad "${_rules}")
expect_failure("${_bad}" "requires an owned source")
# A present but unsupported layer is not an optional missing metadata target.
file(WRITE "${_src}/incoming/port/mmakefile.src"
  "#MM example-linux-x86_64 :\nexample-linux-x86_64 :\n\t@echo unsupported\n")
expect_failure("${_rules}" "Unsupported static prerequisite recipe")
file(WRITE "${_src}/incoming/port/mmakefile.src"
  "%build_prog mmake=example-linux-x86_64 progname=Unsupported\n")
expect_failure("${_rules}" "needs native support for %build_prog")
file(WRITE "${_src}/incoming/port/mmakefile.src"
  "%build_module mmake=example-linux modname=example modtype=library\n")
expect_failure("${_rules}" "needs native support for %build_module")
file(WRITE "${_src}/incoming/port/mmakefile.src" "${_layer}\n#MM example-linux-x86_64 : example\n")
expect_failure("${_rules}" "static metadata dependency cycle")
string(REPLACE /S/Layer /S/Startup _bad_layer "${_layer}")
file(WRITE "${_src}/incoming/port/mmakefile.src" "${_bad_layer}")
expect_failure("${_rules}" "Conflicting static-file producers")
# A local alias must not hide additional producers in a different manifest.
set(_local [=[
#MM example : local-alias
#MM- local-alias : extra
#MM extra
extra : $(AROSDIR)/S/Local
$(AROSDIR)/S/Local : two.txt
	$(CP) $^ $@
]=])
set(_extra [=[
#MM extra
extra : $(AROSDIR)/S/Extra
$(AROSDIR)/S/Extra : layer.txt
	$(CP) $^ $@
]=])
file(WRITE "${_src}/data/mmakefile" "${_rules}\n${_local}")
file(WRITE "${_src}/incoming/port/mmakefile.src" "${_layer}\n${_extra}")
build()
compare(data/two.txt S/Local)
compare(incoming/port/layer.txt S/Extra)
noop()
file(REMOVE "${_src}/incoming/port/mmakefile.src" "${_build}/runtime/S/Layer" "${_build}/runtime/S/Extra")
build()
if(EXISTS "${_build}/runtime/S/Layer" OR EXISTS "${_build}/runtime/S/Extra")
  message(FATAL_ERROR "Removed layer producer remained in the build graph")
endif()
compare(data/two.txt S/Local)
file(WRITE "${_src}/incoming/port/mmakefile.src" "${_layer}")
file(WRITE "${_src}/data/mmakefile" "${_rules}")
build()
compare(data/one.txt S/Startup)
noop()
message(STATUS "Plain-manifest static graph, optional layers, setup/copy rules and no-op checks passed: ${_root}")
