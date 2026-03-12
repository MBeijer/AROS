include_guard(GLOBAL)
include("${CMAKE_SOURCE_DIR}/cmake/AROSLayering.cmake")

function(_aros_encode_list in_list out_var)
  if(in_list)
    string(REPLACE ";" "|" _encoded "${in_list}")
    set(${out_var} "${_encoded}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

function(_aros_sanitize_property_key input_value out_var)
  string(REGEX REPLACE "[^A-Za-z0-9_]" "_" _sanitized "${input_value}")
  set(${out_var} "${_sanitized}" PARENT_SCOPE)
endfunction()

function(_aros_unwrap_strip_expression input_value out_var)
  set(_value "${input_value}")
  if(_value MATCHES "^\\$\\(strip[ \t]*(.*)\\)$")
    set(_value "${CMAKE_MATCH_1}")
  endif()
  string(STRIP "${_value}" _value)
  set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

function(_aros_get_target_context out_arch out_cpu out_variant out_family)
  string(REPLACE "-" ";" _parts "${AROS_TARGET}")
  list(GET _parts 0 _arch)
  list(GET _parts 1 _cpu)

  set(_variant "")
  list(LENGTH _parts _parts_len)
  if(_parts_len GREATER 2)
    list(SUBLIST _parts 2 -1 _variant_parts)
    string(REPLACE ";" "-" _variant "${_variant_parts}")
  endif()

  set(_target_cfg "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg")
  file(STRINGS "${_target_cfg}" _family_line REGEX "^FAMILY[ \t]*:=")
  if(_family_line)
    string(REGEX REPLACE "^FAMILY[ \t]*:=[ \t]*" "" _family "${_family_line}")
    string(STRIP "${_family}" _family)
  else()
    set(_family "${_arch}")
  endif()

  set(${out_arch} "${_arch}" PARENT_SCOPE)
  set(${out_cpu} "${_cpu}" PARENT_SCOPE)
  set(${out_variant} "${_variant}" PARENT_SCOPE)
  set(${out_family} "${_family}" PARENT_SCOPE)
endfunction()

function(_aros_get_active_alias_layers out_var)
  _aros_get_target_context(_arch _cpu _variant _family)

  set(_aliases)
  if(_variant)
    list(APPEND _aliases "${_arch}-${_cpu}-${_variant}")
  endif()
  list(APPEND _aliases "${_arch}-${_cpu}")
  if(_variant)
    list(APPEND _aliases "${_arch}-${_variant}")
  endif()
  list(APPEND _aliases
    "${_arch}"
    "${_family}"
    "${_cpu}"
  )
  list(REMOVE_DUPLICATES _aliases)
  set(${out_var} "${_aliases}" PARENT_SCOPE)
endfunction()

function(_aros_extract_make_call input_value call_name out_prefix out_body out_suffix)
  string(FIND "${input_value}" "$(${call_name} " _call_start)
  if(_call_start EQUAL -1)
    set(${out_prefix} "${input_value}" PARENT_SCOPE)
    set(${out_body} "" PARENT_SCOPE)
    set(${out_suffix} "" PARENT_SCOPE)
    return()
  endif()

  string(LENGTH "${input_value}" _input_len)
  set(_depth 0)
  set(_call_end -1)
  set(_index "${_call_start}")
  while(_index LESS _input_len)
    math(EXPR _remaining "${_input_len} - ${_index}")
    if(_remaining GREATER 1)
      string(SUBSTRING "${input_value}" ${_index} 2 _pair)
    else()
      set(_pair "")
    endif()

    if(_pair STREQUAL "$(")
      math(EXPR _depth "${_depth} + 1")
      math(EXPR _index "${_index} + 2")
      continue()
    endif()

    string(SUBSTRING "${input_value}" ${_index} 1 _char)
    if(_char STREQUAL ")" AND _depth GREATER 0)
      math(EXPR _depth "${_depth} - 1")
      if(_depth EQUAL 0)
        set(_call_end "${_index}")
        break()
      endif()
    endif()

    math(EXPR _index "${_index} + 1")
  endwhile()

  if(_call_end EQUAL -1)
    message(FATAL_ERROR "Unterminated \$(${call_name} ...) expression: ${input_value}")
  endif()

  if(_call_start GREATER 0)
    string(SUBSTRING "${input_value}" 0 ${_call_start} _prefix)
  else()
    set(_prefix "")
  endif()

  math(EXPR _body_start "${_call_start} + 2")
  math(EXPR _body_len "${_call_end} - ${_body_start}")
  string(SUBSTRING "${input_value}" ${_body_start} ${_body_len} _body)

  math(EXPR _suffix_start "${_call_end} + 1")
  if(_suffix_start LESS _input_len)
    math(EXPR _suffix_len "${_input_len} - ${_suffix_start}")
    string(SUBSTRING "${input_value}" ${_suffix_start} ${_suffix_len} _suffix)
  else()
    set(_suffix "")
  endif()

  set(${out_prefix} "${_prefix}" PARENT_SCOPE)
  set(${out_body} "${_body}" PARENT_SCOPE)
  set(${out_suffix} "${_suffix}" PARENT_SCOPE)
endfunction()

function(_aros_split_make_arguments input_value out_var)
  set(_arguments)
  set(_current "")
  set(_depth 0)
  string(LENGTH "${input_value}" _input_len)
  set(_index 0)

  while(_index LESS _input_len)
    math(EXPR _remaining "${_input_len} - ${_index}")
    if(_remaining GREATER 1)
      string(SUBSTRING "${input_value}" ${_index} 2 _pair)
    else()
      set(_pair "")
    endif()

    if(_pair STREQUAL "$(")
      math(EXPR _depth "${_depth} + 1")
      string(APPEND _current "$(")
      math(EXPR _index "${_index} + 2")
      continue()
    endif()

    string(SUBSTRING "${input_value}" ${_index} 1 _char)
    if(_char STREQUAL ")" AND _depth GREATER 0)
      math(EXPR _depth "${_depth} - 1")
      string(APPEND _current "${_char}")
    elseif(_char STREQUAL "," AND _depth EQUAL 0)
      string(STRIP "${_current}" _current)
      list(APPEND _arguments "${_current}")
      set(_current "")
    else()
      string(APPEND _current "${_char}")
    endif()

    math(EXPR _index "${_index} + 1")
  endwhile()

  string(STRIP "${_current}" _current)
  list(APPEND _arguments "${_current}")
  set(${out_var} "${_arguments}" PARENT_SCOPE)
endfunction()

function(_aros_expand_make_tokens input_value out_var)
  _aros_get_target_context(_arch _cpu _variant _family)
  set(_expanded "${input_value}")
  set(_make_gendir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen")
  set(_limit 100)
  while(_limit GREATER 0)
    math(EXPR _limit "${_limit} - 1")
    _aros_extract_make_call("${_expanded}" "foreach" _foreach_prefix _foreach_body _foreach_suffix)
    if(NOT _foreach_body STREQUAL "")
      string(REGEX REPLACE "^foreach[ \t]+" "" _foreach_arg_string "${_foreach_body}")
      _aros_split_make_arguments("${_foreach_arg_string}" _foreach_args)
      list(LENGTH _foreach_args _foreach_arg_count)
      if(NOT _foreach_arg_count EQUAL 3)
        message(FATAL_ERROR "Unsupported foreach expression while parsing CMake metadata: ${_foreach_body}")
      endif()

      list(GET _foreach_args 0 _foreach_var)
      list(GET _foreach_args 1 _foreach_list_expr)
      list(GET _foreach_args 2 _foreach_text_expr)
      string(STRIP "${_foreach_var}" _foreach_var)

      _aros_expand_make_tokens("${_foreach_list_expr}" _foreach_list_expanded)
      separate_arguments(_foreach_values NATIVE_COMMAND "${_foreach_list_expanded}")

      set(_foreach_saved_defined FALSE)
      if(DEFINED _AROS_MMAKE_VAR_${_foreach_var})
        set(_foreach_saved_defined TRUE)
        set(_foreach_saved_value "${_AROS_MMAKE_VAR_${_foreach_var}}")
      endif()

      set(_foreach_result "")
      foreach(_foreach_value IN LISTS _foreach_values)
        set(_AROS_MMAKE_VAR_${_foreach_var} "${_foreach_value}")
        _aros_expand_make_tokens("${_foreach_text_expr}" _foreach_item)
        string(STRIP "${_foreach_item}" _foreach_item)
        if(_foreach_item STREQUAL "")
          continue()
        endif()
        if(_foreach_result STREQUAL "")
          set(_foreach_result "${_foreach_item}")
        else()
          string(APPEND _foreach_result " " "${_foreach_item}")
        endif()
      endforeach()

      if(_foreach_saved_defined)
        set(_AROS_MMAKE_VAR_${_foreach_var} "${_foreach_saved_value}")
      else()
        unset(_AROS_MMAKE_VAR_${_foreach_var})
      endif()

      set(_expanded "${_foreach_prefix}${_foreach_result}${_foreach_suffix}")
      continue()
    endif()

    string(REGEX MATCH "\\$\\(([A-Za-z0-9_]+)\\)" _match "${_expanded}")
    if(NOT _match)
      break()
    endif()

    set(_var_name "${CMAKE_MATCH_1}")
    if(DEFINED _AROS_MMAKE_VAR_${_var_name})
      set(_replacement "${_AROS_MMAKE_VAR_${_var_name}}")
    elseif(_var_name STREQUAL "ARCH")
      set(_replacement "${_arch}")
    elseif(_var_name STREQUAL "CPU")
      set(_replacement "${_cpu}")
    elseif(_var_name STREQUAL "FAMILY")
      set(_replacement "${_family}")
    elseif(_var_name STREQUAL "AROS_TARGET_ARCH")
      set(_replacement "${_arch}")
    elseif(_var_name STREQUAL "AROS_TARGET_CPU")
      set(_replacement "${_cpu}")
    elseif(_var_name STREQUAL "AROS_TARGET_FAMILY")
      set(_replacement "${_family}")
    elseif(_var_name STREQUAL "AROS_TARGET_PLATFORM")
      set(_replacement "${AROS_TARGET}")
    elseif(_var_name STREQUAL "AROS_TARGET_VARIANT")
      set(_replacement "${_variant}")
    elseif(_var_name STREQUAL "TARGET_CPU")
      set(_replacement "${_cpu}")
    elseif(_var_name STREQUAL "SRCDIR")
      set(_replacement "${CMAKE_SOURCE_DIR}")
    elseif(_var_name STREQUAL "CURDIR")
      set(_replacement "")
    elseif(_var_name STREQUAL "GENDIR")
      set(_replacement "${_make_gendir}")
    else()
      _aros_read_config_value("${_var_name}" _replacement)
    endif()
    string(REPLACE "$(${_var_name})" "${_replacement}" _expanded "${_expanded}")
  endwhile()
  set(${out_var} "${_expanded}" PARENT_SCOPE)
endfunction()

function(_aros_read_config_value variable_name out_var)
  set(_config_files
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
    "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
  )

  foreach(_config_file IN LISTS _config_files)
    if(NOT EXISTS "${_config_file}")
      continue()
    endif()

    file(STRINGS "${_config_file}" _value_line REGEX "^${variable_name}[ \t]*:?=")
    if(_value_line)
      string(REGEX REPLACE "^${variable_name}[ \t]*:?=[ \t]*" "" _value "${_value_line}")
      _aros_unwrap_strip_expression("${_value}" _value)
      set(${out_var} "${_value}" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  set(${out_var} "" PARENT_SCOPE)
endfunction()

function(_aros_read_config_tokens variable_name out_var)
  _aros_read_config_value("${variable_name}" _value)
  if(_value STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  _aros_expand_make_tokens("${_value}" _value)
  separate_arguments(_tokens NATIVE_COMMAND "${_value}")
  set(${out_var} "${_tokens}" PARENT_SCOPE)
endfunction()

function(_aros_remove_empty_entries var_name)
  if(NOT DEFINED ${var_name} OR "${${var_name}}" STREQUAL "")
    set(${var_name} "" PARENT_SCOPE)
    return()
  endif()

  set(_filtered_values)
  foreach(_value IN LISTS ${var_name})
    string(STRIP "${_value}" _stripped_value)
    if(NOT _stripped_value STREQUAL "")
      list(APPEND _filtered_values "${_stripped_value}")
    endif()
  endforeach()
  set(${var_name} "${_filtered_values}" PARENT_SCOPE)
endfunction()

function(_aros_remove_token_entries var_name)
  if(NOT DEFINED ${var_name} OR "${${var_name}}" STREQUAL "")
    set(${var_name} "" PARENT_SCOPE)
    return()
  endif()

  set(_filtered_values)
  foreach(_value IN LISTS ${var_name})
    string(STRIP "${_value}" _stripped_value)
    set(_keep_value TRUE)
    foreach(_remove_token IN LISTS ARGN)
      if(_stripped_value STREQUAL "${_remove_token}")
        set(_keep_value FALSE)
        break()
      endif()
    endforeach()
    if(_keep_value)
      list(APPEND _filtered_values "${_stripped_value}")
    endif()
  endforeach()
  set(${var_name} "${_filtered_values}" PARENT_SCOPE)
endfunction()

function(_aros_collect_link_library_names out_var)
  set(_library_names)
  foreach(_token IN LISTS ARGN)
    if(_token MATCHES "^-l(.+)$")
      list(APPEND _library_names "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _library_names)
  set(${out_var} "${_library_names}" PARENT_SCOPE)
endfunction()

function(_aros_get_genmodule_public_linklib_output module_name module_type module_suffix out_var)
  if(module_type STREQUAL "library")
    set(_module_linklib_suffix "")
  else()
    set(_module_linklib_suffix ".${module_type}")
  endif()

  set(${out_var} "${AROS_NATIVE_PUBLIC_LIB_DIR}/lib${module_name}${_module_linklib_suffix}.a" PARENT_SCOPE)
endfunction()

function(_aros_get_genmodule_rel_linklib_output module_name module_type module_suffix out_var)
  if(module_type STREQUAL "library")
    set(_module_linklib_suffix "")
  else()
    set(_module_linklib_suffix ".${module_type}")
  endif()

  set(${out_var} "${AROS_NATIVE_REL_LIB_DIR}/lib${module_name}_rel${_module_linklib_suffix}.a" PARENT_SCOPE)
endfunction()

function(_aros_collect_registered_archive_dependencies out_files_var out_targets_var)
  set(_dependency_files)
  set(_dependency_targets)

  foreach(_lib_name IN LISTS ARGN)
    _aros_sanitize_property_key("${_lib_name}" _aros_lib_key)

    get_property(
      _registered_output
      GLOBAL
      PROPERTY "AROS_REGISTERED_LINKLIB_OUTPUT_${_aros_lib_key}"
    )
    get_property(
      _registered_target
      GLOBAL
      PROPERTY "AROS_REGISTERED_LINKLIB_TARGET_${_aros_lib_key}"
    )

    if(NOT _registered_output)
      get_property(
        _registered_output
        GLOBAL
        PROPERTY "AROS_REGISTERED_GENMODULE_REL_LINKLIB_OUTPUT_${_aros_lib_key}"
      )
      get_property(
        _registered_target
        GLOBAL
        PROPERTY "AROS_REGISTERED_GENMODULE_REL_LINKLIB_TARGET_${_aros_lib_key}"
      )
    endif()

    if(NOT _registered_output)
      get_property(
        _registered_output
        GLOBAL
        PROPERTY "AROS_REGISTERED_GENMODULE_PUBLIC_LINKLIB_OUTPUT_${_aros_lib_key}"
      )
      get_property(
        _registered_target
        GLOBAL
        PROPERTY "AROS_REGISTERED_GENMODULE_PUBLIC_LINKLIB_TARGET_${_aros_lib_key}"
      )
    endif()

    if(_registered_output)
      list(APPEND _dependency_files "${_registered_output}")
    endif()
    if(_registered_target)
      list(APPEND _dependency_targets "${_registered_target}")
    endif()
  endforeach()

  list(REMOVE_DUPLICATES _dependency_files)
  list(REMOVE_DUPLICATES _dependency_targets)
  set(${out_files_var} "${_dependency_files}" PARENT_SCOPE)
  set(${out_targets_var} "${_dependency_targets}" PARENT_SCOPE)
endfunction()

function(_aros_extract_conf_rellibs conf_path out_var)
  if(NOT EXISTS "${conf_path}")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  file(STRINGS "${conf_path}" _conf_rellib_lines REGEX "^[ \t]*rellib[ \t]+")
  set(_rellibs)
  foreach(_conf_rellib_line IN LISTS _conf_rellib_lines)
    string(REGEX REPLACE "^[ \t]*rellib[ \t]+([^ \t#]+).*$" "\\1" _rellib_name "${_conf_rellib_line}")
    if(NOT _rellib_name STREQUAL "")
      list(APPEND _rellibs "${_rellib_name}_rel")
    endif()
  endforeach()

  list(REMOVE_DUPLICATES _rellibs)
  set(${out_var} "${_rellibs}" PARENT_SCOPE)
endfunction()

function(_aros_collect_interface_dependency_artifacts out_files_var out_targets_var)
  set(_dependency_files)
  set(_dependency_targets)

  foreach(_interface_name IN LISTS ARGN)
    _aros_sanitize_property_key("${_interface_name}" _aros_interface_key)
    get_property(
      _interface_target
      GLOBAL
      PROPERTY "AROS_MODULE_INTERFACE_TARGET_${_aros_interface_key}"
    )
    if(NOT _interface_target OR NOT TARGET "${_interface_target}")
      continue()
    endif()

    list(APPEND _dependency_targets "${_interface_target}")

    get_target_property(_interface_stamp "${_interface_target}" AROS_MODULE_INTERFACE_STAMP)
    if(_interface_stamp AND NOT _interface_stamp STREQUAL "AROS_MODULE_INTERFACE_STAMP-NOTFOUND")
      list(APPEND _dependency_files "${_interface_stamp}")
    endif()
  endforeach()

  list(REMOVE_DUPLICATES _dependency_files)
  list(REMOVE_DUPLICATES _dependency_targets)
  set(${out_files_var} "${_dependency_files}" PARENT_SCOPE)
  set(${out_targets_var} "${_dependency_targets}" PARENT_SCOPE)
endfunction()

function(_aros_read_mmake_logical_lines file_path out_var)
  file(STRINGS "${file_path}" _raw_lines)
  set(_logical_lines)
  set(_current "")

  foreach(_raw_line IN LISTS _raw_lines)
    string(REGEX REPLACE "[\r\n]+$" "" _line "${_raw_line}")
    if(_current STREQUAL "")
      set(_current "${_line}")
    else()
      string(APPEND _current " " "${_line}")
    endif()

    if(_current MATCHES "\\\\[ \t]*$")
      string(REGEX REPLACE "\\\\[ \t]*$" "" _current "${_current}")
      string(STRIP "${_current}" _current)
    else()
      string(STRIP "${_current}" _current)
      if(NOT _current STREQUAL "")
        string(REPLACE ";" "\\;" _current "${_current}")
        list(APPEND _logical_lines "${_current}")
      endif()
      set(_current "")
    endif()
  endforeach()

  if(NOT _current STREQUAL "")
    string(STRIP "${_current}" _current)
    string(REPLACE ";" "\\;" _current "${_current}")
    list(APPEND _logical_lines "${_current}")
  endif()

  set(${out_var} "${_logical_lines}" PARENT_SCOPE)
endfunction()

function(_aros_collect_include_interface_modules_from_files out_var)
  set(_source_scan_extensions
    .c
    .cc
    .cpp
    .cxx
    .h
    .hpp
    .s
    .S
  )
  set(_collected_modules)

  foreach(_input_path IN LISTS ARGN)
    if(NOT EXISTS "${_input_path}" OR IS_DIRECTORY "${_input_path}")
      continue()
    endif()

    get_filename_component(_input_ext "${_input_path}" EXT)
    list(FIND _source_scan_extensions "${_input_ext}" _ext_index)
    if(_ext_index EQUAL -1)
      continue()
    endif()

    file(STRINGS "${_input_path}" _include_lines
      REGEX "^[ \t]*#[ \t]*include[ \t]*<((proto|inline|defines)/[^>]+|clib/[^>]+_protos\\.h)>"
    )

    foreach(_include_line IN LISTS _include_lines)
      set(_module_name "")
      if(_include_line MATCHES "<(proto|inline|defines)/([^>]+)\\.h>")
        set(_module_name "${CMAKE_MATCH_2}")
      elseif(_include_line MATCHES "<clib/([^>]+)_protos\\.h>")
        set(_module_name "${CMAKE_MATCH_1}")
      endif()

      if(NOT _module_name STREQUAL "")
        list(APPEND _collected_modules "${_module_name}")
      endif()
    endforeach()
  endforeach()

  list(REMOVE_DUPLICATES _collected_modules)
  set(${out_var} "${_collected_modules}" PARENT_SCOPE)
endfunction()

function(_aros_extract_mmake_build_module_metadata mmakefile_src module_path out_prefix)
  _aros_read_mmake_logical_lines("${mmakefile_src}" _logical_lines)

  set(_module_name "")
  set(_module_type "")
  set(_module_mmake "")
  set(_module_conf "")
  set(_module_suffix "")
  set(_module_archspecific FALSE)
  set(_module_sdk "public")
  set(_module_link_libs)
  set(_module_use_sdks)

  foreach(_line IN LISTS _logical_lines)
    if(_line MATCHES "^#" OR _line MATCHES "^include " OR _line MATCHES "^-include ")
      continue()
    endif()

    if(_line MATCHES "^%build_module[^ \t]*[ \t]+(.*)$")
      set(_arg_string "${CMAKE_MATCH_1}")
      separate_arguments(_tokens NATIVE_COMMAND "${_arg_string}")
      foreach(_token IN LISTS _tokens)
        if(NOT _token MATCHES "^([^=]+)=(.*)$")
          continue()
        endif()
        set(_key "${CMAKE_MATCH_1}")
        set(_value "${CMAKE_MATCH_2}")
        _aros_expand_make_tokens("${_value}" _value)
        _aros_unwrap_strip_expression("${_value}" _value)
        if(_key STREQUAL "mmake")
          set(_module_mmake "${_value}")
        elseif(_key STREQUAL "modname")
          set(_module_name "${_value}")
        elseif(_key STREQUAL "modtype")
          set(_module_type "${_value}")
        elseif(_key STREQUAL "conffile")
          set(_module_conf "${_value}")
        elseif(_key STREQUAL "modsuffix")
          set(_module_suffix "${_value}")
        elseif(_key STREQUAL "archspecific" AND _value STREQUAL "yes")
          set(_module_archspecific TRUE)
        elseif(_key STREQUAL "sdk")
          set(_module_sdk "${_value}")
        elseif(_key STREQUAL "uselibs")
          separate_arguments(_module_link_libs NATIVE_COMMAND "${_value}")
          _aros_remove_empty_entries(_module_link_libs)
          _aros_remove_token_entries(_module_link_libs "\\")
        elseif(_key STREQUAL "usesdks")
          separate_arguments(_module_use_sdks NATIVE_COMMAND "${_value}")
          _aros_remove_empty_entries(_module_use_sdks)
          _aros_remove_token_entries(_module_use_sdks "\\")
        endif()
      endforeach()
      break()
    endif()
  endforeach()

  if(NOT _module_name OR NOT _module_type)
    message(FATAL_ERROR "Could not extract modname/modtype from ${mmakefile_src}")
  endif()

  if(_module_conf)
    if(IS_ABSOLUTE "${_module_conf}")
      set(_module_conf_path "${_module_conf}")
    else()
      set(_module_conf_path "${CMAKE_SOURCE_DIR}/${module_path}/${_module_conf}")
    endif()
  else()
    set(_module_conf_path "${CMAKE_SOURCE_DIR}/${module_path}/${_module_name}.conf")
  endif()

  set(${out_prefix}_MODULE_NAME "${_module_name}" PARENT_SCOPE)
  set(${out_prefix}_MODULE_TYPE "${_module_type}" PARENT_SCOPE)
  set(${out_prefix}_MMAKE_NAME "${_module_mmake}" PARENT_SCOPE)
  set(${out_prefix}_MODULE_CONF "${_module_conf_path}" PARENT_SCOPE)
  set(${out_prefix}_MODULE_SUFFIX "${_module_suffix}" PARENT_SCOPE)
  set(${out_prefix}_ARCHSPECIFIC "${_module_archspecific}" PARENT_SCOPE)
  set(${out_prefix}_MODULE_SDK "${_module_sdk}" PARENT_SCOPE)
  set(${out_prefix}_MODULE_LINK_LIBS "${_module_link_libs}" PARENT_SCOPE)
  set(${out_prefix}_MODULE_USE_SDKS "${_module_use_sdks}" PARENT_SCOPE)
endfunction()

function(_aros_extract_mmake_build_linklib_metadata mmakefile_src out_prefix)
  set(_options)
  set(_one_value_args
    MMAKE_NAME
    LIBNAME
  )
  cmake_parse_arguments(AROS_LINKLIB "${_options}" "${_one_value_args}" "" ${ARGN})

  if(NOT AROS_LINKLIB_MMAKE_NAME AND NOT AROS_LINKLIB_LIBNAME)
    message(FATAL_ERROR "Linklib metadata extraction requires MMAKE_NAME or LIBNAME")
  endif()

  _aros_read_mmake_logical_lines("${mmakefile_src}" _logical_lines)

  set(_matched FALSE)
  foreach(_line IN LISTS _logical_lines)
    if(_line MATCHES "^#" OR _line MATCHES "^include " OR _line MATCHES "^-include ")
      continue()
    endif()

    if(NOT _line MATCHES "^%build_linklib[^ \t]*[ \t]+(.*)$")
      continue()
    endif()

    set(_arg_string "${CMAKE_MATCH_1}")
    separate_arguments(_tokens NATIVE_COMMAND "${_arg_string}")

    set(_candidate_mmake "")
    set(_candidate_libname "")
    set(_candidate_sdk "public")
    set(_candidate_libdir "")

    foreach(_token IN LISTS _tokens)
      if(NOT _token MATCHES "^([^=]+)=(.*)$")
        continue()
      endif()
      set(_key "${CMAKE_MATCH_1}")
      set(_value "${CMAKE_MATCH_2}")
      if(_key STREQUAL "mmake")
        set(_candidate_mmake "${_value}")
      elseif(_key STREQUAL "libname")
        set(_candidate_libname "${_value}")
      elseif(_key STREQUAL "sdk")
        set(_candidate_sdk "${_value}")
      elseif(_key STREQUAL "libdir")
        set(_candidate_libdir "${_value}")
      endif()
    endforeach()

    set(_mmake_matches TRUE)
    if(AROS_LINKLIB_MMAKE_NAME AND NOT _candidate_mmake STREQUAL "${AROS_LINKLIB_MMAKE_NAME}")
      set(_mmake_matches FALSE)
    endif()
    set(_libname_matches TRUE)
    if(AROS_LINKLIB_LIBNAME AND NOT _candidate_libname STREQUAL "${AROS_LINKLIB_LIBNAME}")
      set(_libname_matches FALSE)
    endif()
    if(NOT _mmake_matches OR NOT _libname_matches)
      continue()
    endif()

    set(_matched TRUE)
    set(${out_prefix}_MMAKE_NAME "${_candidate_mmake}" PARENT_SCOPE)
    set(${out_prefix}_LIBNAME "${_candidate_libname}" PARENT_SCOPE)
    set(${out_prefix}_SDK "${_candidate_sdk}" PARENT_SCOPE)
    set(${out_prefix}_LIBDIR "${_candidate_libdir}" PARENT_SCOPE)
    break()
  endforeach()

  if(NOT _matched)
    message(FATAL_ERROR "Could not find matching %build_linklib entry in ${mmakefile_src}")
  endif()
endfunction()

function(_aros_extract_mmake_include_interface_metadata mmakefile_src module_name out_names out_depends)
  _aros_read_mmake_logical_lines("${mmakefile_src}" _logical_lines)

  set(_interface_names)
  set(_interface_depends)
  set(_preferred_name "kernel-${module_name}-includes")

  foreach(_line IN LISTS _logical_lines)
    if(NOT _line MATCHES "^#MM-?[ \t]+([^ \t:]+)[ \t]*:(.*)$")
      continue()
    endif()

    set(_interface_name "${CMAKE_MATCH_1}")
    set(_dep_string "${CMAKE_MATCH_2}")
    if(NOT _interface_name MATCHES "-includes$")
      continue()
    endif()

    list(APPEND _interface_names "${_interface_name}")

    string(STRIP "${_dep_string}" _dep_string)
    if(_interface_name STREQUAL "${_preferred_name}" AND NOT _dep_string STREQUAL "")
      separate_arguments(_dep_tokens NATIVE_COMMAND "${_dep_string}")
      foreach(_dep_token IN LISTS _dep_tokens)
        if(_dep_token MATCHES "-includes$")
          list(APPEND _interface_depends "${_dep_token}")
        endif()
      endforeach()
    endif()
  endforeach()

  list(REMOVE_DUPLICATES _interface_names)
  list(REMOVE_DUPLICATES _interface_depends)

  list(FIND _interface_names "${_preferred_name}" _preferred_index)
  if(_preferred_index EQUAL -1)
    list(INSERT _interface_names 0 "${_preferred_name}")
  endif()

  set(${out_names} "${_interface_names}" PARENT_SCOPE)
  set(${out_depends} "${_interface_depends}" PARENT_SCOPE)
endfunction()

function(_aros_collect_active_module_layer_mmakefiles module_dir_name out_var)
  set(_module_mmake_name "")
  if(ARGC GREATER 2)
    set(_module_mmake_name "${ARGV2}")
  endif()

  if(NOT _module_mmake_name STREQUAL "")
    aros_layering_collect_resolved_module_layer_mmakefiles(
      "${module_dir_name}"
      "${_module_mmake_name}"
      _layer_mmakefiles
      _resolved_layers
      _reachable_aliases
    )
    set(${out_var} "${_layer_mmakefiles}" PARENT_SCOPE)
    return()
  endif()

  _aros_get_target_context(_arch _cpu _variant _family)
  set(_layer_mmakefiles)
  foreach(_candidate IN ITEMS
      "${CMAKE_SOURCE_DIR}/arch/all-${_family}/${module_dir_name}/mmakefile.src"
      "${CMAKE_SOURCE_DIR}/arch/all-${_arch}/${module_dir_name}/mmakefile.src"
      "${CMAKE_SOURCE_DIR}/arch/${_cpu}-${_family}/${module_dir_name}/mmakefile.src"
      "${CMAKE_SOURCE_DIR}/arch/${_cpu}-${_arch}/${module_dir_name}/mmakefile.src"
      "${CMAKE_SOURCE_DIR}/arch/${_cpu}-all/${module_dir_name}/mmakefile.src")
    if(EXISTS "${_candidate}")
      list(APPEND _layer_mmakefiles "${_candidate}")
    endif()
  endforeach()
  if(_variant)
    foreach(_candidate IN ITEMS
        "${CMAKE_SOURCE_DIR}/arch/all-${_arch}/${_variant}/${module_dir_name}/mmakefile.src"
        "${CMAKE_SOURCE_DIR}/arch/${_cpu}-${_arch}/${_variant}/${module_dir_name}/mmakefile.src")
      if(EXISTS "${_candidate}")
        list(APPEND _layer_mmakefiles "${_candidate}")
      endif()
    endforeach()
  endif()
  list(REMOVE_DUPLICATES _layer_mmakefiles)
  set(${out_var} "${_layer_mmakefiles}" PARENT_SCOPE)
endfunction()

function(_aros_extract_layer_interface_depends mmake_name out_var)
  set(_layer_depends)
  foreach(_mmakefile_src IN LISTS ARGN)
    if(NOT EXISTS "${_mmakefile_src}")
      continue()
    endif()
    _aros_read_mmake_logical_lines("${_mmakefile_src}" _logical_lines)
    foreach(_line IN LISTS _logical_lines)
      if(NOT _line MATCHES "^#MM-?[ \t]+([^ \t:]+)[ \t]*:(.*)$")
        continue()
      endif()
      set(_target_name "${CMAKE_MATCH_1}")
      set(_dep_string "${CMAKE_MATCH_2}")
      if(NOT _target_name MATCHES "^${mmake_name}($|-)")
        continue()
      endif()
      string(STRIP "${_dep_string}" _dep_string)
      if(_dep_string STREQUAL "")
        continue()
      endif()
      separate_arguments(_dep_tokens NATIVE_COMMAND "${_dep_string}")
      foreach(_dep_token IN LISTS _dep_tokens)
        if(_dep_token MATCHES "-includes$")
          list(APPEND _layer_depends "${_dep_token}")
        endif()
      endforeach()
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES _layer_depends)
  set(${out_var} "${_layer_depends}" PARENT_SCOPE)
endfunction()

function(aros_register_layered_module_sources_target target_name module_path)
  add_custom_target(
    "${target_name}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            -DAROS_TARGET=${AROS_TARGET}
            -DMODULE_PATH=${module_path}
            -P "${CMAKE_SOURCE_DIR}/cmake/report_layered_module.cmake"
    DEPENDS aros-configure
    COMMENT "Reporting layered source mapping for ${module_path}"
    VERBATIM
  )
endfunction()

function(aros_add_flexcat_header target_name)
  set(_options)
  set(_one_value_args
    OUTPUT
    CD_FILE
    SOURCE_DESCRIPTION
  )
  set(_multi_value_args
    DEPENDS
  )
  cmake_parse_arguments(AROS_FLEXCAT "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_FLEXCAT_OUTPUT OR NOT AROS_FLEXCAT_CD_FILE OR NOT AROS_FLEXCAT_SOURCE_DESCRIPTION)
    message(FATAL_ERROR "aros_add_flexcat_header requires OUTPUT, CD_FILE, and SOURCE_DESCRIPTION")
  endif()
  if(NOT TARGET flexcat)
    message(FATAL_ERROR "aros_add_flexcat_header requires the native flexcat target")
  endif()

  get_filename_component(_aros_flexcat_output_dir "${AROS_FLEXCAT_OUTPUT}" DIRECTORY)
  add_custom_command(
    OUTPUT "${AROS_FLEXCAT_OUTPUT}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_aros_flexcat_output_dir}"
    COMMAND "$<TARGET_FILE:flexcat>" "${AROS_FLEXCAT_CD_FILE}" "${AROS_FLEXCAT_OUTPUT}=${AROS_FLEXCAT_SOURCE_DESCRIPTION}"
    DEPENDS
      flexcat
      "${AROS_FLEXCAT_CD_FILE}"
      "${AROS_FLEXCAT_SOURCE_DESCRIPTION}"
      ${AROS_FLEXCAT_DEPENDS}
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${AROS_FLEXCAT_OUTPUT}")
endfunction()

function(aros_add_emit_tool_stdout_file target_name)
  set(_options)
  set(_one_value_args
    OUTPUT
    PROGRAM
  )
  set(_multi_value_args
    COMMAND_ARGS
    DEPENDS
  )
  cmake_parse_arguments(AROS_EMIT "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_EMIT_OUTPUT OR NOT AROS_EMIT_PROGRAM)
    message(FATAL_ERROR "aros_add_emit_tool_stdout_file requires OUTPUT and PROGRAM")
  endif()

  _aros_encode_list("${AROS_EMIT_COMMAND_ARGS}" _aros_emit_command_args)
  get_filename_component(_aros_emit_output_dir "${AROS_EMIT_OUTPUT}" DIRECTORY)
  add_custom_command(
    OUTPUT "${AROS_EMIT_OUTPUT}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_aros_emit_output_dir}"
    COMMAND "${CMAKE_COMMAND}"
            -DPROGRAM=${AROS_EMIT_PROGRAM}
            -DCOMMAND_ARGS=${_aros_emit_command_args}
            -DOUTPUT_FILE=${AROS_EMIT_OUTPUT}
            -P "${CMAKE_SOURCE_DIR}/cmake/emit_tool_stdout_to_file.cmake"
    DEPENDS
      "${CMAKE_SOURCE_DIR}/cmake/emit_tool_stdout_to_file.cmake"
      ${AROS_EMIT_DEPENDS}
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${AROS_EMIT_OUTPUT}")
endfunction()

function(aros_register_genmodule_module target_name)
  set(_options
    ARCHSPECIFIC
  )
  set(_one_value_args
    MODULE_PATH
    MODULE_MMAKE_NAME
    MODULE_NAME
    MODULE_TYPE
    MODULE_CONF
    MODULE_SDK
    MMAKEFILE_SRC
    MODULE_VERSION_EXTRA
    MODULE_SUFFIX
    MODULE_FILENAME_SEPARATOR
    OUTPUT_SUBDIR
    OUTPUT_SUFFIX
  )
  set(_multi_value_args
    BASE_SOURCES
    LAYER_OVERRIDES
    LAYER_ADDITIONS
    LAYER_EXCLUSIONS
    INCLUDE_DIRS
    COMPILE_DEFINITIONS
    COMPILE_OPTIONS
    LINK_OPTIONS
    LINK_LIBS
    INTERFACE_NAMES
    INTERFACE_DEPENDS
    DEPENDS
  )
  cmake_parse_arguments(AROS_MODULE "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_MODULE_MODULE_PATH
     OR NOT AROS_MODULE_MODULE_NAME
     OR NOT AROS_MODULE_MODULE_TYPE
     OR NOT AROS_MODULE_MODULE_CONF)
    message(FATAL_ERROR "aros_register_genmodule_module requires module path/name/type/conf")
  endif()

  if((NOT AROS_MODULE_MODULE_MMAKE_NAME OR AROS_MODULE_MODULE_MMAKE_NAME STREQUAL "")
     AND AROS_MODULE_MMAKEFILE_SRC
     AND EXISTS "${AROS_MODULE_MMAKEFILE_SRC}")
    aros_layering_extract_primary_mmake_name(
      "${AROS_MODULE_MMAKEFILE_SRC}"
      AROS_MODULE_MODULE_MMAKE_NAME
    )
  endif()

  if(NOT AROS_MODULE_OUTPUT_SUBDIR OR NOT AROS_MODULE_OUTPUT_SUFFIX)
    if(AROS_MODULE_MODULE_TYPE STREQUAL "library")
      set(_aros_default_output_subdir "Libs")
      set(_aros_default_output_suffix "library")
      set(_aros_default_separator ".")
    elseif(AROS_MODULE_MODULE_TYPE STREQUAL "resource")
      set(_aros_default_output_subdir "Devs")
      set(_aros_default_output_suffix "resource")
      set(_aros_default_separator ".")
    elseif(AROS_MODULE_MODULE_TYPE STREQUAL "device")
      set(_aros_default_output_subdir "Devs")
      set(_aros_default_output_suffix "device")
      set(_aros_default_separator ".")
    elseif(AROS_MODULE_MODULE_TYPE STREQUAL "handler")
      set(_aros_default_output_subdir "L")
      set(_aros_default_output_suffix "handler")
      set(_aros_default_separator "-")
    elseif(AROS_MODULE_MODULE_TYPE STREQUAL "hidd")
      set(_aros_default_output_subdir "Devs/Drivers")
      set(_aros_default_output_suffix "hidd")
      set(_aros_default_separator ".")
    elseif(AROS_MODULE_MODULE_TYPE STREQUAL "usbclass")
      set(_aros_default_output_subdir "Classes/USB")
      set(_aros_default_output_suffix "class")
      set(_aros_default_separator ".")
    else()
      message(FATAL_ERROR
        "No default output mapping for modtype ${AROS_MODULE_MODULE_TYPE}. "
        "Pass OUTPUT_SUBDIR and OUTPUT_SUFFIX explicitly."
      )
    endif()
  endif()

  if(NOT AROS_MODULE_OUTPUT_SUBDIR)
    set(AROS_MODULE_OUTPUT_SUBDIR "${_aros_default_output_subdir}")
  endif()
  if(NOT AROS_MODULE_OUTPUT_SUFFIX)
    set(AROS_MODULE_OUTPUT_SUFFIX "${_aros_default_output_suffix}")
  endif()
  if(NOT AROS_MODULE_MODULE_FILENAME_SEPARATOR)
    if(DEFINED _aros_default_separator)
      set(AROS_MODULE_MODULE_FILENAME_SEPARATOR "${_aros_default_separator}")
    else()
      set(AROS_MODULE_MODULE_FILENAME_SEPARATOR ".")
    endif()
  endif()
  if(NOT AROS_MODULE_MODULE_SUFFIX)
    set(AROS_MODULE_MODULE_SUFFIX "${AROS_MODULE_OUTPUT_SUFFIX}")
  endif()

  string(REPLACE "/" "_" _aros_module_id "${AROS_MODULE_MODULE_PATH}")
  _aros_sanitize_property_key("${AROS_MODULE_MODULE_PATH}" _aros_module_property_key)
  set(_aros_module_work_dir "${CMAKE_BINARY_DIR}/modules/${_aros_module_id}")
  set(_aros_module_generated_dir "${_aros_module_work_dir}/genmodule")
  set(_aros_module_obj_dir "${_aros_module_work_dir}/obj")
  set(_aros_module_interface_stamp "${_aros_module_work_dir}/.${AROS_MODULE_MODULE_NAME}.${AROS_MODULE_MODULE_TYPE}-interfaces.stamp")
  set(_aros_module_interface_target "${target_name}-interface")
  set(_aros_module_native_abi_target "${target_name}-abi")
  string(REPLACE "-" ";" _aros_target_parts "${AROS_TARGET}")
  list(GET _aros_target_parts 0 _aros_target_arch)
  set(_aros_module_runtime_prefix "")
  if(AROS_MODULE_ARCHSPECIFIC)
    set(_aros_module_runtime_prefix "boot/${_aros_target_arch}/")
  endif()
  set(_aros_module_output_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/AROS/${_aros_module_runtime_prefix}${AROS_MODULE_OUTPUT_SUBDIR}")
  set(_aros_module_output
    "${_aros_module_output_dir}/${AROS_MODULE_MODULE_NAME}${AROS_MODULE_MODULE_FILENAME_SEPARATOR}${AROS_MODULE_MODULE_SUFFIX}"
  )
  _aros_get_genmodule_public_linklib_output(
    "${AROS_MODULE_MODULE_NAME}"
    "${AROS_MODULE_MODULE_TYPE}"
    "${AROS_MODULE_MODULE_SUFFIX}"
    _aros_module_public_linklib_output
  )
  _aros_get_genmodule_rel_linklib_output(
    "${AROS_MODULE_MODULE_NAME}"
    "${AROS_MODULE_MODULE_TYPE}"
    "${AROS_MODULE_MODULE_SUFFIX}"
    _aros_module_rel_linklib_output
  )

  get_property(
    _aros_existing_module_target
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_TARGET_${_aros_module_property_key}"
  )
  if(_aros_existing_module_target)
    get_property(
      _aros_existing_interface_target
      GLOBAL
      PROPERTY "AROS_REGISTERED_GENMODULE_INTERFACE_TARGET_${_aros_module_property_key}"
    )
    get_property(
      _aros_existing_interfaces_build_target
      GLOBAL
      PROPERTY "AROS_REGISTERED_GENMODULE_INTERFACES_BUILD_TARGET_${_aros_module_property_key}"
    )
    get_property(
      _aros_existing_output
      GLOBAL
      PROPERTY "AROS_REGISTERED_GENMODULE_OUTPUT_${_aros_module_property_key}"
    )
    get_property(
      _aros_existing_abi_target
      GLOBAL
      PROPERTY "AROS_REGISTERED_GENMODULE_ABI_TARGET_${_aros_module_property_key}"
    )

    add_custom_target("${target_name}-interfaces")
    if(_aros_existing_interfaces_build_target)
      add_dependencies("${target_name}-interfaces" "${_aros_existing_interfaces_build_target}")
    endif()

    add_library("${_aros_module_interface_target}" INTERFACE)
    target_include_directories(
      "${_aros_module_interface_target}"
      INTERFACE
        "$<BUILD_INTERFACE:${AROS_NATIVE_INCLUDE_DIR}>"
    )
    if(_aros_existing_interface_target)
      target_link_libraries("${_aros_module_interface_target}" INTERFACE "${_aros_existing_interface_target}")
    endif()
    add_dependencies("${_aros_module_interface_target}" "${target_name}-interfaces")

    add_custom_target("${target_name}" DEPENDS "${_aros_existing_output}")
    add_custom_target("${_aros_module_native_abi_target}")
    if(_aros_existing_abi_target)
      add_dependencies("${_aros_module_native_abi_target}" "${_aros_existing_abi_target}")
    elseif(_aros_existing_output)
      add_dependencies("${_aros_module_native_abi_target}" "${target_name}")
    endif()

    set(${target_name}_OUTPUT "${_aros_existing_output}" PARENT_SCOPE)
    set(${target_name}_INTERFACES_TARGET "${target_name}-interfaces" PARENT_SCOPE)
    set(${target_name}_INTERFACE_LIBRARY_TARGET "${_aros_module_interface_target}" PARENT_SCOPE)
    set(${target_name}_ABI_TARGET "${_aros_module_native_abi_target}" PARENT_SCOPE)
    return()
  endif()

  if(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR)
    set(_aros_module_toolchain_dir "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}")
  elseif(AROS_CROSSTOOLS_INSTALL_DIR)
    set(_aros_module_toolchain_dir "${AROS_CROSSTOOLS_INSTALL_DIR}")
  elseif(AROS_TOOLCHAIN_INSTALL_DIR)
    set(_aros_module_toolchain_dir "${AROS_TOOLCHAIN_INSTALL_DIR}")
  else()
    set(_aros_module_toolchain_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools")
  endif()
  set(_aros_module_target_cc "")
  foreach(_aros_module_cc_candidate IN ITEMS
      "${_aros_module_toolchain_dir}/bin/${AROS_CROSSTOOLS_TARGET_CPU}-aros-gcc"
      "${_aros_module_toolchain_dir}/${AROS_CROSSTOOLS_TARGET_CPU}-aros-gcc")
    if(EXISTS "${_aros_module_cc_candidate}")
      set(_aros_module_target_cc "${_aros_module_cc_candidate}")
      break()
    endif()
  endforeach()
  set(_aros_module_sysroot "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/AROS/Development")

  set(_aros_module_build_deps
    aros-configure
    genmodule
    "${CMAKE_SOURCE_DIR}/cmake/build_genmodule_module.cmake"
    "${AROS_MODULE_MODULE_CONF}"
    ${AROS_MODULE_DEPENDS}
  )
  if(TARGET aros-native-includes)
    list(APPEND _aros_module_build_deps aros-native-includes)
  endif()
  if(DEFINED AROS_NATIVE_INCLUDES_STAMP)
    list(APPEND _aros_module_build_deps "${AROS_NATIVE_INCLUDES_STAMP}")
  endif()
  if(TARGET aros-crosstools-toolchain AND NOT _aros_module_target_cc)
    list(APPEND _aros_module_build_deps aros-crosstools-toolchain)
  endif()
  set(_aros_module_runtime_build_deps ${_aros_module_build_deps})
  if(TARGET aros-sdk-interfaces-native)
    list(APPEND _aros_module_runtime_build_deps aros-sdk-interfaces-native)
  endif()
  if(TARGET aros-core-linklibs-native)
    list(APPEND _aros_module_runtime_build_deps aros-core-linklibs-native)
  endif()
  if(TARGET aros-arch-linklibs-native)
    list(APPEND _aros_module_runtime_build_deps aros-arch-linklibs-native)
  endif()

  _aros_read_config_tokens("TARGET_C_LIBS" _aros_module_target_c_libs)
  _aros_collect_link_library_names(_aros_module_target_c_lib_names ${_aros_module_target_c_libs})
  _aros_collect_link_library_names(_aros_module_option_link_lib_names ${AROS_MODULE_LINK_OPTIONS})

  _aros_encode_list("${AROS_MODULE_BASE_SOURCES}" _aros_module_base_sources)
  _aros_encode_list("${AROS_MODULE_LAYER_OVERRIDES}" _aros_module_layer_overrides)
  _aros_encode_list("${AROS_MODULE_LAYER_ADDITIONS}" _aros_module_layer_additions)
  _aros_encode_list("${AROS_MODULE_LAYER_EXCLUSIONS}" _aros_module_layer_exclusions)
  _aros_encode_list("${AROS_MODULE_INCLUDE_DIRS}" _aros_module_include_dirs)
  _aros_encode_list("${AROS_MODULE_COMPILE_DEFINITIONS}" _aros_module_compile_definitions)
  _aros_encode_list("${AROS_MODULE_COMPILE_OPTIONS}" _aros_module_compile_options)
  _aros_encode_list("${AROS_MODULE_LINK_OPTIONS}" _aros_module_link_options)
  set(_aros_module_resolved_link_libs ${AROS_MODULE_LINK_LIBS})
  if(AROS_COMPILER_NATIVE_MODULE_LINKLIBS)
    list(APPEND _aros_module_resolved_link_libs ${AROS_COMPILER_NATIVE_MODULE_LINKLIBS})
  endif()
  list(REMOVE_DUPLICATES _aros_module_resolved_link_libs)
  _aros_encode_list("${_aros_module_resolved_link_libs}" _aros_module_link_libs)
  _aros_encode_list("${AROS_COMPILER_NATIVE_MODULE_AUTOLIBS}" _aros_module_auto_link_libs)

  set(_aros_module_archive_dep_names ${_aros_module_resolved_link_libs})
  list(APPEND _aros_module_archive_dep_names ${AROS_COMPILER_NATIVE_MODULE_AUTOLIBS})
  list(APPEND _aros_module_archive_dep_names ${_aros_module_target_c_lib_names})
  list(APPEND _aros_module_archive_dep_names ${_aros_module_option_link_lib_names})
  list(REMOVE_DUPLICATES _aros_module_archive_dep_names)
  _aros_collect_registered_archive_dependencies(
    _aros_module_archive_dep_files
    _aros_module_archive_dep_targets
    ${_aros_module_archive_dep_names}
  )
  _aros_collect_interface_dependency_artifacts(
    _aros_module_interface_dep_files
    _aros_module_interface_dep_targets
    ${AROS_MODULE_INTERFACE_DEPENDS}
  )

  set(_aros_module_interface_build_file_deps ${_aros_module_interface_dep_files})
  set(_aros_module_interface_build_target_deps ${_aros_module_build_deps})
  list(APPEND _aros_module_interface_build_target_deps ${_aros_module_interface_dep_targets})
  list(REMOVE_DUPLICATES _aros_module_interface_build_target_deps)

  set(_aros_module_runtime_build_file_deps
    "${_aros_module_interface_stamp}"
    ${_aros_module_interface_dep_files}
    ${_aros_module_archive_dep_files}
  )
  set(_aros_module_runtime_build_target_deps ${_aros_module_runtime_build_deps})
  list(APPEND _aros_module_runtime_build_target_deps ${_aros_module_interface_dep_targets})
  list(APPEND _aros_module_runtime_build_target_deps ${_aros_module_archive_dep_targets})
  list(REMOVE_DUPLICATES _aros_module_runtime_build_target_deps)

  add_custom_command(
    OUTPUT "${_aros_module_interface_stamp}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            -DAROS_TARGET=${AROS_TARGET}
            -DAROS_GENMODULE=$<TARGET_FILE:genmodule>
            -DAROS_TOOLCHAIN_DIR=${_aros_module_toolchain_dir}
            -DAROS_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros
            -DAROS_SYSROOT=${_aros_module_sysroot}
            -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
            -DAROS_NATIVE_PUBLIC_LIB_DIR=${AROS_NATIVE_PUBLIC_LIB_DIR}
            -DAROS_NATIVE_PRIVATE_LIB_DIR=${AROS_NATIVE_PRIVATE_LIB_DIR}
            -DAROS_NATIVE_REL_LIB_DIR=${AROS_NATIVE_REL_LIB_DIR}
            -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
            -DINTERFACE_ONLY=ON
            -DMODULE_PATH=${AROS_MODULE_MODULE_PATH}
            -DMODULE_NAME=${AROS_MODULE_MODULE_NAME}
            -DMODULE_TYPE=${AROS_MODULE_MODULE_TYPE}
            -DMODULE_CONF=${AROS_MODULE_MODULE_CONF}
            -DMODULE_SDK=${AROS_MODULE_MODULE_SDK}
            -DMODULE_MMAKEFILE=${AROS_MODULE_MMAKEFILE_SRC}
            -DMODULE_MMAKE_NAME=${AROS_MODULE_MODULE_MMAKE_NAME}
            -DMODULE_VERSION_EXTRA=${AROS_MODULE_MODULE_VERSION_EXTRA}
            -DMODULE_OUTPUT=${_aros_module_output}
            -DMODULE_GENERATED_DIR=${_aros_module_generated_dir}
            -DMODULE_OBJ_DIR=${_aros_module_obj_dir}
            -DMODULE_ARCHSPECIFIC=$<BOOL:${AROS_MODULE_ARCHSPECIFIC}>
            -DMODULE_BASE_SOURCES=${_aros_module_base_sources}
            -DMODULE_LAYER_OVERRIDES=${_aros_module_layer_overrides}
            -DMODULE_LAYER_ADDITIONS=${_aros_module_layer_additions}
            -DMODULE_LAYER_EXCLUSIONS=${_aros_module_layer_exclusions}
            -DMODULE_INCLUDE_DIRS=${_aros_module_include_dirs}
            -DMODULE_COMPILE_DEFINITIONS=${_aros_module_compile_definitions}
            -DMODULE_COMPILE_OPTIONS=${_aros_module_compile_options}
            -DMODULE_LINK_OPTIONS=${_aros_module_link_options}
            -DMODULE_LINK_LIBS=${_aros_module_link_libs}
            -DMODULE_AUTO_LINK_LIBS=${_aros_module_auto_link_libs}
            -P "${CMAKE_SOURCE_DIR}/cmake/build_genmodule_module.cmake"
    COMMAND "${CMAKE_COMMAND}" -E touch "${_aros_module_interface_stamp}"
    DEPENDS
      ${_aros_module_interface_build_target_deps}
      ${_aros_module_interface_build_file_deps}
    COMMENT "Generating native CMake ${AROS_MODULE_MODULE_PATH} interfaces"
    VERBATIM
  )

  add_custom_target("${target_name}-interfaces" DEPENDS "${_aros_module_interface_stamp}")
  add_library("${_aros_module_interface_target}" INTERFACE)
  target_include_directories(
    "${_aros_module_interface_target}"
    INTERFACE
      "$<BUILD_INTERFACE:${AROS_NATIVE_INCLUDE_DIR}>"
  )
  add_dependencies("${_aros_module_interface_target}" "${target_name}-interfaces")

  if(NOT AROS_MODULE_INTERFACE_NAMES)
    set(AROS_MODULE_INTERFACE_NAMES "kernel-${AROS_MODULE_MODULE_NAME}-includes")
  endif()
  set_target_properties(
    "${_aros_module_interface_target}"
    PROPERTIES
      AROS_MODULE_INTERFACE_STAMP "${_aros_module_interface_stamp}"
      AROS_MODULE_INTERFACE_NAMES "${AROS_MODULE_INTERFACE_NAMES}"
      AROS_MODULE_INTERFACE_DEPENDS "${AROS_MODULE_INTERFACE_DEPENDS}"
      AROS_MODULE_PUBLIC_LINKLIB_OUTPUT "${_aros_module_public_linklib_output}"
  )

  get_property(_aros_registered_interface_targets GLOBAL PROPERTY AROS_REGISTERED_MODULE_INTERFACE_TARGETS)
  list(APPEND _aros_registered_interface_targets "${_aros_module_interface_target}")
  list(REMOVE_DUPLICATES _aros_registered_interface_targets)
  set_property(GLOBAL PROPERTY AROS_REGISTERED_MODULE_INTERFACE_TARGETS "${_aros_registered_interface_targets}")

  foreach(_aros_interface_name IN LISTS AROS_MODULE_INTERFACE_NAMES)
    _aros_sanitize_property_key("${_aros_interface_name}" _aros_interface_key)
    set_property(
      GLOBAL
      PROPERTY "AROS_MODULE_INTERFACE_TARGET_${_aros_interface_key}"
      "${_aros_module_interface_target}"
    )
  endforeach()
  _aros_sanitize_property_key("${AROS_MODULE_MODULE_NAME}" _aros_module_name_key)
  set_property(
    GLOBAL
    PROPERTY "AROS_MODULE_NAME_INTERFACE_TARGET_${_aros_module_name_key}"
    "${_aros_module_interface_target}"
  )

  add_custom_command(
    OUTPUT "${_aros_module_output}"
    BYPRODUCTS
      "${_aros_module_public_linklib_output}"
      "${_aros_module_rel_linklib_output}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            -DAROS_TARGET=${AROS_TARGET}
            -DAROS_GENMODULE=$<TARGET_FILE:genmodule>
            -DAROS_TOOLCHAIN_DIR=${_aros_module_toolchain_dir}
            -DAROS_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros
            -DAROS_SYSROOT=${_aros_module_sysroot}
            -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
            -DAROS_NATIVE_PUBLIC_LIB_DIR=${AROS_NATIVE_PUBLIC_LIB_DIR}
            -DAROS_NATIVE_PRIVATE_LIB_DIR=${AROS_NATIVE_PRIVATE_LIB_DIR}
            -DAROS_NATIVE_REL_LIB_DIR=${AROS_NATIVE_REL_LIB_DIR}
            -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
            -DMODULE_PATH=${AROS_MODULE_MODULE_PATH}
            -DMODULE_NAME=${AROS_MODULE_MODULE_NAME}
            -DMODULE_TYPE=${AROS_MODULE_MODULE_TYPE}
            -DMODULE_CONF=${AROS_MODULE_MODULE_CONF}
            -DMODULE_SDK=${AROS_MODULE_MODULE_SDK}
            -DMODULE_MMAKEFILE=${AROS_MODULE_MMAKEFILE_SRC}
            -DMODULE_MMAKE_NAME=${AROS_MODULE_MODULE_MMAKE_NAME}
            -DMODULE_VERSION_EXTRA=${AROS_MODULE_MODULE_VERSION_EXTRA}
            -DMODULE_OUTPUT=${_aros_module_output}
            -DMODULE_GENERATED_DIR=${_aros_module_generated_dir}
            -DMODULE_OBJ_DIR=${_aros_module_obj_dir}
            -DMODULE_ARCHSPECIFIC=$<BOOL:${AROS_MODULE_ARCHSPECIFIC}>
            -DMODULE_BASE_SOURCES=${_aros_module_base_sources}
            -DMODULE_LAYER_OVERRIDES=${_aros_module_layer_overrides}
            -DMODULE_LAYER_ADDITIONS=${_aros_module_layer_additions}
            -DMODULE_LAYER_EXCLUSIONS=${_aros_module_layer_exclusions}
            -DMODULE_INCLUDE_DIRS=${_aros_module_include_dirs}
            -DMODULE_COMPILE_DEFINITIONS=${_aros_module_compile_definitions}
            -DMODULE_COMPILE_OPTIONS=${_aros_module_compile_options}
            -DMODULE_LINK_OPTIONS=${_aros_module_link_options}
            -DMODULE_LINK_LIBS=${_aros_module_link_libs}
            -DMODULE_AUTO_LINK_LIBS=${_aros_module_auto_link_libs}
            -P "${CMAKE_SOURCE_DIR}/cmake/build_genmodule_module.cmake"
    DEPENDS
      ${_aros_module_runtime_build_target_deps}
      ${_aros_module_runtime_build_file_deps}
    COMMENT "Building native CMake ${AROS_MODULE_MODULE_PATH} module"
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${_aros_module_output}")
  add_custom_target("${_aros_module_native_abi_target}" DEPENDS "${_aros_module_output}")
  set(${target_name}_OUTPUT "${_aros_module_output}" PARENT_SCOPE)
  set(${target_name}_INTERFACES_TARGET "${target_name}-interfaces" PARENT_SCOPE)
  set(${target_name}_INTERFACE_LIBRARY_TARGET "${_aros_module_interface_target}" PARENT_SCOPE)
  set(${target_name}_ABI_TARGET "${_aros_module_native_abi_target}" PARENT_SCOPE)
  set_target_properties(
    "${_aros_module_interface_target}"
    PROPERTIES
      AROS_MODULE_OWNER_TARGET "${target_name}"
      AROS_MODULE_OWNER_ABI_TARGET "${_aros_module_native_abi_target}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_TARGET_${_aros_module_property_key}"
    "${target_name}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_INTERFACE_TARGET_${_aros_module_property_key}"
    "${_aros_module_interface_target}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_INTERFACES_BUILD_TARGET_${_aros_module_property_key}"
    "${target_name}-interfaces"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_OUTPUT_${_aros_module_property_key}"
    "${_aros_module_output}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_ABI_TARGET_${_aros_module_property_key}"
    "${_aros_module_native_abi_target}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_PUBLIC_LINKLIB_OUTPUT_${_aros_module_name_key}"
    "${_aros_module_public_linklib_output}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_PUBLIC_LINKLIB_TARGET_${_aros_module_name_key}"
    "${target_name}"
  )
  _aros_sanitize_property_key("${AROS_MODULE_MODULE_NAME}_rel" _aros_module_rel_name_key)
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_REL_LINKLIB_OUTPUT_${_aros_module_rel_name_key}"
    "${_aros_module_rel_linklib_output}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_GENMODULE_REL_LINKLIB_TARGET_${_aros_module_rel_name_key}"
    "${target_name}"
  )
endfunction()

function(aros_register_mmake_genmodule_module target_name)
  set(_options)
  set(_one_value_args
    MODULE_PATH
    MMAKEFILE_SRC
    MODULE_CONF
  )
  set(_multi_value_args
    DEPENDS
    LAYER_EXCLUSIONS
  )
  cmake_parse_arguments(AROS_MMAKE "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_MMAKE_MODULE_PATH)
    message(FATAL_ERROR "aros_register_mmake_genmodule_module requires MODULE_PATH")
  endif()

  if(AROS_MMAKE_MMAKEFILE_SRC)
    set(_aros_mmakefile_src "${AROS_MMAKE_MMAKEFILE_SRC}")
  else()
    set(_aros_mmakefile_src "${CMAKE_SOURCE_DIR}/${AROS_MMAKE_MODULE_PATH}/mmakefile.src")
  endif()

  _aros_extract_mmake_build_module_metadata("${_aros_mmakefile_src}" "${AROS_MMAKE_MODULE_PATH}" _aros_mmake)
  _aros_extract_conf_rellibs("${_aros_mmake_MODULE_CONF}" _aros_mmake_CONF_RELLIBS)
  _aros_extract_mmake_include_interface_metadata(
    "${_aros_mmakefile_src}"
    "${_aros_mmake_MODULE_NAME}"
    _aros_mmake_INTERFACE_NAMES
    _aros_mmake_INTERFACE_DEPENDS
  )
  get_filename_component(_aros_module_dir_name "${AROS_MMAKE_MODULE_PATH}" NAME)
  _aros_collect_active_module_layer_mmakefiles(
    "${_aros_module_dir_name}"
    _aros_layer_mmakefiles
    "${_aros_mmake_MMAKE_NAME}"
  )
  if(_aros_mmake_MMAKE_NAME AND _aros_layer_mmakefiles)
    _aros_extract_layer_interface_depends(
      "${_aros_mmake_MMAKE_NAME}"
      _aros_mmake_LAYER_INTERFACE_DEPENDS
      ${_aros_layer_mmakefiles}
    )
    list(APPEND _aros_mmake_INTERFACE_DEPENDS ${_aros_mmake_LAYER_INTERFACE_DEPENDS})
    list(REMOVE_DUPLICATES _aros_mmake_INTERFACE_DEPENDS)
  endif()

  if(AROS_MMAKE_MODULE_CONF)
    set(_aros_module_conf "${AROS_MMAKE_MODULE_CONF}")
  else()
    set(_aros_module_conf "${_aros_mmake_MODULE_CONF}")
  endif()

  file(GLOB_RECURSE _aros_module_source_deps
    "${CMAKE_SOURCE_DIR}/${AROS_MMAKE_MODULE_PATH}/*"
    "${CMAKE_SOURCE_DIR}/arch/*/${_aros_module_dir_name}/*"
  )
  list(FILTER _aros_module_source_deps EXCLUDE REGEX "/\\.git/")

  if(_aros_mmake_ARCHSPECIFIC)
    set(_aros_archspecific ARCHSPECIFIC)
  else()
    set(_aros_archspecific)
  endif()

  aros_register_genmodule_module(
    "${target_name}"
    ${_aros_archspecific}
    MODULE_PATH "${AROS_MMAKE_MODULE_PATH}"
    MODULE_MMAKE_NAME "${_aros_mmake_MMAKE_NAME}"
    MODULE_NAME "${_aros_mmake_MODULE_NAME}"
    MODULE_TYPE "${_aros_mmake_MODULE_TYPE}"
    MODULE_CONF "${_aros_module_conf}"
    MODULE_SDK "${_aros_mmake_MODULE_SDK}"
    MMAKEFILE_SRC "${_aros_mmakefile_src}"
    MODULE_SUFFIX "${_aros_mmake_MODULE_SUFFIX}"
    LINK_LIBS ${_aros_mmake_MODULE_LINK_LIBS} ${_aros_mmake_CONF_RELLIBS}
    INTERFACE_NAMES ${_aros_mmake_INTERFACE_NAMES}
    INTERFACE_DEPENDS ${_aros_mmake_INTERFACE_DEPENDS}
    LAYER_EXCLUSIONS ${AROS_MMAKE_LAYER_EXCLUSIONS}
    DEPENDS
      "${_aros_mmakefile_src}"
      "${_aros_module_conf}"
      ${_aros_module_source_deps}
      ${AROS_MMAKE_DEPENDS}
  )
endfunction()

function(aros_register_mmake_linklib target_name)
  set(_options)
  set(_one_value_args
    MODULE_PATH
    MMAKEFILE_SRC
    MMAKE_NAME
    LIBNAME
  )
  set(_multi_value_args
    DEPENDS
  )
  cmake_parse_arguments(AROS_LINKLIB "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_LINKLIB_MODULE_PATH)
    message(FATAL_ERROR "aros_register_mmake_linklib requires MODULE_PATH")
  endif()
  if(NOT AROS_LINKLIB_MMAKE_NAME AND NOT AROS_LINKLIB_LIBNAME)
    message(FATAL_ERROR "aros_register_mmake_linklib requires MMAKE_NAME or LIBNAME")
  endif()

  if(AROS_LINKLIB_MMAKEFILE_SRC)
    set(_aros_mmakefile_src "${AROS_LINKLIB_MMAKEFILE_SRC}")
  else()
    set(_aros_mmakefile_src "${CMAKE_SOURCE_DIR}/${AROS_LINKLIB_MODULE_PATH}/mmakefile.src")
  endif()

  _aros_extract_mmake_build_linklib_metadata(
    "${_aros_mmakefile_src}"
    _aros_linklib
    MMAKE_NAME "${AROS_LINKLIB_MMAKE_NAME}"
    LIBNAME "${AROS_LINKLIB_LIBNAME}"
  )

  if(NOT _aros_linklib_LIBNAME)
    message(FATAL_ERROR "Could not determine libname for ${target_name}")
  endif()

  if(_aros_linklib_LIBDIR)
    message(FATAL_ERROR
      "Explicit libdir handling is not implemented yet for ${AROS_LINKLIB_MODULE_PATH} (${_aros_linklib_LIBNAME})"
    )
  endif()

  if(_aros_linklib_SDK STREQUAL "public" OR _aros_linklib_SDK STREQUAL "")
    set(_aros_linklib_output_dir "${AROS_NATIVE_PUBLIC_LIB_DIR}")
  elseif(_aros_linklib_SDK STREQUAL "private")
    set(_aros_linklib_output_dir "${AROS_NATIVE_PRIVATE_LIB_DIR}")
  else()
    set(_aros_linklib_output_dir "${AROS_NATIVE_BUILD_SDKS_DIR}/${_aros_linklib_SDK}/lib")
  endif()

  set(_aros_linklib_output "${_aros_linklib_output_dir}/lib${_aros_linklib_LIBNAME}.a")
  string(REPLACE "/" "_" _aros_linklib_id "${AROS_LINKLIB_MODULE_PATH}")
  string(REPLACE "." "_" _aros_linklib_lib_id "${_aros_linklib_LIBNAME}")
  set(_aros_linklib_obj_dir "${CMAKE_BINARY_DIR}/linklibs/${_aros_linklib_id}/${_aros_linklib_lib_id}")
  set(_aros_linklib_include_stamp "${_aros_linklib_obj_dir}/.includes.stamp")
  if(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR)
    set(_aros_linklib_toolchain_dir "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}")
  elseif(AROS_CROSSTOOLS_INSTALL_DIR)
    set(_aros_linklib_toolchain_dir "${AROS_CROSSTOOLS_INSTALL_DIR}")
  elseif(AROS_TOOLCHAIN_INSTALL_DIR)
    set(_aros_linklib_toolchain_dir "${AROS_TOOLCHAIN_INSTALL_DIR}")
  else()
    set(_aros_linklib_toolchain_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools")
  endif()
  set(_aros_linklib_sysroot "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/AROS/Development")

  file(GLOB_RECURSE _aros_linklib_source_deps
    "${CMAKE_SOURCE_DIR}/${AROS_LINKLIB_MODULE_PATH}/*"
  )
  list(FILTER _aros_linklib_source_deps EXCLUDE REGEX "/\\.git/")
  _aros_collect_include_interface_modules_from_files(
    _aros_linklib_source_interface_modules
    ${_aros_linklib_source_deps}
  )

  set(_aros_linklib_include_deps
    aros-native-includes
    "${CMAKE_SOURCE_DIR}/cmake/stage_mmake_includes.cmake"
    "${_aros_mmakefile_src}"
    ${AROS_LINKLIB_DEPENDS}
  )
  if(DEFINED AROS_NATIVE_INCLUDES_STAMP)
    list(APPEND _aros_linklib_include_deps "${AROS_NATIVE_INCLUDES_STAMP}")
  endif()

  add_custom_command(
    OUTPUT "${_aros_linklib_include_stamp}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            -DAROS_TARGET=${AROS_TARGET}
            -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
            -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
            -DMMAKEFILE_PATH=${_aros_mmakefile_src}
            -DINCLUDES_SDK=${_aros_linklib_SDK}
            -DINCLUDES_STAMP=${_aros_linklib_include_stamp}
            -P "${CMAKE_SOURCE_DIR}/cmake/stage_mmake_includes.cmake"
    DEPENDS
      ${_aros_linklib_include_deps}
    COMMENT "Staging native CMake ${_aros_linklib_LIBNAME} includes"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${_aros_linklib_output}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            -DAROS_TARGET=${AROS_TARGET}
            -DAROS_TOOLCHAIN_DIR=${_aros_linklib_toolchain_dir}
            -DAROS_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros
            -DAROS_SYSROOT=${_aros_linklib_sysroot}
            -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
            -DAROS_NATIVE_PUBLIC_LIB_DIR=${AROS_NATIVE_PUBLIC_LIB_DIR}
            -DAROS_NATIVE_PRIVATE_LIB_DIR=${AROS_NATIVE_PRIVATE_LIB_DIR}
            -DAROS_NATIVE_REL_LIB_DIR=${AROS_NATIVE_REL_LIB_DIR}
            -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
            -DLINKLIB_PATH=${AROS_LINKLIB_MODULE_PATH}
            -DLINKLIB_MMAKEFILE=${_aros_mmakefile_src}
            -DLINKLIB_MMAKE_NAME=${_aros_linklib_MMAKE_NAME}
            -DLINKLIB_NAME=${_aros_linklib_LIBNAME}
            -DLINKLIB_OUTPUT=${_aros_linklib_output}
            -DLINKLIB_OBJ_DIR=${_aros_linklib_obj_dir}
            -P "${CMAKE_SOURCE_DIR}/cmake/build_mmake_linklib.cmake"
    DEPENDS
      "${_aros_linklib_include_stamp}"
      aros-configure
      aros-native-includes
      "${CMAKE_SOURCE_DIR}/cmake/build_mmake_linklib.cmake"
      "${_aros_mmakefile_src}"
      ${_aros_linklib_source_deps}
      ${AROS_LINKLIB_DEPENDS}
    COMMENT "Building native CMake ${_aros_linklib_LIBNAME} linklib"
    VERBATIM
  )

  add_custom_target("${target_name}-includes" DEPENDS "${_aros_linklib_include_stamp}")
  add_custom_target("${target_name}" DEPENDS "${_aros_linklib_output}")
  if(_aros_linklib_source_interface_modules)
    set_target_properties(
      "${target_name}"
      PROPERTIES
        AROS_SOURCE_INTERFACE_MODULES "${_aros_linklib_source_interface_modules}"
    )
  endif()
  get_property(_aros_registered_linklib_targets GLOBAL PROPERTY AROS_REGISTERED_LINKLIB_TARGETS)
  list(APPEND _aros_registered_linklib_targets "${target_name}")
  list(REMOVE_DUPLICATES _aros_registered_linklib_targets)
  set_property(GLOBAL PROPERTY AROS_REGISTERED_LINKLIB_TARGETS "${_aros_registered_linklib_targets}")
  _aros_sanitize_property_key("${_aros_linklib_LIBNAME}" _aros_linklib_name_key)
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_LINKLIB_OUTPUT_${_aros_linklib_name_key}"
    "${_aros_linklib_output}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_LINKLIB_TARGET_${_aros_linklib_name_key}"
    "${target_name}"
  )
  if(TARGET aros-sdk-interfaces-native)
    add_dependencies("${target_name}" aros-sdk-interfaces-native)
  endif()
  set(${target_name}_OUTPUT "${_aros_linklib_output}" PARENT_SCOPE)
endfunction()

function(aros_finalize_module_interfaces)
  get_property(_aros_registered_interface_targets GLOBAL PROPERTY AROS_REGISTERED_MODULE_INTERFACE_TARGETS)
  foreach(_aros_interface_target IN LISTS _aros_registered_interface_targets)
    if(NOT TARGET "${_aros_interface_target}")
      continue()
    endif()

    get_target_property(_aros_interface_dep_nodes "${_aros_interface_target}" AROS_MODULE_INTERFACE_DEPENDS)
    if(NOT _aros_interface_dep_nodes OR _aros_interface_dep_nodes STREQUAL "_aros_interface_dep_nodes-NOTFOUND")
      continue()
    endif()

    set(_aros_interface_dep_targets)
    foreach(_aros_dep_node IN LISTS _aros_interface_dep_nodes)
      _aros_sanitize_property_key("${_aros_dep_node}" _aros_dep_key)
      get_property(_aros_dep_target GLOBAL PROPERTY "AROS_MODULE_INTERFACE_TARGET_${_aros_dep_key}")
      if(NOT _aros_dep_target OR _aros_dep_target STREQUAL "${_aros_interface_target}")
        continue()
      endif()
      if(TARGET "${_aros_dep_target}")
        list(APPEND _aros_interface_dep_targets "${_aros_dep_target}")
      endif()
    endforeach()

    list(REMOVE_DUPLICATES _aros_interface_dep_targets)
    if(_aros_interface_dep_targets)
      target_link_libraries("${_aros_interface_target}" INTERFACE ${_aros_interface_dep_targets})
      add_dependencies("${_aros_interface_target}" ${_aros_interface_dep_targets})
    endif()

  endforeach()

  get_property(_aros_registered_linklib_targets GLOBAL PROPERTY AROS_REGISTERED_LINKLIB_TARGETS)
  foreach(_aros_linklib_target IN LISTS _aros_registered_linklib_targets)
    if(NOT TARGET "${_aros_linklib_target}")
      continue()
    endif()

    get_target_property(_aros_source_interface_modules "${_aros_linklib_target}" AROS_SOURCE_INTERFACE_MODULES)
    if(NOT _aros_source_interface_modules OR _aros_source_interface_modules STREQUAL "_aros_source_interface_modules-NOTFOUND")
      continue()
    endif()

    set(_aros_linklib_dep_targets)
    foreach(_aros_source_module IN LISTS _aros_source_interface_modules)
      _aros_sanitize_property_key("${_aros_source_module}" _aros_source_key)
      get_property(_aros_dep_target GLOBAL PROPERTY "AROS_MODULE_NAME_INTERFACE_TARGET_${_aros_source_key}")
      if(_aros_dep_target AND TARGET "${_aros_dep_target}")
        list(APPEND _aros_linklib_dep_targets "${_aros_dep_target}")
      endif()
    endforeach()

    list(REMOVE_DUPLICATES _aros_linklib_dep_targets)
    if(_aros_linklib_dep_targets)
      add_dependencies("${_aros_linklib_target}" ${_aros_linklib_dep_targets})
    endif()
  endforeach()
endfunction()
