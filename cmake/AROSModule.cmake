include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/AROSLayering.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/AROSMmakeFunctions.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/AROSNativeConfig.cmake")

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

function(_aros_make_dotted_identifier input_value out_var)
  string(REPLACE "/" "." _dotted "${input_value}")
  set(${out_var} "${_dotted}" PARENT_SCOPE)
endfunction()

function(_aros_compute_target_folders module_path out_public_var out_internal_var)
  set(${out_public_var} "aros/${module_path}" PARENT_SCOPE)
  set(${out_internal_var} "aros/internal/${module_path}" PARENT_SCOPE)
endfunction()

function(_aros_set_target_folder_if_exists target_name folder_name)
  if(TARGET "${target_name}" AND NOT "${folder_name}" STREQUAL "")
    set_target_properties("${target_name}" PROPERTIES FOLDER "${folder_name}")
  endif()
endfunction()

function(_aros_resolve_public_alias_name property_prefix preferred_name owner_id fallback_name out_var)
  set(_candidate "${preferred_name}")
  _aros_sanitize_property_key("${_candidate}" _candidate_key)
  get_property(_existing_owner GLOBAL PROPERTY "${property_prefix}_${_candidate_key}")
  if(TARGET "${_candidate}" AND NOT _existing_owner STREQUAL "${owner_id}")
    set(_candidate "${fallback_name}")
    _aros_sanitize_property_key("${_candidate}" _candidate_key)
    get_property(_existing_owner GLOBAL PROPERTY "${property_prefix}_${_candidate_key}")
  endif()

  if(TARGET "${_candidate}" AND NOT _existing_owner STREQUAL "${owner_id}")
    message(FATAL_ERROR "Public alias target collision for ${owner_id}: ${_candidate}")
  endif()

  set(${out_var} "${_candidate}" PARENT_SCOPE)
endfunction()

function(
  _aros_register_public_module_aliases
  module_path
  module_name
  module_type
  owner_target
  interfaces_build_target
  interface_target
  output_path
  public_linklib_output
)
  _aros_compute_target_folders("${module_path}" _public_folder _internal_folder)
  _aros_make_dotted_identifier("${module_path}" _module_dotted_path)

  _aros_resolve_public_alias_name(
    "AROS_PUBLIC_MODULE_INTERFACE_ALIAS_OWNER"
    "${module_name}"
    "${module_path}"
    "${_module_dotted_path}"
    _public_interface_target
  )
  if(NOT TARGET "${_public_interface_target}")
    add_library("${_public_interface_target}" INTERFACE)
  endif()
  target_link_libraries("${_public_interface_target}" INTERFACE "${interface_target}")
  add_dependencies("${_public_interface_target}" "${interfaces_build_target}")
  _aros_set_target_folder_if_exists("${_public_interface_target}" "${_public_folder}")

  get_target_property(_public_interface_include_dirs "${interface_target}" AROS_MODULE_INTERFACE_INCLUDE_DIRS)
  if(_public_interface_include_dirs AND NOT _public_interface_include_dirs STREQUAL "AROS_MODULE_INTERFACE_INCLUDE_DIRS-NOTFOUND")
    set_target_properties(
      "${_public_interface_target}"
      PROPERTIES
        AROS_MODULE_INTERFACE_INCLUDE_DIRS "${_public_interface_include_dirs}"
    )
  endif()
  get_target_property(_public_interface_stamp "${interface_target}" AROS_MODULE_INTERFACE_STAMP)
  if(_public_interface_stamp AND NOT _public_interface_stamp STREQUAL "AROS_MODULE_INTERFACE_STAMP-NOTFOUND")
    set_target_properties(
      "${_public_interface_target}"
      PROPERTIES
        AROS_MODULE_INTERFACE_STAMP "${_public_interface_stamp}"
    )
  endif()
  if(public_linklib_output AND NOT "${public_linklib_output}" STREQUAL "")
    set_target_properties(
      "${_public_interface_target}"
      PROPERTIES
        AROS_LINKLIB_OUTPUT "${public_linklib_output}"
        AROS_LINKLIB_OWNER_TARGET "${owner_target}"
    )
    add_dependencies("${_public_interface_target}" "${owner_target}")
  endif()

  _aros_sanitize_property_key("${_public_interface_target}" _public_interface_key)
  set_property(GLOBAL PROPERTY "AROS_PUBLIC_MODULE_INTERFACE_ALIAS_OWNER_${_public_interface_key}" "${module_path}")
  _aros_sanitize_property_key("${module_path}" _module_path_key)
  set_property(GLOBAL PROPERTY "AROS_PUBLIC_MODULE_INTERFACE_TARGET_${_module_path_key}" "${_public_interface_target}")

  set(_preferred_artifact_target "${module_name}.${module_type}")
  set(_fallback_artifact_target "${_module_dotted_path}.${module_type}")
  _aros_resolve_public_alias_name(
    "AROS_PUBLIC_MODULE_ARTIFACT_ALIAS_OWNER"
    "${_preferred_artifact_target}"
    "${module_path}"
    "${_fallback_artifact_target}"
    _public_artifact_target
  )
  if(NOT TARGET "${_public_artifact_target}")
    add_custom_target("${_public_artifact_target}")
  endif()
  add_dependencies("${_public_artifact_target}" "${owner_target}")
  set_target_properties(
    "${_public_artifact_target}"
    PROPERTIES
      AROS_MODULE_OUTPUT "${output_path}"
  )
  _aros_set_target_folder_if_exists("${_public_artifact_target}" "${_public_folder}")

  _aros_sanitize_property_key("${_public_artifact_target}" _public_artifact_key)
  set_property(GLOBAL PROPERTY "AROS_PUBLIC_MODULE_ARTIFACT_ALIAS_OWNER_${_public_artifact_key}" "${module_path}")
  set_property(GLOBAL PROPERTY "AROS_PUBLIC_MODULE_ARTIFACT_TARGET_${_module_path_key}" "${_public_artifact_target}")
endfunction()

function(_aros_register_public_linklib_alias module_path libname owner_target output_path)
  _aros_compute_target_folders("${module_path}" _public_folder _internal_folder)
  _aros_make_dotted_identifier("${module_path}" _module_dotted_path)
  _aros_sanitize_property_key("${module_path}" _module_path_key)
  get_property(_public_interface_target GLOBAL PROPERTY "AROS_PUBLIC_MODULE_INTERFACE_TARGET_${_module_path_key}")
  if(_public_interface_target AND TARGET "${_public_interface_target}")
    set(_public_linklib_target "${_public_interface_target}")
  else()
    _aros_resolve_public_alias_name(
      "AROS_PUBLIC_LINKLIB_ALIAS_OWNER"
      "${libname}"
      "${module_path}"
      "${_module_dotted_path}"
      _public_linklib_target
    )

    if(NOT TARGET "${_public_linklib_target}")
      add_custom_target("${_public_linklib_target}")
    endif()
  endif()

  add_dependencies("${_public_linklib_target}" "${owner_target}")
  set_target_properties(
    "${_public_linklib_target}"
    PROPERTIES
      AROS_LINKLIB_OUTPUT "${output_path}"
      AROS_LINKLIB_OWNER_TARGET "${owner_target}"
  )
  _aros_set_target_folder_if_exists("${_public_linklib_target}" "${_public_folder}")

  _aros_sanitize_property_key("${_public_linklib_target}" _public_linklib_key)
  set_property(GLOBAL PROPERTY "AROS_PUBLIC_LINKLIB_ALIAS_OWNER_${_public_linklib_key}" "${module_path}")
  set_property(GLOBAL PROPERTY "AROS_PUBLIC_LINKLIB_TARGET_${_module_path_key}" "${_public_linklib_target}")
endfunction()

function(_aros_get_linklib_output_dir_for_sdk sdk_name out_var)
  if("${sdk_name}" STREQUAL "" OR "${sdk_name}" STREQUAL "public")
    set(_output_dir "${AROS_NATIVE_PUBLIC_LIB_DIR}")
  elseif("${sdk_name}" STREQUAL "private")
    set(_output_dir "${AROS_NATIVE_PRIVATE_LIB_DIR}")
  else()
    set(_output_dir "${AROS_NATIVE_BUILD_SDKS_DIR}/${sdk_name}/lib")
  endif()

  set(${out_var} "${_output_dir}" PARENT_SCOPE)
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
  if(DEFINED AROS_TARGET_FAMILY AND NOT AROS_TARGET_FAMILY STREQUAL "")
    set(_family "${AROS_TARGET_FAMILY}")
  elseif(EXISTS "${_target_cfg}")
    file(STRINGS "${_target_cfg}" _family_line REGEX "^FAMILY[ \t]*:=")
    if(_family_line)
      string(REGEX REPLACE "^FAMILY[ \t]*:=[ \t]*" "" _family "${_family_line}")
      string(STRIP "${_family}" _family)
    else()
      set(_family "${_arch}")
    endif()
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
  set(_separator "")
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
      string(REPLACE ";" "\\;" _current "${_current}")
      string(APPEND _arguments "${_separator}${_current}")
      set(_separator ";")
      set(_current "")
    else()
      string(APPEND _current "${_char}")
    endif()

    math(EXPR _index "${_index} + 1")
  endwhile()

  string(STRIP "${_current}" _current)
  string(REPLACE ";" "\\;" _current "${_current}")
  string(APPEND _arguments "${_separator}${_current}")
  set(${out_var} "${_arguments}" PARENT_SCOPE)
endfunction()

function(_aros_set_make_context_for_file file_path)
  get_filename_component(_file_dir "${file_path}" DIRECTORY)
  if(IS_ABSOLUTE "${_file_dir}")
    file(RELATIVE_PATH _context_curdir "${CMAKE_SOURCE_DIR}" "${_file_dir}")
  else()
    set(_context_curdir "${_file_dir}")
  endif()

  if(_context_curdir MATCHES "^\\.\\.?(/|$)")
    if(ARGC GREATER 1 AND NOT "${ARGV1}" STREQUAL "")
      set(_context_curdir "${ARGV1}")
    else()
      set(_context_curdir "")
    endif()
  endif()

  set(_context_maindir "")
  if(ARGC GREATER 1 AND NOT "${ARGV1}" STREQUAL "")
    set(_context_maindir "${ARGV1}")
  else()
    set(_context_maindir "${_context_curdir}")
  endif()

  set(_AROS_MMAKE_CONTEXT_CURDIR "${_context_curdir}" PARENT_SCOPE)
  set(_AROS_MMAKE_CONTEXT_MAINDIR "${_context_maindir}" PARENT_SCOPE)
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
      if(_foreach_list_expanded MATCHES "\\$|@[^@ \t]+@")
        # An immediate assignment must not re-evaluate this list after a
        # later assignment happens to make its variables known.
        set(${out_var} "${_foreach_prefix}$<unresolved-foreach-list>${_foreach_suffix}" PARENT_SCOPE)
        return()
      endif()
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

    # Bind foreach variables before evaluating functions in their bodies.
    # Filesystem-aware consumers opt in; other metadata readers stay pure.
    if(_AROS_MMAKE_CALL_EXPANDER)
      cmake_language(CALL "${_AROS_MMAKE_CALL_EXPANDER}" "${_expanded}" _expanded _call_function)
      if(_call_function)
        continue()
      endif()
    endif()
    _aros_expand_make_word_function("${_expanded}" _expanded _word_function)
    if(_word_function)
      continue()
    endif()

    string(REGEX MATCH "\\$\\(([A-Za-z0-9_-]+)\\)" _match "${_expanded}")
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
      if(DEFINED _AROS_MMAKE_CONTEXT_CURDIR AND NOT _AROS_MMAKE_CONTEXT_CURDIR STREQUAL "")
        set(_replacement "${_AROS_MMAKE_CONTEXT_CURDIR}")
      else()
        set(_replacement "")
      endif()
    elseif(_var_name STREQUAL "MAINDIR")
      if(DEFINED _AROS_MMAKE_CONTEXT_MAINDIR AND NOT _AROS_MMAKE_CONTEXT_MAINDIR STREQUAL "")
        set(_replacement "${_AROS_MMAKE_CONTEXT_MAINDIR}")
      else()
        set(_replacement "")
      endif()
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
  _aros_native_config_value("${variable_name}" _value _found)
  if(_found)
    set(${out_var} "${_value}" PARENT_SCOPE)
    return()
  endif()
  # A conditional default may test the variable it is about to define. At
  # that point there is no earlier config assignment to resolve recursively.
  if(variable_name IN_LIST _aros_config_read_stack)
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()
  list(APPEND _aros_config_read_stack "${variable_name}")
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

    file(STRINGS "${_config_file}" _value_lines REGEX "^[ \t]*${variable_name}[ \t]*:?=")
    if(NOT _value_lines)
      continue()
    endif()
    # The same config values are queried for hundreds of modules. Cache only
    # syntax, not expanded values (which depend on the caller's make context).
    file(SHA256 "${_config_file}" _config_hash)
    get_property(_config_lines GLOBAL PROPERTY "AROS_CONFIG_LINES_${_config_hash}")
    if(NOT _config_lines)
      _aros_read_mmake_logical_lines("${_config_file}" _config_lines)
      set_property(GLOBAL PROPERTY "AROS_CONFIG_LINES_${_config_hash}" "${_config_lines}")
    endif()
    set(_conditions)
    foreach(_line IN LISTS _config_lines)
      if(_line MATCHES "^ifn?eq[ \t]*\\(.*\\)$")
        list(APPEND _conditions "${_line}")
      elseif(_line STREQUAL "else")
        list(POP_BACK _conditions _condition)
        list(APPEND _conditions "!${_condition}")
      elseif(_line STREQUAL "endif")
        list(POP_BACK _conditions)
      elseif(_line MATCHES "^${variable_name}[ \t]*:?=[ \t]*(.*)$")
        set(_value "${CMAKE_MATCH_1}")
        set(_active TRUE)
        # Evaluate only the conditions enclosing this assignment. An unrelated
        # earlier condition may itself query the value we are looking up.
        foreach(_condition IN LISTS _conditions)
          if(_condition MATCHES "^!(.*)$")
            _aros_evaluate_mmake_condition("${CMAKE_MATCH_1}" _condition_active)
            if(_condition_active)
              set(_condition_active FALSE)
            else()
              set(_condition_active TRUE)
            endif()
          else()
            _aros_evaluate_mmake_condition("${_condition}" _condition_active)
          endif()
          if(NOT _condition_active)
            set(_active FALSE)
            break()
          endif()
        endforeach()
        if(_active)
          _aros_unwrap_strip_expression("${_value}" _value)
          set(${out_var} "${_value}" PARENT_SCOPE)
          return()
        endif()
      endif()
    endforeach()
  endforeach()

  # START LEGACY: configure still exports a few configuration values only in
  # its top-level Makefile (icon set, GUI theme, bootloader). Read assignments,
  # never recipes, until the native configuration snapshot owns those values.
  if(EXISTS "${AROS_LEGACY_BUILD_DIR}/Makefile")
    file(STRINGS "${AROS_LEGACY_BUILD_DIR}/Makefile" _exports
      REGEX "^export[ \t]+${variable_name}[ \t]*:?=")
    if(_exports)
      list(GET _exports -1 _export)
      string(REGEX REPLACE "^export[ \t]+${variable_name}[ \t]*:?=[ \t]*" "" _value "${_export}")
      set(${out_var} "${_value}" PARENT_SCOPE)
      return()
    endif()
  endif()
  # END LEGACY
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

function(_aros_condition_stack_is_active condition_stack out_var)
  set(_active TRUE)
  foreach(_condition IN LISTS condition_stack)
    if(NOT _condition)
      set(_active FALSE)
      break()
    endif()
  endforeach()
  set(${out_var} "${_active}" PARENT_SCOPE)
endfunction()

function(_aros_evaluate_mmake_condition line out_var)
  _aros_evaluate_make_equality("${line}" _active)
  set(${out_var} "${_active}" PARENT_SCOPE)
endfunction()

function(_aros_tokenize_mmake_value input_value out_var)
  if("${input_value}" STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  separate_arguments(_tokens NATIVE_COMMAND "${input_value}")
  _aros_remove_empty_entries(_tokens)
  _aros_remove_token_entries(_tokens "\\")
  set(${out_var} "${_tokens}" PARENT_SCOPE)
endfunction()

function(_aros_resolve_make_include_path input_path out_var)
  if("${input_path}" STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  if(IS_ABSOLUTE "${input_path}")
    set(_resolved_path "${input_path}")
  else()
    if(DEFINED _AROS_MMAKE_CONTEXT_CURDIR AND NOT _AROS_MMAKE_CONTEXT_CURDIR STREQUAL "")
      set(_base_dir "${CMAKE_SOURCE_DIR}/${_AROS_MMAKE_CONTEXT_CURDIR}")
    else()
      set(_base_dir "${CMAKE_SOURCE_DIR}")
    endif()
    get_filename_component(_resolved_path "${input_path}" ABSOLUTE BASE_DIR "${_base_dir}")
  endif()

  set(${out_var} "${_resolved_path}" PARENT_SCOPE)
endfunction()

function(_aros_extract_include_dirs_from_tokens input_tokens out_var)
  set(_include_dirs)
  set(_pending_flag "")

  foreach(_token IN LISTS input_tokens)
    if(NOT _pending_flag STREQUAL "")
      _aros_resolve_make_include_path("${_token}" _resolved_include_dir)
      if(NOT _resolved_include_dir STREQUAL "")
        list(APPEND _include_dirs "${_resolved_include_dir}")
      endif()
      set(_pending_flag "")
      continue()
    endif()

    if(_token MATCHES "^(-I|-iquote|-isystem|-idirafter)(.+)$")
      _aros_resolve_make_include_path("${CMAKE_MATCH_2}" _resolved_include_dir)
      if(NOT _resolved_include_dir STREQUAL "")
        list(APPEND _include_dirs "${_resolved_include_dir}")
      endif()
    elseif(_token STREQUAL "-I"
           OR _token STREQUAL "-iquote"
           OR _token STREQUAL "-isystem"
           OR _token STREQUAL "-idirafter")
      set(_pending_flag "${_token}")
    endif()
  endforeach()

  list(REMOVE_DUPLICATES _include_dirs)
  set(${out_var} "${_include_dirs}" PARENT_SCOPE)
endfunction()

function(_aros_collect_archincludes maindir modname out_var)
  get_filename_component(_module_dir_name "${maindir}" NAME)

  set(_archinclude_mmakefiles)
  set(_module_mmakefile "${CMAKE_SOURCE_DIR}/${maindir}/mmakefile.src")
  if(EXISTS "${_module_mmakefile}")
    aros_layering_extract_primary_mmake_name("${_module_mmakefile}" _archinclude_mmake_name)
    if(NOT _archinclude_mmake_name STREQUAL "")
      aros_layering_collect_resolved_module_layer_mmakefiles(
        "${_module_dir_name}"
        "${_archinclude_mmake_name}"
        _archinclude_mmakefiles
        _archinclude_layers
        _archinclude_aliases
      )
    endif()
  endif()

  if(NOT _archinclude_mmakefiles)
    _aros_collect_active_module_layer_mmakefiles("${_module_dir_name}" _archinclude_mmakefiles)
  endif()

  set(_archinclude_entries)
  foreach(_mmakefile_path IN LISTS _archinclude_mmakefiles)
    if(NOT EXISTS "${_mmakefile_path}")
      continue()
    endif()

    _aros_set_make_context_for_file("${_mmakefile_path}" "${maindir}")
    _aros_read_mmake_logical_lines("${_mmakefile_path}" _logical_lines)
    set(_condition_stack)
    foreach(_line IN LISTS _logical_lines)
      if(_line MATCHES "^#")
        continue()
      endif()
      if(_line MATCHES "^ifn?eq[ \t]*\\(.*\\)$")
        _aros_evaluate_mmake_condition("${_line}" _condition_value)
        list(APPEND _condition_stack "${_condition_value}")
        continue()
      elseif(_line STREQUAL "else")
        list(LENGTH _condition_stack _condition_len)
        if(_condition_len GREATER 0)
          math(EXPR _last_index "${_condition_len} - 1")
          list(GET _condition_stack "${_last_index}" _last_value)
          if(_last_value)
            set(_new_value FALSE)
          else()
            set(_new_value TRUE)
          endif()
          list(REMOVE_AT _condition_stack "${_last_index}")
          list(APPEND _condition_stack "${_new_value}")
        endif()
        continue()
      elseif(_line STREQUAL "endif")
        list(LENGTH _condition_stack _condition_len)
        if(_condition_len GREATER 0)
          math(EXPR _last_index "${_condition_len} - 1")
          list(REMOVE_AT _condition_stack "${_last_index}")
        endif()
        continue()
      endif()

      _aros_condition_stack_is_active("${_condition_stack}" _condition_active)
      if(NOT _condition_active OR NOT _line MATCHES "^%set_archincludes[ \t]+(.*)$")
        continue()
      endif()

      _aros_expand_make_tokens("${CMAKE_MATCH_1}" _expanded_args)
      separate_arguments(_arg_tokens NATIVE_COMMAND "${_expanded_args}")

      set(_entry_modname "")
      set(_entry_maindir "")
      set(_entry_pri "999")
      set(_entry_includes "")
      set(_pending_key "")

      foreach(_arg_token IN LISTS _arg_tokens)
        if(NOT _arg_token MATCHES "^([^=]+)=(.*)$")
          if(NOT _pending_key STREQUAL "")
            set(_pending_var "_entry_${_pending_key}")
            if("${${_pending_var}}" STREQUAL "")
              set(${_pending_var} "${_arg_token}")
            else()
              string(APPEND ${_pending_var} " ${_arg_token}")
            endif()
          endif()
          continue()
        endif()

        set(_arg_key "${CMAKE_MATCH_1}")
        set(_arg_value "${CMAKE_MATCH_2}")
        if(_arg_key STREQUAL "modname")
          set(_pending_key "")
          set(_entry_modname "${_arg_value}")
        elseif(_arg_key STREQUAL "maindir")
          set(_pending_key "")
          set(_entry_maindir "${_arg_value}")
        elseif(_arg_key STREQUAL "pri")
          set(_pending_key "")
          set(_entry_pri "${_arg_value}")
        elseif(_arg_key STREQUAL "includes")
          set(_pending_key "includes")
          set(_entry_includes "${_arg_value}")
        else()
          set(_pending_key "")
        endif()
      endforeach()

      if(NOT _entry_modname STREQUAL "${modname}" OR NOT _entry_maindir STREQUAL "${maindir}")
        continue()
      endif()

      set(_entry_pri_padded "${_entry_pri}")
      string(REGEX REPLACE "^([0-9])$" "00\\1" _entry_pri_padded "${_entry_pri_padded}")
      string(REGEX REPLACE "^([0-9][0-9])$" "0\\1" _entry_pri_padded "${_entry_pri_padded}")
      string(REPLACE ";" "\\;" _entry_includes "${_entry_includes}")
      list(APPEND _archinclude_entries "${_entry_pri_padded}|${_entry_includes}")
    endforeach()
  endforeach()

  list(SORT _archinclude_entries)

  set(_collected_includes)
  foreach(_entry IN LISTS _archinclude_entries)
    string(REGEX REPLACE "^[0-9][0-9][0-9]\\|" "" _entry_includes "${_entry}")
    _aros_tokenize_mmake_value("${_entry_includes}" _entry_include_tokens)
    list(APPEND _collected_includes ${_entry_include_tokens})
  endforeach()

  set(${out_var} "${_collected_includes}" PARENT_SCOPE)
endfunction()

function(_aros_collect_make_variable_from_file file_path variable_name out_var)
  if(NOT EXISTS "${file_path}")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  set(_maindir "")
  if(ARGC GREATER 3)
    set(_maindir "${ARGV3}")
  endif()

  _aros_set_make_context_for_file("${file_path}" "${_maindir}")
  _aros_read_mmake_logical_lines("${file_path}" _logical_lines)

  set(_values)
  set(_condition_stack)
  foreach(_line IN LISTS _logical_lines)
    if(_line MATCHES "^[ \t;]*#")
      continue()
    endif()
    if(_line MATCHES "^ifn?eq[ \t]*\\(.*\\)$")
      _aros_evaluate_mmake_condition("${_line}" _condition_value)
      list(APPEND _condition_stack "${_condition_value}")
      continue()
    elseif(_line STREQUAL "else")
      list(LENGTH _condition_stack _condition_len)
      if(_condition_len GREATER 0)
        math(EXPR _last_index "${_condition_len} - 1")
        list(GET _condition_stack "${_last_index}" _last_value)
        if(_last_value)
          set(_new_value FALSE)
        else()
          set(_new_value TRUE)
        endif()
        list(REMOVE_AT _condition_stack "${_last_index}")
        list(APPEND _condition_stack "${_new_value}")
      endif()
      continue()
    elseif(_line STREQUAL "endif")
      list(LENGTH _condition_stack _condition_len)
      if(_condition_len GREATER 0)
        math(EXPR _last_index "${_condition_len} - 1")
        list(REMOVE_AT _condition_stack "${_last_index}")
      endif()
      continue()
    endif()

    _aros_condition_stack_is_active("${_condition_stack}" _condition_active)
    if(NOT _condition_active)
      continue()
    endif()

    if(_line MATCHES "^([A-Za-z0-9_]+)[ \t]*(\\+=|:?=)[ \t]*(.*)$")
      set(_assign_name "${CMAKE_MATCH_1}")
      set(_assign_mode "${CMAKE_MATCH_2}")
      set(_value "${CMAKE_MATCH_3}")
      _aros_expand_make_tokens("${_value}" _expanded_value)
      _aros_tokenize_mmake_value("${_expanded_value}" _expanded_tokens)

      if(_assign_mode STREQUAL "+=" AND DEFINED _AROS_MMAKE_VAR_${_assign_name})
        set(_AROS_MMAKE_VAR_${_assign_name} "${_AROS_MMAKE_VAR_${_assign_name}} ${_expanded_value}")
      elseif(_assign_mode STREQUAL "?=")
        if(NOT DEFINED _AROS_MMAKE_VAR_${_assign_name} OR "${_AROS_MMAKE_VAR_${_assign_name}}" STREQUAL "")
          set(_AROS_MMAKE_VAR_${_assign_name} "${_expanded_value}")
        endif()
      else()
        set(_AROS_MMAKE_VAR_${_assign_name} "${_expanded_value}")
      endif()

      if(NOT _assign_name STREQUAL "${variable_name}")
        continue()
      endif()

      if(_assign_mode STREQUAL "+=")
        list(APPEND _values ${_expanded_tokens})
      else()
        set(_values ${_expanded_tokens})
      endif()
      continue()
    endif()

    if(variable_name STREQUAL "USER_INCLUDES" AND _line MATCHES "^%get_archincludes[ \t]+(.*)$")
      _aros_expand_make_tokens("${CMAKE_MATCH_1}" _expanded_args)
      separate_arguments(_arg_tokens NATIVE_COMMAND "${_expanded_args}")

      set(_archinclude_modname "")
      set(_archinclude_maindir "")
      set(_archinclude_flag "USER_INCLUDES")
      foreach(_arg_token IN LISTS _arg_tokens)
        if(NOT _arg_token MATCHES "^([^=]+)=(.*)$")
          continue()
        endif()
        set(_arg_key "${CMAKE_MATCH_1}")
        set(_arg_value "${CMAKE_MATCH_2}")
        if(_arg_key STREQUAL "modname")
          set(_archinclude_modname "${_arg_value}")
        elseif(_arg_key STREQUAL "maindir")
          set(_archinclude_maindir "${_arg_value}")
        elseif(_arg_key STREQUAL "includeflag")
          set(_archinclude_flag "${_arg_value}")
        endif()
      endforeach()

      if(_archinclude_flag STREQUAL "${variable_name}" AND _archinclude_modname AND _archinclude_maindir)
        _aros_collect_archincludes("${_archinclude_maindir}" "${_archinclude_modname}" _resolved_archincludes)
        list(APPEND _values ${_resolved_archincludes})
      endif()
    endif()
  endforeach()

  _aros_remove_empty_entries(_values)
  _aros_remove_token_entries(_values "\\")
  set(${out_var} "${_values}" PARENT_SCOPE)
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

    if(NOT _registered_output AND _lib_name MATCHES "^(.+)_rel$")
      _aros_sanitize_property_key("${CMAKE_MATCH_1}" _aros_module_name_key)
      get_property(
        _registered_interface_target
        GLOBAL
        PROPERTY "AROS_MODULE_NAME_INTERFACE_TARGET_${_aros_module_name_key}"
      )
      if(_registered_interface_target AND TARGET "${_registered_interface_target}")
        get_target_property(
          _registered_output
          "${_registered_interface_target}"
          AROS_MODULE_REL_LINKLIB_OUTPUT
        )
        if(_registered_output STREQUAL "AROS_MODULE_REL_LINKLIB_OUTPUT-NOTFOUND")
          set(_registered_output "")
        endif()
        set(_registered_target "${_registered_interface_target}")
        set(_registered_output "")
      endif()
    endif()

    if(NOT _registered_output)
      get_property(
        _registered_interface_target
        GLOBAL
        PROPERTY "AROS_MODULE_NAME_INTERFACE_TARGET_${_aros_lib_key}"
      )
      if(_registered_interface_target AND TARGET "${_registered_interface_target}")
        get_target_property(
          _registered_output
          "${_registered_interface_target}"
          AROS_MODULE_PUBLIC_LINKLIB_OUTPUT
        )
        if(_registered_output STREQUAL "AROS_MODULE_PUBLIC_LINKLIB_OUTPUT-NOTFOUND")
          set(_registered_output "")
        endif()
        set(_registered_target "${_registered_interface_target}")
        set(_registered_output "")
      endif()
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

function(_aros_conf_has_option conf_path option_name out_var)
  if(NOT EXISTS "${conf_path}")
    set(${out_var} FALSE PARENT_SCOPE)
    return()
  endif()

  file(STRINGS "${conf_path}" _conf_option_lines REGEX "^[ \t]*options[ \t]+")
  set(_has_option FALSE)
  foreach(_conf_option_line IN LISTS _conf_option_lines)
    string(REGEX REPLACE "^[ \t]*options[ \t]+" "" _options_text "${_conf_option_line}")
    string(REPLACE "," ";" _options_list "${_options_text}")
    foreach(_option_entry IN LISTS _options_list)
      string(STRIP "${_option_entry}" _option_entry)
      if(_option_entry STREQUAL "${option_name}")
        set(_has_option TRUE)
        break()
      endif()
    endforeach()
    if(_has_option)
      break()
    endif()
  endforeach()

  set(${out_var} "${_has_option}" PARENT_SCOPE)
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
  # Keep physical newlines while splitting: file(STRINGS) folds backslash
  # continuations into semicolons, losing both #MM edges and shell separators.
  file(READ "${file_path}" _contents)
  string(REPLACE ";" "\\;" _contents "${_contents}")
  string(APPEND _contents "\n")
  string(REGEX MATCHALL "[^\n]*\n" _raw_lines "${_contents}")
  set(_logical_lines)
  set(_current "")

  foreach(_raw_line IN LISTS _raw_lines)
    string(REGEX REPLACE "[\r\n]+$" "" _line "${_raw_line}")
    string(STRIP "${_line}" _stripped_line)
    if(_current MATCHES "^#MM" AND _stripped_line MATCHES "^#MM[ \t]+")
      string(REGEX REPLACE "^#MM[ \t]+" "" _line "${_stripped_line}")
      set(_stripped_line "${_line}")
    endif()
    if(NOT "${_current}" STREQUAL "" AND "${_stripped_line}" MATCHES "^#")
      string(STRIP "${_current}" _current)
      string(REGEX REPLACE "([ \t]|;)+#.*$" "" _current "${_current}")
      string(STRIP "${_current}" _current)
      if(NOT "${_current}" STREQUAL "")
        string(REPLACE ";" "\\;" _current "${_current}")
        if(ARGV2 STREQUAL "PRESERVE_RECIPES" AND _recipe)
          string(PREPEND _current "\t")
        endif()
        list(APPEND _logical_lines "${_current}")
      endif()
      set(_current "")
      continue()
    endif()
    if("${_current}" STREQUAL "")
      set(_current "${_line}")
      set(_recipe FALSE)
      if(_line MATCHES "^\t")
        set(_recipe TRUE)
      endif()
    else()
      string(APPEND _current " " "${_line}")
    endif()

    if("${_current}" MATCHES "\\\\[ \t]*$")
      string(REGEX REPLACE "\\\\[ \t]*$" "" _current "${_current}")
      string(STRIP "${_current}" _current)
    else()
      string(STRIP "${_current}" _current)
      string(REGEX REPLACE "([ \t]|;)+#.*$" "" _current "${_current}")
      string(STRIP "${_current}" _current)
      if(NOT "${_current}" STREQUAL "")
        string(REPLACE ";" "\\;" _current "${_current}")
        if(ARGV2 STREQUAL "PRESERVE_RECIPES" AND _recipe)
          string(PREPEND _current "\t")
        endif()
        list(APPEND _logical_lines "${_current}")
      endif()
      set(_current "")
    endif()
  endforeach()

  if(NOT "${_current}" STREQUAL "")
    string(STRIP "${_current}" _current)
    string(REGEX REPLACE "([ \t]|;)+#.*$" "" _current "${_current}")
    string(STRIP "${_current}" _current)
    string(REPLACE ";" "\\;" _current "${_current}")
    if(ARGV2 STREQUAL "PRESERVE_RECIPES" AND _recipe)
      string(PREPEND _current "\t")
    endif()
    list(APPEND _logical_lines "${_current}")
  endif()

  set(${out_var} "${_logical_lines}" PARENT_SCOPE)
endfunction()

function(_aros_collect_include_interface_modules_from_files out_var)
  set(_source_scan_extensions
    ${_AROS_INCLUDE_SCAN_EXTRA_EXTENSIONS}
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

function(_aros_collect_include_virtual_paths_from_files out_var)
  set(_source_scan_extensions
    ${_AROS_INCLUDE_SCAN_EXTRA_EXTENSIONS}
    .c
    .cc
    .cpp
    .cxx
    .h
    .hpp
    .s
    .S
  )
  set(_collected_include_paths)

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
      REGEX "^[ \t]*#[ \t]*include[ \t]*<[^>]+>"
    )

    foreach(_include_line IN LISTS _include_lines)
      if(_include_line MATCHES "<([^>]+)>")
        list(APPEND _collected_include_paths "${CMAKE_MATCH_1}")
      endif()
    endforeach()
  endforeach()

  list(REMOVE_DUPLICATES _collected_include_paths)
  set(${out_var} "${_collected_include_paths}" PARENT_SCOPE)
endfunction()

function(_aros_collect_staged_copy_include_paths_from_mmake mmakefile_path module_path out_var)
  if(NOT EXISTS "${mmakefile_path}")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  get_filename_component(_mmake_dir "${mmakefile_path}" DIRECTORY)
  _aros_set_make_context_for_file("${mmakefile_path}" "${module_path}")
  _aros_read_mmake_logical_lines("${mmakefile_path}" _logical_lines)

  set(_condition_stack)
  set(_staged_include_paths)
  foreach(_line IN LISTS _logical_lines)
    if(_line MATCHES "^[ \t;]*#")
      continue()
    endif()

    if(_line MATCHES "^ifn?eq[ \t]*\\(.*\\)$")
      _aros_evaluate_mmake_condition("${_line}" _condition_value)
      list(APPEND _condition_stack "${_condition_value}")
      continue()
    elseif(_line STREQUAL "else")
      list(LENGTH _condition_stack _condition_len)
      if(_condition_len GREATER 0)
        math(EXPR _last_index "${_condition_len} - 1")
        list(GET _condition_stack "${_last_index}" _last_value)
        if(_last_value)
          set(_new_value FALSE)
        else()
          set(_new_value TRUE)
        endif()
        list(REMOVE_AT _condition_stack "${_last_index}")
        list(APPEND _condition_stack "${_new_value}")
      endif()
      continue()
    elseif(_line STREQUAL "endif")
      list(LENGTH _condition_stack _condition_len)
      if(_condition_len GREATER 0)
        math(EXPR _last_index "${_condition_len} - 1")
        list(REMOVE_AT _condition_stack "${_last_index}")
      endif()
      continue()
    endif()

    _aros_condition_stack_is_active("${_condition_stack}" _condition_active)
    if(NOT _condition_active)
      continue()
    endif()

    if(_line MATCHES "^([A-Za-z0-9_]+)[ \t]*(\\+=|:=|\\?=|=)[ \t]*(.*)$")
      set(_var_name "${CMAKE_MATCH_1}")
      set(_assign_mode "${CMAKE_MATCH_2}")
      set(_raw_value "${CMAKE_MATCH_3}")
      _aros_expand_make_tokens("${_raw_value}" _expanded_value)
      if(_assign_mode STREQUAL "+=" AND DEFINED _AROS_MMAKE_VAR_${_var_name})
        set(_AROS_MMAKE_VAR_${_var_name} "${_AROS_MMAKE_VAR_${_var_name}} ${_expanded_value}")
      elseif(_assign_mode STREQUAL "?=")
        if(NOT DEFINED _AROS_MMAKE_VAR_${_var_name} OR "${_AROS_MMAKE_VAR_${_var_name}}" STREQUAL "")
          set(_AROS_MMAKE_VAR_${_var_name} "${_expanded_value}")
        endif()
      else()
        set(_AROS_MMAKE_VAR_${_var_name} "${_expanded_value}")
      endif()
      continue()
    endif()

    if(NOT _line MATCHES "^%copy_includes([ \t]+(.*))?$")
      continue()
    endif()

    set(_copy_args_string "${CMAKE_MATCH_2}")
    _aros_expand_make_tokens("${_copy_args_string}" _copy_args_string)
    separate_arguments(_copy_args NATIVE_COMMAND "${_copy_args_string}")

    set(_copy_dir ".")
    set(_copy_path ".")
    set(_copy_includes "")
    foreach(_arg IN LISTS _copy_args)
      if(_arg MATCHES "^dir=(.*)$")
        set(_copy_dir "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^path=(.*)$")
        set(_copy_path "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^includes=(.*)$")
        set(_copy_includes "${CMAKE_MATCH_1}")
      endif()
    endforeach()

    if(IS_ABSOLUTE "${_copy_dir}")
      set(_source_root "${_copy_dir}")
    else()
      set(_source_root "${_mmake_dir}/${_copy_dir}")
    endif()

    if(_copy_path STREQUAL "." OR _copy_path STREQUAL "")
      set(_virtual_root "")
    else()
      set(_virtual_root "${_copy_path}")
    endif()

    if(_copy_includes STREQUAL "" AND DEFINED _AROS_MMAKE_VAR_INCLUDE_FILES)
      set(_copy_includes "${_AROS_MMAKE_VAR_INCLUDE_FILES}")
    endif()

    set(_resolved_copy_paths)
    if(NOT _copy_includes STREQUAL "")
      separate_arguments(_copy_include_entries NATIVE_COMMAND "${_copy_includes}")
      foreach(_include_entry IN LISTS _copy_include_entries)
        if(_include_entry STREQUAL "")
          continue()
        endif()

        set(_include_source "")
        if(IS_ABSOLUTE "${_include_entry}")
          set(_include_source "${_include_entry}")
        elseif(EXISTS "${_mmake_dir}/${_include_entry}")
          set(_include_source "${_mmake_dir}/${_include_entry}")
        elseif(EXISTS "${_source_root}/${_include_entry}")
          set(_include_source "${_source_root}/${_include_entry}")
        endif()

        if(_include_source STREQUAL "" OR IS_DIRECTORY "${_include_source}")
          continue()
        endif()

        file(RELATIVE_PATH _relative_include_path "${_source_root}" "${_include_source}")
        if(_virtual_root STREQUAL "")
          list(APPEND _resolved_copy_paths "${_relative_include_path}")
        else()
          list(APPEND _resolved_copy_paths "${_virtual_root}/${_relative_include_path}")
        endif()
      endforeach()
    endif()

    if(NOT _resolved_copy_paths)
      file(GLOB_RECURSE _copy_header_candidates
        RELATIVE "${_source_root}"
        "${_source_root}/*.h"
        "${_source_root}/*.hpp"
      )
      foreach(_relative_include_path IN LISTS _copy_header_candidates)
        if(_virtual_root STREQUAL "")
          list(APPEND _resolved_copy_paths "${_relative_include_path}")
        else()
          list(APPEND _resolved_copy_paths "${_virtual_root}/${_relative_include_path}")
        endif()
      endforeach()
    endif()

    list(APPEND _staged_include_paths ${_resolved_copy_paths})
  endforeach()

  list(REMOVE_DUPLICATES _staged_include_paths)
  set(${out_var} "${_staged_include_paths}" PARENT_SCOPE)
endfunction()

function(_aros_extract_mmake_build_module_metadata mmakefile_src module_path out_prefix)
  set(_options)
  set(_one_value_args
    MMAKE_NAME
  )
  cmake_parse_arguments(AROS_BUILD_MODULE "${_options}" "${_one_value_args}" "" ${ARGN})
  _aros_read_mmake_logical_lines("${mmakefile_src}" _logical_lines)

  set(_module_name "")
  set(_module_type "")
  set(_module_mmake "")
  set(_module_conf "")
  set(_module_suffix "")
  set(_module_runtime_dir "")
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
      set(_line_module_name "")
      set(_line_module_type "")
      set(_line_module_mmake "")
      set(_line_module_conf "")
      set(_line_module_suffix "")
      set(_line_module_runtime_dir "")
      set(_line_module_archspecific FALSE)
      set(_line_module_sdk "public")
      set(_line_module_link_libs)
      set(_line_module_use_sdks)
      foreach(_token IN LISTS _tokens)
        if(NOT _token MATCHES "^([^=]+)=(.*)$")
          continue()
        endif()
        set(_key "${CMAKE_MATCH_1}")
        set(_value "${CMAKE_MATCH_2}")
        _aros_expand_make_tokens("${_value}" _value)
        _aros_unwrap_strip_expression("${_value}" _value)
        if(_key STREQUAL "mmake")
          set(_line_module_mmake "${_value}")
        elseif(_key STREQUAL "modname")
          set(_line_module_name "${_value}")
        elseif(_key STREQUAL "modtype")
          set(_line_module_type "${_value}")
        elseif(_key STREQUAL "conffile")
          set(_line_module_conf "${_value}")
        elseif(_key STREQUAL "modsuffix")
          set(_line_module_suffix "${_value}")
        elseif(_key STREQUAL "moduledir")
          set(_line_module_runtime_dir "${_value}")
        elseif(_key STREQUAL "archspecific" AND _value STREQUAL "yes")
          set(_line_module_archspecific TRUE)
        elseif(_key STREQUAL "sdk")
          set(_line_module_sdk "${_value}")
        elseif(_key STREQUAL "uselibs")
          separate_arguments(_line_module_link_libs NATIVE_COMMAND "${_value}")
          _aros_remove_empty_entries(_line_module_link_libs)
          _aros_remove_token_entries(_line_module_link_libs "\\")
        elseif(_key STREQUAL "usesdks")
          separate_arguments(_line_module_use_sdks NATIVE_COMMAND "${_value}")
          _aros_remove_empty_entries(_line_module_use_sdks)
          _aros_remove_token_entries(_line_module_use_sdks "\\")
        endif()
      endforeach()
      if(AROS_BUILD_MODULE_MMAKE_NAME
         AND NOT _line_module_mmake STREQUAL "${AROS_BUILD_MODULE_MMAKE_NAME}")
        continue()
      endif()
      set(_module_name "${_line_module_name}")
      set(_module_type "${_line_module_type}")
      set(_module_mmake "${_line_module_mmake}")
      set(_module_conf "${_line_module_conf}")
      set(_module_suffix "${_line_module_suffix}")
      set(_module_runtime_dir "${_line_module_runtime_dir}")
      set(_module_archspecific "${_line_module_archspecific}")
      set(_module_sdk "${_line_module_sdk}")
      set(_module_link_libs ${_line_module_link_libs})
      set(_module_use_sdks ${_line_module_use_sdks})
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
  set(${out_prefix}_MODULE_RUNTIME_DIR "${_module_runtime_dir}" PARENT_SCOPE)
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
  if(ARGC GREATER 4 AND NOT "${ARGV4}" STREQUAL "")
    # build_module creates this interface even without an explicit #MM line.
    set(_preferred_name "${ARGV4}-includes")
  endif()

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

function(_aros_append_include_dirs list_var)
  set(_include_dirs "${${list_var}}")
  foreach(_include_dir IN LISTS ARGN)
    if(_include_dir STREQUAL "")
      continue()
    endif()
    list(APPEND _include_dirs "${_include_dir}")
  endforeach()
  list(REMOVE_DUPLICATES _include_dirs)
  set(${list_var} "${_include_dirs}" PARENT_SCOPE)
endfunction()

function(_aros_append_existing_include_dirs list_var)
  set(_existing_include_dirs)
  foreach(_include_dir IN LISTS ARGN)
    if(IS_DIRECTORY "${_include_dir}")
      list(APPEND _existing_include_dirs "${_include_dir}")
    endif()
  endforeach()
  _aros_append_include_dirs("${list_var}" ${_existing_include_dirs})
endfunction()

function(_aros_filter_interface_include_dirs list_var)
  set(_filtered_include_dirs)
  foreach(_include_dir IN LISTS ${list_var})
    if(_include_dir STREQUAL "")
      continue()
    endif()

    if(NOT IS_ABSOLUTE "${_include_dir}")
      list(APPEND _filtered_include_dirs "${_include_dir}")
      continue()
    endif()

    set(_keep_include_dir FALSE)
    foreach(_allowed_prefix IN ITEMS
        "${CMAKE_SOURCE_DIR}"
        "${CMAKE_BINARY_DIR}"
        "${AROS_CONFIG_BUILD_DIR}"
        "${AROS_LEGACY_BUILD_DIR}"
        "${AROS_NATIVE_INCLUDE_DIR}"
        "${AROS_NATIVE_BUILD_SDKS_DIR}")
      if(_allowed_prefix STREQUAL "")
        continue()
      endif()

      string(LENGTH "${_allowed_prefix}" _allowed_prefix_len)
      string(LENGTH "${_include_dir}" _include_dir_len)
      if(_include_dir_len LESS _allowed_prefix_len)
        continue()
      endif()

      string(SUBSTRING "${_include_dir}" 0 ${_allowed_prefix_len} _include_prefix)
      if(NOT _include_prefix STREQUAL "${_allowed_prefix}")
        continue()
      endif()

      if(_include_dir STREQUAL "${_allowed_prefix}")
        set(_keep_include_dir TRUE)
        break()
      endif()

      string(SUBSTRING "${_include_dir}" ${_allowed_prefix_len} 1 _include_suffix_char)
      if(_include_suffix_char STREQUAL "/")
        set(_keep_include_dir TRUE)
        break()
      endif()
    endforeach()

    if(_keep_include_dir)
      list(APPEND _filtered_include_dirs "${_include_dir}")
    endif()
  endforeach()

  list(REMOVE_DUPLICATES _filtered_include_dirs)
  set(${list_var} "${_filtered_include_dirs}" PARENT_SCOPE)
endfunction()

function(_aros_collect_module_layer_include_dirs module_path module_mmake_name out_var)
  get_filename_component(_module_dir_name "${module_path}" NAME)
  _aros_collect_active_module_layer_mmakefiles(
    "${_module_dir_name}"
    _layer_mmakefiles
    "${module_mmake_name}"
  )

  set(_include_dirs)
  foreach(_layer_mmakefile IN LISTS _layer_mmakefiles)
    get_filename_component(_layer_dir "${_layer_mmakefile}" DIRECTORY)
    list(APPEND _include_dirs "${_layer_dir}")
  endforeach()

  _aros_append_existing_include_dirs(_include_dirs ${_include_dirs})
  set(${out_var} "${_include_dirs}" PARENT_SCOPE)
endfunction()

function(_aros_collect_module_catalog_cd module_path out_var)
  set(_catalog_cd_files)
  foreach(_catalog_dir IN ITEMS catalogs Catalogs cat)
    file(GLOB _catalog_dir_cds
      LIST_DIRECTORIES FALSE
      "${CMAKE_SOURCE_DIR}/${module_path}/${_catalog_dir}/*.cd"
    )
    list(APPEND _catalog_cd_files ${_catalog_dir_cds})
  endforeach()
  list(REMOVE_DUPLICATES _catalog_cd_files)

  list(LENGTH _catalog_cd_files _catalog_cd_count)
  if(_catalog_cd_count EQUAL 1)
    list(GET _catalog_cd_files 0 _catalog_cd_file)
    set(${out_var} "${_catalog_cd_file}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

function(_aros_module_uses_local_strings_header out_var)
  set(_needs_local_strings_header FALSE)

  foreach(_module_source_file IN LISTS ARGN)
    if(IS_DIRECTORY "${_module_source_file}")
      continue()
    endif()
    if(NOT _module_source_file MATCHES "\\.(c|cc|cpp|cxx|h|hh|hpp|hxx|s|S)$")
      continue()
    endif()

    file(
      STRINGS
      "${_module_source_file}"
      _strings_header_include_lines
      REGEX "^[ \t]*#[ \t]*include[ \t]+\"strings\\.h\""
    )
    if(_strings_header_include_lines)
      set(_needs_local_strings_header TRUE)
      break()
    endif()
  endforeach()

  set(${out_var} "${_needs_local_strings_header}" PARENT_SCOPE)
endfunction()

function(_aros_register_module_local_strings_header module_path out_target out_include_dir)
  _aros_sanitize_property_key("${module_path}" _module_path_key)
  get_property(
    _existing_target
    GLOBAL
    PROPERTY "AROS_MODULE_LOCAL_STRINGS_HEADER_TARGET_${_module_path_key}"
  )
  get_property(
    _existing_include_dir
    GLOBAL
    PROPERTY "AROS_MODULE_LOCAL_STRINGS_HEADER_INCLUDE_DIR_${_module_path_key}"
  )
  if(_existing_target OR _existing_include_dir)
    set(${out_target} "${_existing_target}" PARENT_SCOPE)
    set(${out_include_dir} "${_existing_include_dir}" PARENT_SCOPE)
    return()
  endif()

  set(_module_source_deps ${ARGN})
  _aros_collect_module_catalog_cd("${module_path}" _catalog_cd_file)
  if(NOT _catalog_cd_file)
    set(${out_target} "" PARENT_SCOPE)
    set(${out_include_dir} "" PARENT_SCOPE)
    return()
  endif()

  _aros_module_uses_local_strings_header(_needs_local_strings_header ${_module_source_deps})
  if(NOT _needs_local_strings_header)
    set(${out_target} "" PARENT_SCOPE)
    set(${out_include_dir} "" PARENT_SCOPE)
    return()
  endif()

  string(REPLACE "/" "_" _module_id "${module_path}")
  string(REPLACE "/" "-" _module_target_id "${module_path}")
  set(_strings_header_dir "${CMAKE_BINARY_DIR}/modules/${_module_id}/generated")
  set(_strings_header_output "${_strings_header_dir}/strings.h")
  set(_strings_header_target "aros-${_module_target_id}-strings-header")

  aros_add_flexcat_header(
    "${_strings_header_target}"
    OUTPUT "${_strings_header_output}"
    CD_FILE "${_catalog_cd_file}"
    SOURCE_DESCRIPTION "${CMAKE_SOURCE_DIR}/tools/flexcat/src/sd/C_h_aros.sd"
  )

  _aros_compute_target_folders("${module_path}" _public_folder _internal_folder)
  _aros_set_target_folder_if_exists("${_strings_header_target}" "${_internal_folder}")

  set_property(
    GLOBAL
    PROPERTY "AROS_MODULE_LOCAL_STRINGS_HEADER_TARGET_${_module_path_key}"
    "${_strings_header_target}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_MODULE_LOCAL_STRINGS_HEADER_INCLUDE_DIR_${_module_path_key}"
    "${_strings_header_dir}"
  )

  set(${out_target} "${_strings_header_target}" PARENT_SCOPE)
  set(${out_include_dir} "${_strings_header_dir}" PARENT_SCOPE)
endfunction()

function(_aros_collect_module_interface_include_dirs module_path module_mmake_name module_sdk module_mmakefile out_var)
  string(REPLACE "/" "_" _module_id "${module_path}")
  get_filename_component(_module_dir_name "${module_path}" NAME)

  set(_include_dirs)
  _aros_collect_active_module_layer_mmakefiles(
    "${_module_dir_name}"
    _layer_mmakefiles
    "${module_mmake_name}"
  )
  _aros_collect_module_layer_include_dirs("${module_path}" "${module_mmake_name}" _layer_include_dirs)
  _aros_append_include_dirs(_include_dirs ${_layer_include_dirs})

  if(NOT module_mmakefile STREQUAL "")
    _aros_collect_make_variable_from_file("${module_mmakefile}" "USER_INCLUDES" _module_user_include_tokens "${module_path}")
    _aros_extract_include_dirs_from_tokens("${_module_user_include_tokens}" _module_user_include_dirs)
    _aros_append_include_dirs(_include_dirs ${_module_user_include_dirs})
  endif()

  foreach(_layer_mmakefile IN LISTS _layer_mmakefiles)
    _aros_collect_make_variable_from_file("${_layer_mmakefile}" "USER_INCLUDES" _layer_user_include_tokens "${module_path}")
    _aros_extract_include_dirs_from_tokens("${_layer_user_include_tokens}" _layer_user_include_dirs)
    _aros_append_include_dirs(_include_dirs ${_layer_user_include_dirs})

    get_filename_component(_layer_dir "${_layer_mmakefile}" DIRECTORY)
    _aros_collect_make_variable_from_file("${_layer_dir}/make.opts" "USER_INCLUDES" _layer_makeopts_include_tokens "${module_path}")
    _aros_extract_include_dirs_from_tokens("${_layer_makeopts_include_tokens}" _layer_makeopts_include_dirs)
    _aros_append_include_dirs(_include_dirs ${_layer_makeopts_include_dirs})
  endforeach()

  if(NOT module_sdk STREQUAL "" AND NOT module_sdk STREQUAL "public")
    _aros_append_include_dirs(
      _include_dirs
      "${AROS_NATIVE_BUILD_SDKS_DIR}/${module_sdk}/include"
      "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/${module_sdk}/include"
    )
  endif()

  _aros_append_include_dirs(
    _include_dirs
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/${module_path}/include"
    "${CMAKE_BINARY_DIR}/modules/${_module_id}/genmodule/include"
    "${AROS_NATIVE_INCLUDE_DIR}"
    "${CMAKE_SOURCE_DIR}/${module_path}"
  )
  _aros_filter_interface_include_dirs(_include_dirs)

  set(${out_var} "${_include_dirs}" PARENT_SCOPE)
endfunction()

function(aros_register_layered_module_sources_target target_name module_path)
  add_custom_target(
    "${target_name}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
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
    WORKING_DIRECTORY
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
            -DWORKING_DIRECTORY=${AROS_EMIT_WORKING_DIRECTORY}
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/emit_tool_stdout_to_file.cmake"
    DEPENDS
      "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/emit_tool_stdout_to_file.cmake"
      ${AROS_EMIT_DEPENDS}
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${AROS_EMIT_OUTPUT}")
endfunction()

function(aros_add_genmodule_exports target_name)
  set(_options)
  set(_one_value_args
    MODULE_PATH
    CONF_FILE
    MODULE_NAME
    MODULE_TYPE
  )
  set(_multi_value_args
    WRITEINCLUDES_DIRS
    WRITELIBDEFS_DIRS
    DEPENDS
  )
  cmake_parse_arguments(AROS_GENEXPORT "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_GENEXPORT_CONF_FILE
     OR NOT AROS_GENEXPORT_MODULE_NAME
     OR NOT AROS_GENEXPORT_MODULE_TYPE)
    message(FATAL_ERROR
      "aros_add_genmodule_exports requires CONF_FILE, MODULE_NAME, and MODULE_TYPE"
    )
  endif()

  if(NOT TARGET genmodule)
    message(FATAL_ERROR "aros_add_genmodule_exports requires the native genmodule target")
  endif()

  if(NOT AROS_GENEXPORT_WRITEINCLUDES_DIRS AND NOT AROS_GENEXPORT_WRITELIBDEFS_DIRS)
    message(FATAL_ERROR
      "aros_add_genmodule_exports requires WRITEINCLUDES_DIRS and/or WRITELIBDEFS_DIRS"
    )
  endif()

  if(AROS_GENEXPORT_MODULE_PATH)
    string(REPLACE "/" "_" _aros_genexport_module_id "${AROS_GENEXPORT_MODULE_PATH}")
  else()
    set(_aros_genexport_module_id "${target_name}")
  endif()
  set(_aros_genexport_stamp_dir "${CMAKE_BINARY_DIR}/modules/${_aros_genexport_module_id}/extras")
  set(_aros_genexport_stamp "${_aros_genexport_stamp_dir}/${target_name}.stamp")

  _aros_encode_list("${AROS_GENEXPORT_WRITEINCLUDES_DIRS}" _aros_genexport_writeincludes_dirs)
  _aros_encode_list("${AROS_GENEXPORT_WRITELIBDEFS_DIRS}" _aros_genexport_writelibdefs_dirs)

  add_custom_command(
    OUTPUT "${_aros_genexport_stamp}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_aros_genexport_stamp_dir}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_GENMODULE=$<TARGET_FILE:genmodule>
            -DMODULE_CONF=${AROS_GENEXPORT_CONF_FILE}
            -DMODULE_NAME=${AROS_GENEXPORT_MODULE_NAME}
            -DMODULE_TYPE=${AROS_GENEXPORT_MODULE_TYPE}
            -DWRITEINCLUDES_DIRS_ENCODED=${_aros_genexport_writeincludes_dirs}
            -DWRITELIBDEFS_DIRS_ENCODED=${_aros_genexport_writelibdefs_dirs}
            -DAROS_LIST_SEP=__AROS_LIST_SEP__
            -P "${CMAKE_SOURCE_DIR}/cmake/run_genmodule_exports.cmake"
    COMMAND "${CMAKE_COMMAND}" -E touch "${_aros_genexport_stamp}"
    DEPENDS
      genmodule
      "${AROS_GENEXPORT_CONF_FILE}"
      "${CMAKE_SOURCE_DIR}/cmake/run_genmodule_exports.cmake"
      ${AROS_GENEXPORT_DEPENDS}
    COMMENT "Generating extra genmodule exports for ${AROS_GENEXPORT_MODULE_NAME}.${AROS_GENEXPORT_MODULE_TYPE}"
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${_aros_genexport_stamp}")
endfunction()

function(aros_register_genmodule_module target_name)
  set(_options
    ARCHSPECIFIC
  )
  set(_one_value_args
    MODULE_PATH
    MODULE_RUNTIME_DIR
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
    SOURCE_INCLUDE_PATHS
    STAGED_INCLUDE_PATHS
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
    if(AROS_MODULE_MODULE_SUFFIX STREQUAL "handler")
      set(AROS_MODULE_MODULE_FILENAME_SEPARATOR "-")
    elseif(DEFINED _aros_default_separator)
      set(AROS_MODULE_MODULE_FILENAME_SEPARATOR "${_aros_default_separator}")
    else()
      set(AROS_MODULE_MODULE_FILENAME_SEPARATOR ".")
    endif()
  endif()
  if(NOT AROS_MODULE_MODULE_SUFFIX)
    set(AROS_MODULE_MODULE_SUFFIX "${AROS_MODULE_OUTPUT_SUFFIX}")
  endif()

  string(REPLACE "/" "_" _aros_module_id "${AROS_MODULE_MODULE_PATH}")
  set(_aros_module_registration_key
    "${AROS_MODULE_MODULE_PATH}:${AROS_MODULE_MODULE_NAME}:${AROS_MODULE_MODULE_TYPE}"
  )
  _aros_sanitize_property_key("${_aros_module_registration_key}" _aros_module_property_key)
  set(_aros_module_work_dir "${CMAKE_BINARY_DIR}/modules/${_aros_module_id}")
  set(_aros_module_generated_dir "${_aros_module_work_dir}/genmodule")
  set(_aros_module_obj_dir "${_aros_module_work_dir}/obj")
  set(_aros_module_link_manifest "${_aros_module_work_dir}/${AROS_MODULE_MODULE_NAME}.${AROS_MODULE_MODULE_TYPE}-link.cmake")
  set(_aros_module_kobj "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/gen/kobjs/${AROS_MODULE_MODULE_NAME}_${AROS_MODULE_MODULE_SUFFIX}.o")
  set(_aros_module_interface_stamp "${_aros_module_work_dir}/.${AROS_MODULE_MODULE_NAME}.${AROS_MODULE_MODULE_TYPE}-interfaces.stamp")
  set(_aros_module_interface_target "${target_name}-interface")
  set(_aros_module_native_abi_target "${target_name}-abi")
  _aros_compute_target_folders("${AROS_MODULE_MODULE_PATH}" _aros_module_public_folder _aros_module_internal_folder)
  string(REPLACE "-" ";" _aros_target_parts "${AROS_TARGET}")
  list(GET _aros_target_parts 0 _aros_target_arch)
  set(_aros_module_runtime_prefix "")
  if(AROS_MODULE_ARCHSPECIFIC)
    set(_aros_module_runtime_prefix "boot/${_aros_target_arch}/")
  endif()
  set(_aros_module_output_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/AROS/${_aros_module_runtime_prefix}${AROS_MODULE_OUTPUT_SUBDIR}")
  if(AROS_MODULE_MODULE_RUNTIME_DIR)
    if(IS_ABSOLUTE "${AROS_MODULE_MODULE_RUNTIME_DIR}" OR AROS_MODULE_MODULE_RUNTIME_DIR MATCHES "(^|/)\\.\\.(/|$)")
      message(FATAL_ERROR "Module runtime directory must be relative to the AROS tree: ${AROS_MODULE_MODULE_RUNTIME_DIR}")
    endif()
    set(_aros_module_output_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/AROS/${AROS_MODULE_MODULE_RUNTIME_DIR}")
  endif()
  set(_aros_module_output
    "${_aros_module_output_dir}/${AROS_MODULE_MODULE_NAME}${AROS_MODULE_MODULE_FILENAME_SEPARATOR}${AROS_MODULE_MODULE_SUFFIX}"
  )
  _aros_get_genmodule_public_linklib_output(
    "${AROS_MODULE_MODULE_NAME}"
    "${AROS_MODULE_MODULE_TYPE}"
    "${AROS_MODULE_MODULE_SUFFIX}"
    _aros_module_public_linklib_output
  )
  _aros_conf_has_option("${AROS_MODULE_MODULE_CONF}" "rellinklib" _aros_module_has_rellinklib)
  if(_aros_module_has_rellinklib)
    _aros_get_genmodule_rel_linklib_output(
      "${AROS_MODULE_MODULE_NAME}"
      "${AROS_MODULE_MODULE_TYPE}"
      "${AROS_MODULE_MODULE_SUFFIX}"
      _aros_module_rel_linklib_output
    )
  else()
    set(_aros_module_rel_linklib_output "")
  endif()

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

    set(_aros_existing_interface_include_dirs)
    if(_aros_existing_interface_target AND TARGET "${_aros_existing_interface_target}")
      get_target_property(
        _aros_existing_interface_include_dirs
        "${_aros_existing_interface_target}"
        AROS_MODULE_INTERFACE_INCLUDE_DIRS
      )
      if(_aros_existing_interface_include_dirs STREQUAL "AROS_MODULE_INTERFACE_INCLUDE_DIRS-NOTFOUND")
        set(_aros_existing_interface_include_dirs)
      endif()
    endif()

    add_library("${_aros_module_interface_target}" INTERFACE)
    if(_aros_existing_interface_include_dirs)
      target_include_directories("${_aros_module_interface_target}" INTERFACE ${_aros_existing_interface_include_dirs})
    else()
      target_include_directories("${_aros_module_interface_target}" INTERFACE "${AROS_NATIVE_INCLUDE_DIR}")
    endif()
    if(_aros_existing_interface_target)
      target_link_libraries("${_aros_module_interface_target}" INTERFACE "${_aros_existing_interface_target}")
    endif()
    add_dependencies("${_aros_module_interface_target}" "${target_name}-interfaces")
    set_target_properties(
      "${_aros_module_interface_target}"
      PROPERTIES
        AROS_MODULE_INTERFACE_INCLUDE_DIRS "${_aros_existing_interface_include_dirs}"
    )

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
    _aros_set_target_folder_if_exists("${target_name}-interfaces" "${_aros_module_internal_folder}")
    _aros_set_target_folder_if_exists("${_aros_module_interface_target}" "${_aros_module_internal_folder}")
    _aros_set_target_folder_if_exists("${target_name}" "${_aros_module_internal_folder}")
    _aros_set_target_folder_if_exists("${_aros_module_native_abi_target}" "${_aros_module_internal_folder}")
    if(NOT target_name MATCHES "-sdk-native$")
      _aros_register_public_module_aliases(
        "${AROS_MODULE_MODULE_PATH}"
        "${AROS_MODULE_MODULE_NAME}"
        "${AROS_MODULE_MODULE_TYPE}"
        "${target_name}"
        "${target_name}-interfaces"
        "${_aros_module_interface_target}"
        "${_aros_existing_output}"
        "${_aros_module_public_linklib_output}"
      )
    endif()
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
  set(_aros_module_config_deps
    ${AROS_NATIVE_CONFIG_FILE}
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AROSNativeConfig.cmake"
    "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
  )

  set(_aros_module_build_deps
    aros-configure
    genmodule
    "${CMAKE_SOURCE_DIR}/cmake/build_genmodule_module.cmake"
    "${CMAKE_SOURCE_DIR}/cmake/AROSMmakeBuild.cmake"
    "${CMAKE_SOURCE_DIR}/cmake/AROSMmakeFunctions.cmake"
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
  set(_aros_module_resolved_link_options ${AROS_MODULE_LINK_OPTIONS})
  set(_aros_module_resolved_link_libs ${AROS_MODULE_LINK_LIBS})
  if(AROS_COMPILER_NATIVE_MODULE_LINKLIBS)
    list(APPEND _aros_module_resolved_link_libs ${AROS_COMPILER_NATIVE_MODULE_LINKLIBS})
  endif()
  list(REMOVE_DUPLICATES _aros_module_resolved_link_libs)
  _aros_encode_list("${_aros_module_resolved_link_libs}" _aros_module_link_libs)
  list(REMOVE_DUPLICATES _aros_module_resolved_link_options)
  _aros_encode_list("${_aros_module_resolved_link_options}" _aros_module_link_options)
  set(_aros_module_resolved_auto_link_libs ${AROS_COMPILER_NATIVE_MODULE_AUTOLIBS})
  list(REMOVE_DUPLICATES _aros_module_resolved_auto_link_libs)
  _aros_encode_list("${_aros_module_resolved_auto_link_libs}" _aros_module_auto_link_libs)

  set(_aros_module_archive_dep_names ${_aros_module_resolved_link_libs})
  list(APPEND _aros_module_archive_dep_names ${_aros_module_resolved_auto_link_libs})
  list(APPEND _aros_module_archive_dep_names ${_aros_module_target_c_lib_names})
  list(APPEND _aros_module_archive_dep_names ${_aros_module_option_link_lib_names})
  list(REMOVE_DUPLICATES _aros_module_archive_dep_names)
  _aros_collect_registered_archive_dependencies(
    _aros_module_archive_dep_files
    _aros_module_archive_dep_targets
    ${_aros_module_archive_dep_names}
  )
  _aros_encode_list("${_aros_module_archive_dep_files}" _aros_module_archive_dep_files_encoded)
  _aros_collect_interface_dependency_artifacts(
    _aros_module_interface_dep_files
    _aros_module_interface_dep_targets
    ${AROS_MODULE_INTERFACE_DEPENDS}
  )

  set(_aros_module_interface_build_file_deps
    ${_aros_module_interface_dep_files}
    ${_aros_module_config_deps}
  )
  set(_aros_module_interface_build_target_deps ${_aros_module_build_deps})
  list(APPEND _aros_module_interface_build_target_deps ${_aros_module_interface_dep_targets})
  list(REMOVE_DUPLICATES _aros_module_interface_build_target_deps)

  set(_aros_module_runtime_build_file_deps
    "${_aros_module_interface_stamp}"
    ${_aros_module_interface_dep_files}
    ${_aros_module_archive_dep_files}
    ${_aros_module_config_deps}
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
            "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
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
  _aros_collect_module_interface_include_dirs(
    "${AROS_MODULE_MODULE_PATH}"
    "${AROS_MODULE_MODULE_MMAKE_NAME}"
    "${AROS_MODULE_MODULE_SDK}"
    "${AROS_MODULE_MMAKEFILE_SRC}"
    _aros_module_interface_include_dirs
  )
  set(_aros_module_runtime_include_dirs ${AROS_MODULE_INCLUDE_DIRS})
  list(APPEND _aros_module_runtime_include_dirs ${_aros_module_interface_include_dirs})
  list(REMOVE_DUPLICATES _aros_module_runtime_include_dirs)
  if(AROS_NATIVE_INCLUDE_DIR)
    # The builder appends the flat public include root later on purpose.
    # Keeping it in MODULE_INCLUDE_DIRS lets generated private sources pick
    # public headers like native-includes/lddemon.h before module-local ones.
    list(REMOVE_ITEM _aros_module_runtime_include_dirs "${AROS_NATIVE_INCLUDE_DIR}")
  endif()
  _aros_encode_list("${_aros_module_runtime_include_dirs}" _aros_module_runtime_include_dirs_encoded)
  add_library("${_aros_module_interface_target}" INTERFACE)
  if(_aros_module_interface_include_dirs)
    target_include_directories("${_aros_module_interface_target}" INTERFACE ${_aros_module_interface_include_dirs})
  else()
    target_include_directories("${_aros_module_interface_target}" INTERFACE "${AROS_NATIVE_INCLUDE_DIR}")
  endif()
  add_dependencies("${_aros_module_interface_target}" "${target_name}-interfaces")

  if(NOT AROS_MODULE_INTERFACE_NAMES)
    if(AROS_MODULE_MODULE_MMAKE_NAME)
      set(AROS_MODULE_INTERFACE_NAMES "${AROS_MODULE_MODULE_MMAKE_NAME}-includes")
    else()
      set(AROS_MODULE_INTERFACE_NAMES "kernel-${AROS_MODULE_MODULE_NAME}-includes")
    endif()
  endif()
  set_target_properties(
    "${_aros_module_interface_target}"
    PROPERTIES
      AROS_MODULE_INTERFACE_STAMP "${_aros_module_interface_stamp}"
      AROS_MODULE_INTERFACE_NAMES "${AROS_MODULE_INTERFACE_NAMES}"
      AROS_MODULE_INTERFACE_DEPENDS "${AROS_MODULE_INTERFACE_DEPENDS}"
      AROS_MODULE_INTERFACE_INCLUDE_DIRS "${_aros_module_interface_include_dirs}"
      AROS_MODULE_INTERFACE_DEPENDENCY_STAMPS ""
      AROS_SOURCE_INCLUDE_VIRTUAL_PATHS "${AROS_MODULE_SOURCE_INCLUDE_PATHS}"
      AROS_MODULE_STAGED_INCLUDE_PATHS "${AROS_MODULE_STAGED_INCLUDE_PATHS}"
      AROS_MODULE_ARCHIVE_DEP_NAMES "${_aros_module_archive_dep_names}"
      AROS_MODULE_ARCHIVE_DEP_FILES "${_aros_module_archive_dep_files}"
      AROS_MODULE_ARCHIVE_DEP_TARGETS "${_aros_module_archive_dep_targets}"
      AROS_MODULE_PUBLIC_LINKLIB_OUTPUT "${_aros_module_public_linklib_output}"
      AROS_MODULE_REL_LINKLIB_OUTPUT "${_aros_module_rel_linklib_output}"
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
    OUTPUT "${_aros_module_link_manifest}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
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
            -DMODULE_INCLUDE_DIRS=${_aros_module_runtime_include_dirs_encoded}
            -DMODULE_COMPILE_DEFINITIONS=${_aros_module_compile_definitions}
            -DMODULE_COMPILE_OPTIONS=${_aros_module_compile_options}
            -DMODULE_LINK_OPTIONS=${_aros_module_link_options}
            -DMODULE_LINK_LIBS=${_aros_module_link_libs}
            -DMODULE_AUTO_LINK_LIBS=${_aros_module_auto_link_libs}
            -DMODULE_EXPECTED_ARCHIVE_DEPS=${_aros_module_archive_dep_files_encoded}
            -DMODULE_LINK_MANIFEST=${_aros_module_link_manifest}
            -P "${CMAKE_SOURCE_DIR}/cmake/build_genmodule_module.cmake"
    DEPENDS
      ${_aros_module_runtime_build_target_deps}
      ${_aros_module_runtime_build_file_deps}
      "$<TARGET_PROPERTY:${_aros_module_interface_target},AROS_MODULE_ARCHIVE_DEP_FILES>"
      "$<TARGET_PROPERTY:${_aros_module_interface_target},AROS_MODULE_INTERFACE_DEPENDENCY_STAMPS>"
    COMMENT "Compiling native CMake ${AROS_MODULE_MODULE_PATH} module"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${_aros_module_output}"
    COMMAND "${CMAKE_COMMAND}" "-DMODULE_LINK_MANIFEST=${_aros_module_link_manifest}"
      -P "${CMAKE_SOURCE_DIR}/cmake/link_genmodule_module.cmake"
    DEPENDS "${_aros_module_link_manifest}" "${CMAKE_SOURCE_DIR}/cmake/link_genmodule_module.cmake"
    COMMENT "Linking native CMake ${AROS_MODULE_MODULE_PATH} module"
    VERBATIM
  )
  add_custom_command(
    OUTPUT "${_aros_module_kobj}"
    COMMAND "${CMAKE_COMMAND}" "-DMODULE_LINK_MANIFEST=${_aros_module_link_manifest}"
      "-DKICKSTART_OUTPUT=${_aros_module_kobj}"
      -P "${CMAKE_SOURCE_DIR}/cmake/link_genmodule_module.cmake"
    DEPENDS "${_aros_module_link_manifest}" "${CMAKE_SOURCE_DIR}/cmake/link_genmodule_module.cmake"
      "$<TARGET_PROPERTY:${target_name}-kobj,AROS_KOBJ_DEP_FILES>"
    COMMENT "Linking native CMake ${AROS_MODULE_MODULE_PATH} kickstart object"
    VERBATIM
  )
  add_custom_target("${target_name}-kobj" DEPENDS "${_aros_module_kobj}")
  set_target_properties("${target_name}-kobj" PROPERTIES FOLDER "${_aros_module_internal_folder}"
    AROS_KOBJ_DEP_FILES ""
    AROS_KOBJ_ARCHIVE_NAMES "${_aros_module_resolved_link_libs};dos;intuition;layers;graphics;oop;utility;expansion;keymap")
  set_property(GLOBAL PROPERTY "AROS_KICKSTART_OBJECT_${AROS_MODULE_MODULE_NAME}_${AROS_MODULE_MODULE_SUFFIX}"
    "${target_name}-kobj|${_aros_module_kobj}")
  set_property(GLOBAL APPEND PROPERTY AROS_REGISTERED_KOBJ_TARGETS "${target_name}-kobj")
  add_custom_target("${target_name}" DEPENDS "${_aros_module_output}")
  add_custom_target("${_aros_module_native_abi_target}" DEPENDS "${_aros_module_output}")
  _aros_set_target_folder_if_exists("${target_name}-interfaces" "${_aros_module_internal_folder}")
  _aros_set_target_folder_if_exists("${_aros_module_interface_target}" "${_aros_module_internal_folder}")
  _aros_set_target_folder_if_exists("${target_name}" "${_aros_module_internal_folder}")
  _aros_set_target_folder_if_exists("${_aros_module_native_abi_target}" "${_aros_module_internal_folder}")
  if(NOT target_name MATCHES "-sdk-native$")
    if(AROS_MODULE_MODULE_MMAKE_NAME)
      _aros_register_mmake_runtime_target("${AROS_MODULE_MODULE_MMAKE_NAME}" "${target_name}")
    endif()
    set_target_properties(
      "${target_name}"
      PROPERTIES
        AROS_MODULE_RUNTIME_LINK_DEP_NAMES "${_aros_module_resolved_link_libs}"
    )
    _aros_register_public_module_aliases(
      "${AROS_MODULE_MODULE_PATH}"
      "${AROS_MODULE_MODULE_NAME}"
      "${AROS_MODULE_MODULE_TYPE}"
      "${target_name}"
      "${target_name}-interfaces"
      "${_aros_module_interface_target}"
      "${_aros_module_output}"
      "${_aros_module_public_linklib_output}"
    )
  endif()
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
  if(_aros_module_rel_linklib_output)
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
  endif()
endfunction()

function(_aros_register_mmake_runtime_target mmake target_name)
  if(NOT mmake OR NOT TARGET "${target_name}")
    message(FATAL_ERROR "Native mmake registration requires a name and an existing target")
  endif()
  string(SHA256 _key "${mmake}")
  get_property(_owner GLOBAL PROPERTY "AROS_MMAKE_RUNTIME_TARGET_${_key}")
  if(_owner AND NOT _owner STREQUAL target_name)
    message(FATAL_ERROR "Conflicting native mmake producers for ${mmake}: ${_owner}, ${target_name}")
  endif()
  set_property(GLOBAL PROPERTY "AROS_MMAKE_RUNTIME_TARGET_${_key}" "${target_name}")
endfunction()

function(aros_register_mmake_genmodule_module target_name)
  set(_options)
  set(_one_value_args
    MODULE_PATH
    MODULE_NAME
    MODULE_TYPE
    MODULE_SDK
    MMAKEFILE_SRC
    MODULE_CONF
    MMAKE_NAME
  )
  set(_multi_value_args
    COMPILE_DEFINITIONS
    COMPILE_OPTIONS
    DEPENDS
    LAYER_EXCLUSIONS
    LINK_LIBS
    LINK_OPTIONS
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

  _aros_extract_mmake_build_module_metadata(
    "${_aros_mmakefile_src}"
    "${AROS_MMAKE_MODULE_PATH}"
    _aros_mmake
    MMAKE_NAME "${AROS_MMAKE_MMAKE_NAME}"
  )
  if(AROS_MMAKE_MODULE_NAME)
    set(_aros_mmake_MODULE_NAME "${AROS_MMAKE_MODULE_NAME}")
  endif()
  if(AROS_MMAKE_MODULE_TYPE)
    set(_aros_mmake_MODULE_TYPE "${AROS_MMAKE_MODULE_TYPE}")
  endif()
  if(AROS_MMAKE_MODULE_SDK)
    set(_aros_mmake_MODULE_SDK "${AROS_MMAKE_MODULE_SDK}")
  endif()
  if(AROS_MMAKE_MODULE_CONF)
    set(_aros_mmake_effective_conf_for_rellibs "${AROS_MMAKE_MODULE_CONF}")
  else()
    set(_aros_mmake_effective_conf_for_rellibs "${_aros_mmake_MODULE_CONF}")
  endif()
  _aros_extract_conf_rellibs("${_aros_mmake_effective_conf_for_rellibs}" _aros_mmake_CONF_RELLIBS)
  _aros_extract_mmake_include_interface_metadata(
    "${_aros_mmakefile_src}"
    "${_aros_mmake_MODULE_NAME}"
    _aros_mmake_INTERFACE_NAMES
    _aros_mmake_INTERFACE_DEPENDS
    "${_aros_mmake_MMAKE_NAME}"
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
  _aros_collect_include_virtual_paths_from_files(_aros_module_source_include_paths ${_aros_module_source_deps})
  _aros_collect_staged_copy_include_paths_from_mmake(
    "${_aros_mmakefile_src}"
    "${AROS_MMAKE_MODULE_PATH}"
    _aros_module_staged_include_paths
  )
  _aros_register_module_local_strings_header(
    "${AROS_MMAKE_MODULE_PATH}"
    _aros_module_local_strings_header_target
    _aros_module_local_strings_header_dir
    ${_aros_module_source_deps}
  )
  set(_aros_module_extra_include_dirs)
  set(_aros_module_extra_dep_targets)
  if(_aros_module_local_strings_header_dir)
    list(APPEND _aros_module_extra_include_dirs "${_aros_module_local_strings_header_dir}")
  endif()
  if(_aros_module_local_strings_header_target)
    list(APPEND _aros_module_extra_dep_targets "${_aros_module_local_strings_header_target}")
  endif()

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
    MODULE_RUNTIME_DIR "${_aros_mmake_MODULE_RUNTIME_DIR}"
    SOURCE_INCLUDE_PATHS ${_aros_module_source_include_paths}
    STAGED_INCLUDE_PATHS ${_aros_module_staged_include_paths}
    INCLUDE_DIRS ${_aros_module_extra_include_dirs}
    COMPILE_DEFINITIONS ${AROS_MMAKE_COMPILE_DEFINITIONS}
    COMPILE_OPTIONS ${AROS_MMAKE_COMPILE_OPTIONS}
    LINK_OPTIONS ${AROS_MMAKE_LINK_OPTIONS}
    LINK_LIBS ${AROS_MMAKE_LINK_LIBS}
    LINK_LIBS ${_aros_mmake_MODULE_LINK_LIBS} ${_aros_mmake_CONF_RELLIBS}
    INTERFACE_NAMES ${_aros_mmake_INTERFACE_NAMES}
    INTERFACE_DEPENDS ${_aros_mmake_INTERFACE_DEPENDS}
    LAYER_EXCLUSIONS ${AROS_MMAKE_LAYER_EXCLUSIONS}
    DEPENDS
      "${_aros_mmakefile_src}"
      "${_aros_module_conf}"
      ${_aros_module_extra_dep_targets}
      ${_aros_module_source_deps}
      ${AROS_MMAKE_DEPENDS}
  )
endfunction()

function(aros_register_mmake_linklib target_name)
  set(_options LEGACY_GENERATED_HEADERS)
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

  _aros_get_linklib_output_dir_for_sdk("${_aros_linklib_SDK}" _aros_linklib_output_dir)

  set(_aros_linklib_output "${_aros_linklib_output_dir}/lib${_aros_linklib_LIBNAME}.a")
  string(REPLACE "/" "_" _aros_linklib_id "${AROS_LINKLIB_MODULE_PATH}")
  string(REPLACE "." "_" _aros_linklib_lib_id "${_aros_linklib_LIBNAME}")
  set(_aros_linklib_obj_dir "${CMAKE_BINARY_DIR}/linklibs/${_aros_linklib_id}/${_aros_linklib_lib_id}")
  set(_aros_linklib_include_stamp "${_aros_linklib_obj_dir}/.includes.stamp")
  _aros_compute_target_folders("${AROS_LINKLIB_MODULE_PATH}" _aros_linklib_public_folder _aros_linklib_internal_folder)
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
  set(_aros_linklib_config_deps
    ${AROS_NATIVE_CONFIG_FILE}
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AROSNativeConfig.cmake"
    "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
  )

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
    "${_aros_mmakefile_src}"
    ${_aros_linklib_config_deps}
    ${AROS_LINKLIB_DEPENDS}
  )
  if(DEFINED AROS_NATIVE_INCLUDES_STAMP)
    list(APPEND _aros_linklib_include_deps "${AROS_NATIVE_INCLUDES_STAMP}")
  endif()

  if(AROS_LINKLIB_LEGACY_GENERATED_HEADERS)
    if(NOT AROS_LINKLIB_DEPENDS)
      message(FATAL_ERROR "LEGACY_GENERATED_HEADERS requires an explicit code-generation dependency")
    endif()
    # Preserve existing generator adapters until their recipes have native
    # manifest translators. Never infer this escape hatch from existing files.
    set(_aros_header_commands
      COMMAND "${CMAKE_COMMAND}"
        -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
        -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
        -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
        "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
        -DAROS_TARGET=${AROS_TARGET}
        -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
        -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
        -DMMAKEFILE_PATH=${_aros_mmakefile_src}
        -DINCLUDES_SDK=${_aros_linklib_SDK}
        -DINCLUDES_STAMP=${_aros_linklib_include_stamp}
        -P "${CMAKE_SOURCE_DIR}/cmake/stage_mmake_includes.cmake")
    list(APPEND _aros_linklib_include_deps "${CMAKE_SOURCE_DIR}/cmake/stage_mmake_includes.cmake")
  else()
    set(_aros_header_commands
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${_aros_linklib_obj_dir}"
      COMMAND "${CMAKE_COMMAND}" -E touch "${_aros_linklib_include_stamp}")
  endif()
  add_custom_command(
    OUTPUT "${_aros_linklib_include_stamp}"
    ${_aros_header_commands}
    DEPENDS
      ${_aros_linklib_include_deps}
      "$<TARGET_PROPERTY:${target_name},AROS_LINKLIB_HEADER_OUTPUTS>"
    COMMENT "Completing manifest headers for ${_aros_linklib_LIBNAME}"
    VERBATIM
  )

  add_custom_command(
    OUTPUT "${_aros_linklib_output}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
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
            -DLINKLIB_DEPFILE=${_aros_linklib_obj_dir}/${_aros_linklib_LIBNAME}.d
            "-DLINKLIB_FETCH_CONTEXT=$<TARGET_PROPERTY:${target_name},AROS_LINKLIB_FETCH_CONTEXT>"
            -P "${CMAKE_SOURCE_DIR}/cmake/build_mmake_linklib.cmake"
    DEPENDS
      "${_aros_linklib_include_stamp}"
      "$<TARGET_PROPERTY:${target_name},AROS_LINKLIB_FETCH_CONTEXT>"
      "$<TARGET_PROPERTY:${target_name},AROS_LINKLIB_FETCH_REPORTS>"
      aros-configure
      aros-native-includes
      "${CMAKE_SOURCE_DIR}/cmake/build_mmake_linklib.cmake"
      "${CMAKE_SOURCE_DIR}/cmake/AROSMmakeFunctions.cmake"
      "${_aros_mmakefile_src}"
      ${_aros_linklib_config_deps}
      ${_aros_linklib_source_deps}
      ${AROS_LINKLIB_DEPENDS}
    COMMENT "Building native CMake ${_aros_linklib_LIBNAME} linklib"
    DEPFILE "${_aros_linklib_obj_dir}/${_aros_linklib_LIBNAME}.d"
    VERBATIM
  )

  add_custom_target("${target_name}-includes" DEPENDS "${_aros_linklib_include_stamp}")
  add_custom_target("${target_name}" DEPENDS "${_aros_linklib_output}")
  set_property(TARGET "${target_name}" PROPERTY AROS_LINKLIB_OUTPUT "${_aros_linklib_output}")
  set_target_properties("${target_name}" PROPERTIES
    AROS_LINKLIB_HEADER_OUTPUTS "" AROS_LINKLIB_FETCH_CONTEXT "" AROS_LINKLIB_FETCH_REPORTS ""
    AROS_LINKLIB_MMAKE_NAME "${_aros_linklib_MMAKE_NAME}")
  if(NOT AROS_LINKLIB_LEGACY_GENERATED_HEADERS)
    set_property(TARGET "${target_name}" PROPERTY AROS_LINKLIB_HEADER_MANIFEST "${_aros_mmakefile_src}")
  endif()
  get_property(_headers_scheduled GLOBAL PROPERTY AROS_LINKLIB_HEADERS_SCHEDULED)
  if(NOT _headers_scheduled)
    set_property(GLOBAL PROPERTY AROS_LINKLIB_HEADERS_SCHEDULED TRUE)
    cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _aros_finalize_linklib_headers)
  endif()
  _aros_set_target_folder_if_exists("${target_name}-includes" "${_aros_linklib_internal_folder}")
  _aros_set_target_folder_if_exists("${target_name}" "${_aros_linklib_internal_folder}")
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
  _aros_register_public_linklib_alias(
    "${AROS_LINKLIB_MODULE_PATH}"
    "${_aros_linklib_LIBNAME}"
    "${target_name}"
    "${_aros_linklib_output}"
  )
  set(${target_name}_OUTPUT "${_aros_linklib_output}" PARENT_SCOPE)
endfunction()

function(_aros_finalize_linklib_headers)
  # All module interface identities must exist before resolving header edges.
  include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AROSProgramTargets.cmake")
  aros_finalize_mmake_linklib_headers()
endfunction()

function(aros_register_archive_linklib target_name)
  set(_options)
  set(_one_value_args
    MODULE_PATH
    LIBNAME
    SDK
  )
  set(_multi_value_args
    OBJECTS
    DEPENDS
    SOURCE_INTERFACE_MODULES
  )
  cmake_parse_arguments(AROS_ARCHIVE "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_ARCHIVE_MODULE_PATH OR NOT AROS_ARCHIVE_LIBNAME OR NOT AROS_ARCHIVE_OBJECTS)
    message(FATAL_ERROR "aros_register_archive_linklib requires MODULE_PATH, LIBNAME, and OBJECTS")
  endif()

  if(NOT AROS_ARCHIVE_SDK)
    set(AROS_ARCHIVE_SDK "public")
  endif()

  _aros_get_linklib_output_dir_for_sdk("${AROS_ARCHIVE_SDK}" _aros_archive_output_dir)
  set(_aros_archive_output "${_aros_archive_output_dir}/lib${AROS_ARCHIVE_LIBNAME}.a")
  _aros_compute_target_folders("${AROS_ARCHIVE_MODULE_PATH}" _aros_archive_public_folder _aros_archive_internal_folder)

  if(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR)
    set(_aros_archive_toolchain_dir "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}")
  elseif(AROS_CROSSTOOLS_INSTALL_DIR)
    set(_aros_archive_toolchain_dir "${AROS_CROSSTOOLS_INSTALL_DIR}")
  elseif(AROS_TOOLCHAIN_INSTALL_DIR)
    set(_aros_archive_toolchain_dir "${AROS_TOOLCHAIN_INSTALL_DIR}")
  else()
    set(_aros_archive_toolchain_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools")
  endif()

  set(_aros_archive_config_deps
    ${AROS_NATIVE_CONFIG_FILE}
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AROSNativeConfig.cmake"
    "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
  )

  _aros_encode_list("${AROS_ARCHIVE_OBJECTS}" _aros_archive_objects_encoded)

  add_custom_command(
    OUTPUT "${_aros_archive_output}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
            -DAROS_TARGET=${AROS_TARGET}
            -DAROS_TOOLCHAIN_DIR=${_aros_archive_toolchain_dir}
            -DAROS_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros
            -DARCHIVE_OUTPUT=${_aros_archive_output}
            -DOBJECTS_ENCODED=${_aros_archive_objects_encoded}
            -P "${CMAKE_SOURCE_DIR}/cmake/archive_static_library.cmake"
    DEPENDS
      "${CMAKE_SOURCE_DIR}/cmake/archive_static_library.cmake"
      ${_aros_archive_config_deps}
      ${AROS_ARCHIVE_OBJECTS}
      ${AROS_ARCHIVE_DEPENDS}
    COMMENT "Building native CMake ${AROS_ARCHIVE_LIBNAME} linklib"
    VERBATIM
  )

  add_custom_target("${target_name}" DEPENDS "${_aros_archive_output}")
  set_property(TARGET "${target_name}" PROPERTY AROS_LINKLIB_OUTPUT "${_aros_archive_output}")
  _aros_set_target_folder_if_exists("${target_name}" "${_aros_archive_internal_folder}")
  if(AROS_ARCHIVE_SOURCE_INTERFACE_MODULES)
    set_target_properties(
      "${target_name}"
      PROPERTIES
        AROS_SOURCE_INTERFACE_MODULES "${AROS_ARCHIVE_SOURCE_INTERFACE_MODULES}"
    )
  endif()
  get_property(_aros_registered_linklib_targets GLOBAL PROPERTY AROS_REGISTERED_LINKLIB_TARGETS)
  list(APPEND _aros_registered_linklib_targets "${target_name}")
  list(REMOVE_DUPLICATES _aros_registered_linklib_targets)
  set_property(GLOBAL PROPERTY AROS_REGISTERED_LINKLIB_TARGETS "${_aros_registered_linklib_targets}")
  _aros_sanitize_property_key("${AROS_ARCHIVE_LIBNAME}" _aros_archive_lib_key)
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_LINKLIB_OUTPUT_${_aros_archive_lib_key}"
    "${_aros_archive_output}"
  )
  set_property(
    GLOBAL
    PROPERTY "AROS_REGISTERED_LINKLIB_TARGET_${_aros_archive_lib_key}"
    "${target_name}"
  )
  _aros_register_public_linklib_alias(
    "${AROS_ARCHIVE_MODULE_PATH}"
    "${AROS_ARCHIVE_LIBNAME}"
    "${target_name}"
    "${_aros_archive_output}"
  )
  set(${target_name}_OUTPUT "${_aros_archive_output}" PARENT_SCOPE)
endfunction()

function(aros_register_mmake_hidd_stub_producer target_name)
  set(_options)
  set(_one_value_args
    MODULE_PATH
    MMAKEFILE_SRC
    INCLUDES_MMAKEFILE_SRC
    MMAKE_CONTEXT_DIR
    SDK
  )
  set(_multi_value_args
    DEPENDS
  )
  cmake_parse_arguments(AROS_HIDDSTUB "${_options}" "${_one_value_args}" "${_multi_value_args}" ${ARGN})

  if(NOT AROS_HIDDSTUB_MODULE_PATH)
    message(FATAL_ERROR "aros_register_mmake_hidd_stub_producer requires MODULE_PATH")
  endif()

  if(AROS_HIDDSTUB_MMAKEFILE_SRC)
    set(_aros_hiddstub_mmakefile "${AROS_HIDDSTUB_MMAKEFILE_SRC}")
  else()
    set(_aros_hiddstub_mmakefile "${CMAKE_SOURCE_DIR}/${AROS_HIDDSTUB_MODULE_PATH}/mmakefile.src")
  endif()

  if(NOT EXISTS "${_aros_hiddstub_mmakefile}")
    message(FATAL_ERROR "Missing hidd stub mmakefile: ${_aros_hiddstub_mmakefile}")
  endif()

  if(AROS_HIDDSTUB_INCLUDES_MMAKEFILE_SRC)
    set(_aros_hiddstub_includes_mmakefile "${AROS_HIDDSTUB_INCLUDES_MMAKEFILE_SRC}")
  else()
    set(_aros_hiddstub_includes_mmakefile "${_aros_hiddstub_mmakefile}")
  endif()

  if(NOT AROS_HIDDSTUB_MMAKE_CONTEXT_DIR)
    set(AROS_HIDDSTUB_MMAKE_CONTEXT_DIR "${AROS_HIDDSTUB_MODULE_PATH}")
  endif()
  if(NOT AROS_HIDDSTUB_SDK)
    set(AROS_HIDDSTUB_SDK "private")
  endif()

  _aros_collect_make_variable_from_file(
    "${_aros_hiddstub_mmakefile}"
    "STUBS"
    _aros_hiddstub_names
    "${AROS_HIDDSTUB_MMAKE_CONTEXT_DIR}"
  )
  if(NOT _aros_hiddstub_names)
    message(FATAL_ERROR "Could not determine STUBS from ${_aros_hiddstub_mmakefile}")
  endif()

  _aros_collect_make_variable_from_file(
    "${_aros_hiddstub_mmakefile}"
    "USER_CPPFLAGS"
    _aros_hiddstub_user_cppflags
    "${AROS_HIDDSTUB_MMAKE_CONTEXT_DIR}"
  )
  _aros_collect_make_variable_from_file(
    "${_aros_hiddstub_mmakefile}"
    "USER_CFLAGS"
    _aros_hiddstub_user_cflags
    "${AROS_HIDDSTUB_MMAKE_CONTEXT_DIR}"
  )
  _aros_collect_make_variable_from_file(
    "${_aros_hiddstub_mmakefile}"
    "USER_INCLUDES"
    _aros_hiddstub_user_includes
    "${AROS_HIDDSTUB_MMAKE_CONTEXT_DIR}"
  )

  _aros_read_config_tokens("CPPFLAGS" _aros_hiddstub_cppflags)
  _aros_read_config_tokens("CFLAGS" _aros_hiddstub_cflags)

  if(AROS_NATIVE_TOOLCHAIN_INSTALL_DIR)
    set(_aros_hiddstub_toolchain_dir "${AROS_NATIVE_TOOLCHAIN_INSTALL_DIR}")
  elseif(AROS_CROSSTOOLS_INSTALL_DIR)
    set(_aros_hiddstub_toolchain_dir "${AROS_CROSSTOOLS_INSTALL_DIR}")
  elseif(AROS_TOOLCHAIN_INSTALL_DIR)
    set(_aros_hiddstub_toolchain_dir "${AROS_TOOLCHAIN_INSTALL_DIR}")
  else()
    set(_aros_hiddstub_toolchain_dir "${CMAKE_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools")
  endif()

  string(REPLACE "/" "_" _aros_hiddstub_id "${AROS_HIDDSTUB_MODULE_PATH}")
  set(_aros_hiddstub_work_dir "${CMAKE_BINARY_DIR}/hiddstubs/${_aros_hiddstub_id}")
  set(_aros_hiddstub_include_stamp "${_aros_hiddstub_work_dir}/.includes.stamp")
  get_filename_component(_aros_hiddstub_source_dir "${_aros_hiddstub_mmakefile}" DIRECTORY)
  _aros_compute_target_folders("${AROS_HIDDSTUB_MODULE_PATH}" _aros_hiddstub_public_folder _aros_hiddstub_internal_folder)
  set(_aros_hiddstub_config_deps
    ${AROS_NATIVE_CONFIG_FILE}
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/AROSNativeConfig.cmake"
    "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/build.cfg"
    "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/compiler.cfg"
  )

  add_custom_command(
    OUTPUT "${_aros_hiddstub_include_stamp}"
    COMMAND "${CMAKE_COMMAND}"
            -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
            -DAROS_CONFIG_BUILD_DIR=${AROS_LEGACY_BUILD_DIR}
            "-DAROS_NATIVE_CONFIG_FILE=${AROS_NATIVE_CONFIG_FILE}"
            -DAROS_TARGET=${AROS_TARGET}
            -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
            -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
            -DMMAKEFILE_PATH=${_aros_hiddstub_includes_mmakefile}
            -DINCLUDES_SDK=${AROS_HIDDSTUB_SDK}
            -DINCLUDES_STAMP=${_aros_hiddstub_include_stamp}
            -P "${CMAKE_SOURCE_DIR}/cmake/stage_mmake_includes.cmake"
    DEPENDS
      aros-native-includes
      "${CMAKE_SOURCE_DIR}/cmake/stage_mmake_includes.cmake"
      "${_aros_hiddstub_includes_mmakefile}"
      ${_aros_hiddstub_config_deps}
      ${AROS_HIDDSTUB_DEPENDS}
    COMMENT "Staging native CMake HIDD stub includes for ${AROS_HIDDSTUB_MODULE_PATH}"
    VERBATIM
  )

  set(_aros_hiddstub_objects)
  foreach(_aros_hiddstub_name IN LISTS _aros_hiddstub_names)
    set(_aros_hiddstub_source "${_aros_hiddstub_source_dir}/${_aros_hiddstub_name}.c")
    if(NOT EXISTS "${_aros_hiddstub_source}")
      message(FATAL_ERROR "Missing HIDD stub source ${_aros_hiddstub_source}")
    endif()

    set(_aros_hiddstub_output "${AROS_NATIVE_PRIVATE_LIB_DIR}/hidd/${_aros_hiddstub_name}.o")
    set(_aros_hiddstub_depfile "${_aros_hiddstub_work_dir}/${_aros_hiddstub_name}.d")
    _aros_encode_list("${_aros_hiddstub_cppflags}" _aros_hiddstub_cppflags_encoded)
    _aros_encode_list("${_aros_hiddstub_cflags}" _aros_hiddstub_cflags_encoded)
    _aros_encode_list("${_aros_hiddstub_user_cppflags}" _aros_hiddstub_user_cppflags_encoded)
    _aros_encode_list("${_aros_hiddstub_user_cflags}" _aros_hiddstub_user_cflags_encoded)
    _aros_encode_list("${_aros_hiddstub_user_includes}" _aros_hiddstub_user_includes_encoded)

    add_custom_command(
      OUTPUT "${_aros_hiddstub_output}"
      COMMAND "${CMAKE_COMMAND}"
              -DAROS_TOOLCHAIN_DIR=${_aros_hiddstub_toolchain_dir}
              -DAROS_TOOLCHAIN_PREFIX=${AROS_CROSSTOOLS_TARGET_CPU}-aros
              -DAROS_SYSROOT=${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/AROS/Development
              -DAROS_SOURCE_DIR=${CMAKE_SOURCE_DIR}
              -DAROS_BINARY_DIR=${CMAKE_BINARY_DIR}
              -DAROS_NATIVE_INCLUDE_DIR=${AROS_NATIVE_INCLUDE_DIR}
              -DAROS_NATIVE_BUILD_SDKS_DIR=${AROS_NATIVE_BUILD_SDKS_DIR}
              -DOBJECT_SOURCE=${_aros_hiddstub_source}
              -DOBJECT_OUTPUT=${_aros_hiddstub_output}
              -DOBJECT_DEPFILE=${_aros_hiddstub_depfile}
              -DCPPFLAGS_ENCODED=${_aros_hiddstub_cppflags_encoded}
              -DCFLAGS_ENCODED=${_aros_hiddstub_cflags_encoded}
              -DUSER_CPPFLAGS_ENCODED=${_aros_hiddstub_user_cppflags_encoded}
              -DUSER_CFLAGS_ENCODED=${_aros_hiddstub_user_cflags_encoded}
              -DUSER_INCLUDES_ENCODED=${_aros_hiddstub_user_includes_encoded}
              -DSDK_NAME=${AROS_HIDDSTUB_SDK}
              -P "${CMAKE_SOURCE_DIR}/cmake/compile_target_object.cmake"
      DEPFILE "${_aros_hiddstub_depfile}"
      DEPENDS
        "${_aros_hiddstub_include_stamp}"
        aros-sdk-interfaces-native
        "${CMAKE_SOURCE_DIR}/cmake/compile_target_object.cmake"
        "${_aros_hiddstub_source}"
        "${_aros_hiddstub_mmakefile}"
        ${_aros_hiddstub_config_deps}
        ${AROS_HIDDSTUB_DEPENDS}
      COMMENT "Building native CMake HIDD stub ${_aros_hiddstub_name}"
      VERBATIM
    )

    list(APPEND _aros_hiddstub_objects "${_aros_hiddstub_output}")
  endforeach()

  add_custom_target("${target_name}" DEPENDS ${_aros_hiddstub_objects})
  _aros_set_target_folder_if_exists("${target_name}" "${_aros_hiddstub_internal_folder}")

  get_property(_aros_registered_hidd_stub_objects GLOBAL PROPERTY AROS_REGISTERED_HIDD_STUB_OBJECTS)
  list(APPEND _aros_registered_hidd_stub_objects ${_aros_hiddstub_objects})
  list(REMOVE_DUPLICATES _aros_registered_hidd_stub_objects)
  set_property(GLOBAL PROPERTY AROS_REGISTERED_HIDD_STUB_OBJECTS "${_aros_registered_hidd_stub_objects}")

  get_property(_aros_registered_hidd_stub_targets GLOBAL PROPERTY AROS_REGISTERED_HIDD_STUB_TARGETS)
  list(APPEND _aros_registered_hidd_stub_targets "${target_name}")
  list(REMOVE_DUPLICATES _aros_registered_hidd_stub_targets)
  set_property(GLOBAL PROPERTY AROS_REGISTERED_HIDD_STUB_TARGETS "${_aros_registered_hidd_stub_targets}")
endfunction()

function(aros_finalize_registered_hidd_stub_linklib)
  if(TARGET aros-compiler-hiddstubs-linklib-native)
    return()
  endif()

  get_property(_aros_hidd_stub_objects GLOBAL PROPERTY AROS_REGISTERED_HIDD_STUB_OBJECTS)
  get_property(_aros_hidd_stub_targets GLOBAL PROPERTY AROS_REGISTERED_HIDD_STUB_TARGETS)
  if(NOT _aros_hidd_stub_objects)
    return()
  endif()

  aros_register_archive_linklib(
    aros-compiler-hiddstubs-linklib-native
    MODULE_PATH compiler/libhiddstubs
    LIBNAME hiddstubs
    SDK private
    OBJECTS ${_aros_hidd_stub_objects}
    DEPENDS ${_aros_hidd_stub_targets}
  )
endfunction()

function(aros_finalize_module_interfaces)
  get_property(_aros_registered_interface_targets GLOBAL PROPERTY AROS_REGISTERED_MODULE_INTERFACE_TARGETS)

  foreach(_aros_interface_target IN LISTS _aros_registered_interface_targets)
    if(NOT TARGET "${_aros_interface_target}")
      continue()
    endif()

    get_target_property(_aros_staged_include_paths "${_aros_interface_target}" AROS_MODULE_STAGED_INCLUDE_PATHS)
    if(NOT _aros_staged_include_paths OR _aros_staged_include_paths STREQUAL "AROS_MODULE_STAGED_INCLUDE_PATHS-NOTFOUND")
      continue()
    endif()

    foreach(_aros_include_path IN LISTS _aros_staged_include_paths)
      _aros_sanitize_property_key("${_aros_include_path}" _aros_include_key)
      get_property(_aros_existing_target GLOBAL PROPERTY "AROS_STAGED_INCLUDE_TARGET_${_aros_include_key}")
      if(_aros_existing_target AND NOT _aros_existing_target STREQUAL "${_aros_interface_target}")
        message(FATAL_ERROR
          "Staged include collision for ${_aros_include_path}: "
          "${_aros_existing_target} vs ${_aros_interface_target}"
        )
      endif()
      set_property(
        GLOBAL
        PROPERTY "AROS_STAGED_INCLUDE_TARGET_${_aros_include_key}"
        "${_aros_interface_target}"
      )
    endforeach()
  endforeach()

  foreach(_aros_interface_target IN LISTS _aros_registered_interface_targets)
    if(NOT TARGET "${_aros_interface_target}")
      continue()
    endif()

    get_target_property(_aros_interface_dep_nodes "${_aros_interface_target}" AROS_MODULE_INTERFACE_DEPENDS)
    set(_aros_declared_interface_dep_targets)
    set(_aros_staged_interface_dep_targets)
    set(_aros_interface_dep_include_dirs)
    set(_aros_interface_dep_stamps)
    if(_aros_interface_dep_nodes AND NOT _aros_interface_dep_nodes STREQUAL "_aros_interface_dep_nodes-NOTFOUND")
      foreach(_aros_dep_node IN LISTS _aros_interface_dep_nodes)
        _aros_sanitize_property_key("${_aros_dep_node}" _aros_dep_key)
        get_property(_aros_dep_target GLOBAL PROPERTY "AROS_MODULE_INTERFACE_TARGET_${_aros_dep_key}")
        if(NOT _aros_dep_target OR _aros_dep_target STREQUAL "${_aros_interface_target}")
          continue()
        endif()
        if(TARGET "${_aros_dep_target}")
          list(APPEND _aros_declared_interface_dep_targets "${_aros_dep_target}")
        endif()
      endforeach()
    endif()

    get_target_property(_aros_source_include_paths "${_aros_interface_target}" AROS_SOURCE_INCLUDE_VIRTUAL_PATHS)
    if(_aros_source_include_paths AND NOT _aros_source_include_paths STREQUAL "AROS_SOURCE_INCLUDE_VIRTUAL_PATHS-NOTFOUND")
      foreach(_aros_source_include_path IN LISTS _aros_source_include_paths)
        _aros_sanitize_property_key("${_aros_source_include_path}" _aros_source_include_key)
        get_property(_aros_dep_target GLOBAL PROPERTY "AROS_STAGED_INCLUDE_TARGET_${_aros_source_include_key}")
        if(_aros_dep_target AND NOT _aros_dep_target STREQUAL "${_aros_interface_target}" AND TARGET "${_aros_dep_target}")
          list(APPEND _aros_staged_interface_dep_targets "${_aros_dep_target}")
        endif()
      endforeach()
    endif()

    set(_aros_interface_dep_targets
      ${_aros_declared_interface_dep_targets}
      ${_aros_staged_interface_dep_targets}
    )
    list(REMOVE_DUPLICATES _aros_declared_interface_dep_targets)
    list(REMOVE_DUPLICATES _aros_staged_interface_dep_targets)
    list(REMOVE_DUPLICATES _aros_interface_dep_targets)
    foreach(_aros_dep_target IN LISTS _aros_interface_dep_targets)
      get_target_property(
        _aros_dep_include_dirs
        "${_aros_dep_target}"
        AROS_MODULE_INTERFACE_INCLUDE_DIRS
      )
      if(_aros_dep_include_dirs AND NOT _aros_dep_include_dirs STREQUAL "AROS_MODULE_INTERFACE_INCLUDE_DIRS-NOTFOUND")
        list(APPEND _aros_interface_dep_include_dirs ${_aros_dep_include_dirs})
      endif()
      get_target_property(_aros_dep_stamp "${_aros_dep_target}" AROS_MODULE_INTERFACE_STAMP)
      if(_aros_dep_stamp AND NOT _aros_dep_stamp STREQUAL "AROS_MODULE_INTERFACE_STAMP-NOTFOUND")
        list(APPEND _aros_interface_dep_stamps "${_aros_dep_stamp}")
      endif()
      get_target_property(
        _aros_dep_stamp_deps
        "${_aros_dep_target}"
        AROS_MODULE_INTERFACE_DEPENDENCY_STAMPS
      )
      if(_aros_dep_stamp_deps AND NOT _aros_dep_stamp_deps STREQUAL "AROS_MODULE_INTERFACE_DEPENDENCY_STAMPS-NOTFOUND")
        list(APPEND _aros_interface_dep_stamps ${_aros_dep_stamp_deps})
      endif()
    endforeach()

    list(REMOVE_DUPLICATES _aros_interface_dep_include_dirs)
    _aros_filter_interface_include_dirs(_aros_interface_dep_include_dirs)
    list(REMOVE_DUPLICATES _aros_interface_dep_stamps)
    if(_aros_declared_interface_dep_targets)
      target_link_libraries("${_aros_interface_target}" INTERFACE ${_aros_declared_interface_dep_targets})
      add_dependencies("${_aros_interface_target}" ${_aros_declared_interface_dep_targets})
    endif()
    if(_aros_interface_dep_include_dirs)
      get_target_property(
        _aros_interface_include_dirs
        "${_aros_interface_target}"
        AROS_MODULE_INTERFACE_INCLUDE_DIRS
      )
      if(_aros_interface_include_dirs STREQUAL "AROS_MODULE_INTERFACE_INCLUDE_DIRS-NOTFOUND")
        set(_aros_interface_include_dirs)
      endif()
      list(APPEND _aros_interface_include_dirs ${_aros_interface_dep_include_dirs})
      list(REMOVE_DUPLICATES _aros_interface_include_dirs)
      _aros_filter_interface_include_dirs(_aros_interface_include_dirs)
      target_include_directories("${_aros_interface_target}" INTERFACE ${_aros_interface_dep_include_dirs})
      set_target_properties(
        "${_aros_interface_target}"
        PROPERTIES
          AROS_MODULE_INTERFACE_INCLUDE_DIRS "${_aros_interface_include_dirs}"
      )
    endif()
    set_target_properties(
      "${_aros_interface_target}"
      PROPERTIES
        AROS_MODULE_INTERFACE_DEPENDENCY_STAMPS "${_aros_interface_dep_stamps}"
    )

  endforeach()

  foreach(_aros_interface_target IN LISTS _aros_registered_interface_targets)
    if(NOT TARGET "${_aros_interface_target}")
      continue()
    endif()

    get_target_property(_aros_archive_dep_names "${_aros_interface_target}" AROS_MODULE_ARCHIVE_DEP_NAMES)
    if(NOT _aros_archive_dep_names OR _aros_archive_dep_names STREQUAL "AROS_MODULE_ARCHIVE_DEP_NAMES-NOTFOUND")
      continue()
    endif()

    _aros_collect_registered_archive_dependencies(
      _aros_late_archive_dep_files
      _aros_late_archive_dep_targets
      ${_aros_archive_dep_names}
    )

    get_target_property(_aros_archive_dep_files "${_aros_interface_target}" AROS_MODULE_ARCHIVE_DEP_FILES)
    if(_aros_archive_dep_files STREQUAL "AROS_MODULE_ARCHIVE_DEP_FILES-NOTFOUND")
      set(_aros_archive_dep_files)
    endif()
    get_target_property(_aros_archive_dep_targets "${_aros_interface_target}" AROS_MODULE_ARCHIVE_DEP_TARGETS)
    if(_aros_archive_dep_targets STREQUAL "AROS_MODULE_ARCHIVE_DEP_TARGETS-NOTFOUND")
      set(_aros_archive_dep_targets)
    endif()
    get_target_property(_aros_interface_owner_target "${_aros_interface_target}" AROS_MODULE_OWNER_TARGET)
    if(_aros_interface_owner_target STREQUAL "AROS_MODULE_OWNER_TARGET-NOTFOUND")
      set(_aros_interface_owner_target)
    endif()
    get_target_property(_aros_interface_owner_abi_target "${_aros_interface_target}" AROS_MODULE_OWNER_ABI_TARGET)
    if(_aros_interface_owner_abi_target STREQUAL "AROS_MODULE_OWNER_ABI_TARGET-NOTFOUND")
      set(_aros_interface_owner_abi_target)
    endif()

    if(_aros_late_archive_dep_targets)
      list(APPEND _aros_archive_dep_targets ${_aros_late_archive_dep_targets})
      list(REMOVE_ITEM _aros_archive_dep_targets "${_aros_interface_owner_target}" "${_aros_interface_owner_abi_target}")
      list(REMOVE_DUPLICATES _aros_archive_dep_targets)
    endif()
    if(_aros_late_archive_dep_files)
      list(APPEND _aros_archive_dep_files ${_aros_late_archive_dep_files})
      list(REMOVE_DUPLICATES _aros_archive_dep_files)
    endif()

    set_target_properties(
      "${_aros_interface_target}"
      PROPERTIES
        AROS_MODULE_ARCHIVE_DEP_FILES "${_aros_archive_dep_files}"
        AROS_MODULE_ARCHIVE_DEP_TARGETS "${_aros_archive_dep_targets}"
    )

  endforeach()

  get_property(_kobjs GLOBAL PROPERTY AROS_REGISTERED_KOBJ_TARGETS)
  foreach(_kobj IN LISTS _kobjs)
    get_target_property(_kobj_libs "${_kobj}" AROS_KOBJ_ARCHIVE_NAMES)
    _aros_collect_registered_archive_dependencies(_kobj_files _kobj_targets ${_kobj_libs})
    foreach(_dep IN LISTS _kobj_targets)
      get_target_property(_stamp "${_dep}" AROS_MODULE_INTERFACE_STAMP)
      if(_stamp AND NOT _stamp MATCHES "-NOTFOUND$")
        list(APPEND _kobj_files "${_stamp}")
      endif()
    endforeach()
    set_property(TARGET "${_kobj}" PROPERTY AROS_KOBJ_DEP_FILES "${_kobj_files}")
    if(_kobj_targets)
      add_dependencies("${_kobj}" ${_kobj_targets})
    endif()
  endforeach()

  _aros_finalize_registered_linklib_interfaces()
endfunction()

function(_aros_finalize_registered_linklib_interfaces)
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
