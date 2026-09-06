if(NOT DEFINED AROS_SOURCE_DIR
   OR NOT DEFINED AROS_BINARY_DIR
   OR NOT DEFINED AROS_CONFIG_BUILD_DIR
   OR NOT DEFINED AROS_TARGET
   OR NOT DEFINED AROS_GENMODULE
   OR NOT DEFINED AROS_TOOLCHAIN_DIR
   OR NOT DEFINED AROS_TOOLCHAIN_PREFIX
   OR NOT DEFINED AROS_SYSROOT
   OR NOT DEFINED AROS_NATIVE_INCLUDE_DIR
   OR NOT DEFINED AROS_NATIVE_PUBLIC_LIB_DIR
   OR NOT DEFINED AROS_NATIVE_PRIVATE_LIB_DIR
   OR NOT DEFINED AROS_NATIVE_REL_LIB_DIR
   OR NOT DEFINED AROS_NATIVE_BUILD_SDKS_DIR
   OR NOT DEFINED MODULE_PATH
   OR NOT DEFINED MODULE_NAME
   OR NOT DEFINED MODULE_TYPE
   OR NOT DEFINED MODULE_CONF
   OR NOT DEFINED MODULE_OUTPUT
   OR NOT DEFINED MODULE_GENERATED_DIR
   OR NOT DEFINED MODULE_OBJ_DIR)
  message(FATAL_ERROR "Missing required generic genmodule build parameters")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/AROSMmakeBuild.cmake")

function(_aros_read_generated_makefile_value pattern out_var)
  _aros_read_mmake_logical_lines("${MODULE_GENERATED_DIR}/Makefile.${MODULE_NAME}${MODULE_TYPE}" _generated_makefile_lines)
  set(_value)
  foreach(_generated_makefile_line IN LISTS _generated_makefile_lines)
    if(NOT _generated_makefile_line MATCHES "^${pattern}[ \t]*\\+=")
      continue()
    endif()
    string(REGEX REPLACE "^${pattern}[ \t]*\\+=[ \t]*" "" _generated_makefile_value "${_generated_makefile_line}")
    string(STRIP "${_generated_makefile_value}" _generated_makefile_value)
    if(_generated_makefile_value STREQUAL "")
      continue()
    endif()
    separate_arguments(_generated_makefile_value NATIVE_COMMAND "${_generated_makefile_value}")
    list(APPEND _value ${_generated_makefile_value})
  endforeach()
  set(${out_var} "${_value}" PARENT_SCOPE)
endfunction()

function(_aros_stage_generated_includes generated_includes)
  foreach(_generated_include IN LISTS generated_includes)
    set(_generated_src "${MODULE_GENERATED_DIR}/include/${_generated_include}")
    if(NOT EXISTS "${_generated_src}")
      message(FATAL_ERROR "Expected generated include not found: ${_generated_src}")
    endif()
    get_filename_component(_generated_dst "${_module_generated_include_root}/${_generated_include}" DIRECTORY)
    file(MAKE_DIRECTORY "${_generated_dst}")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
              "${_generated_src}"
              "${_module_generated_include_root}/${_generated_include}"
      RESULT_VARIABLE _copy_result
    )
    if(NOT _copy_result EQUAL 0)
      message(FATAL_ERROR "Failed staging generated include ${_generated_include}")
    endif()
  endforeach()
endfunction()

function(_aros_copy_header_file source_file source_root dest_root)
  if(NOT EXISTS "${source_file}" OR IS_DIRECTORY "${source_file}")
    return()
  endif()

  file(RELATIVE_PATH _copy_relpath "${source_root}" "${source_file}")
  if(_copy_relpath MATCHES "^\\.\\./" OR _copy_relpath STREQUAL "..")
    get_filename_component(_copy_relpath "${source_file}" NAME)
  endif()

  set(_dest_file "${dest_root}/${_copy_relpath}")
  get_filename_component(_dest_dir "${_dest_file}" DIRECTORY)
  file(MAKE_DIRECTORY "${_dest_dir}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${source_file}"
            "${_dest_file}"
    RESULT_VARIABLE _copy_result
  )
  if(NOT _copy_result EQUAL 0)
    message(FATAL_ERROR "Failed staging copied include ${source_file} -> ${_dest_file}")
  endif()
endfunction()

function(_aros_copy_matching_headers_recursive source_root dest_root)
  if(NOT IS_DIRECTORY "${source_root}")
    return()
  endif()

  file(GLOB_RECURSE _header_files
    RELATIVE "${source_root}"
    "${source_root}/*.h"
    "${source_root}/*.hpp"
  )
  foreach(_header_rel IN LISTS _header_files)
    _aros_copy_header_file("${source_root}/${_header_rel}" "${source_root}" "${dest_root}")
  endforeach()
endfunction()

function(_aros_stage_copy_includes_from_mmake mmakefile_path)
  if(NOT EXISTS "${mmakefile_path}")
    return()
  endif()

  set(_allowed_copy_targets ${ARGN})
  get_filename_component(_mmake_dir "${mmakefile_path}" DIRECTORY)
  _aros_set_make_context_for_file("${mmakefile_path}" "${MODULE_PATH}")
  _aros_read_mmake_logical_lines("${mmakefile_path}" _logical_lines)

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
    set(_copy_sdk "")
    set(_copy_includes "")
    set(_copy_mmake_target "")
    foreach(_arg IN LISTS _copy_args)
      if(_arg MATCHES "^dir=(.*)$")
        set(_copy_dir "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^path=(.*)$")
        set(_copy_path "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^sdk=(.*)$")
        set(_copy_sdk "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^includes=(.*)$")
        set(_copy_includes "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^mmake=(.*)$")
        set(_copy_mmake_target "${CMAKE_MATCH_1}")
      endif()
    endforeach()

    if(_allowed_copy_targets)
      if(_copy_mmake_target STREQUAL "")
        continue()
      endif()
      list(FIND _allowed_copy_targets "${_copy_mmake_target}" _allowed_copy_index)
      if(_allowed_copy_index EQUAL -1)
        continue()
      endif()
    endif()

    if(IS_ABSOLUTE "${_copy_dir}")
      set(_source_root "${_copy_dir}")
    else()
      set(_source_root "${_mmake_dir}/${_copy_dir}")
    endif()

    if(_copy_sdk AND NOT _copy_sdk STREQUAL "public")
      set(_include_root "${AROS_NATIVE_BUILD_SDKS_DIR}/${_copy_sdk}/include")
    else()
      set(_include_root "${AROS_NATIVE_INCLUDE_DIR}")
    endif()

    if(_copy_path STREQUAL "." OR _copy_path STREQUAL "")
      set(_dest_root "${_include_root}")
    else()
      set(_dest_root "${_include_root}/${_copy_path}")
    endif()

    if(_copy_includes STREQUAL "" AND DEFINED _AROS_MMAKE_VAR_INCLUDE_FILES)
      set(_copy_includes "${_AROS_MMAKE_VAR_INCLUDE_FILES}")
    endif()

    if(_copy_includes STREQUAL "")
      _aros_copy_matching_headers_recursive("${_source_root}" "${_dest_root}")
      continue()
    endif()

    separate_arguments(_copy_include_entries NATIVE_COMMAND "${_copy_includes}")
    set(_copied_explicit_include FALSE)
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

      if(_include_source STREQUAL "")
        continue()
      endif()
      _aros_copy_header_file("${_include_source}" "${_source_root}" "${_dest_root}")
      set(_copied_explicit_include TRUE)
    endforeach()

    if(NOT _copied_explicit_include)
      _aros_copy_matching_headers_recursive("${_source_root}" "${_dest_root}")
    endif()
  endforeach()
endfunction()

function(_aros_stage_reachable_copy_includes_targets)
  set(_active_targets ${ARGN})
  list(REMOVE_DUPLICATES _active_targets)
  if(NOT _active_targets)
    return()
  endif()

  file(GLOB_RECURSE _all_mmakefiles LIST_DIRECTORIES false "${AROS_SOURCE_DIR}/*/mmakefile.src")
  foreach(_candidate_mmakefile IN LISTS _all_mmakefiles)
    file(STRINGS "${_candidate_mmakefile}" _copy_lines REGEX "^%copy_includes ")
    if(NOT _copy_lines)
      continue()
    endif()

    set(_has_matching_copy_target FALSE)
    foreach(_copy_line IN LISTS _copy_lines)
      foreach(_active_target IN LISTS _active_targets)
        if(_copy_line MATCHES "(^|[ \t])mmake=${_active_target}([ \t]|$)")
          set(_has_matching_copy_target TRUE)
          break()
        endif()
      endforeach()
      if(_has_matching_copy_target)
        break()
      endif()
    endforeach()

    if(_has_matching_copy_target)
      _aros_stage_copy_includes_from_mmake("${_candidate_mmakefile}" ${_active_targets})
    endif()
  endforeach()
endfunction()

_aros_decode_list(MODULE_INCLUDE_DIRS)
_aros_decode_list(MODULE_COMPILE_DEFINITIONS)
_aros_decode_list(MODULE_COMPILE_OPTIONS)
_aros_decode_list(MODULE_LINK_OPTIONS)
_aros_decode_list(MODULE_LINK_LIBS)
_aros_decode_list(MODULE_AUTO_LINK_LIBS)
_aros_decode_list(MODULE_EXPECTED_ARCHIVE_DEPS)
_aros_remove_empty_entries(MODULE_INCLUDE_DIRS)
set(_module_source_dir "${AROS_SOURCE_DIR}/${MODULE_PATH}")
list(REMOVE_ITEM MODULE_INCLUDE_DIRS "${_module_source_dir}")
if(DEFINED AROS_NATIVE_INCLUDE_DIR AND NOT AROS_NATIVE_INCLUDE_DIR STREQUAL "")
  # The flat public include root is appended later on purpose. If it stays in
  # MODULE_INCLUDE_DIRS, generated private sources can resolve public headers
  # like native-includes/lddemon.h before module-local private headers.
  list(REMOVE_ITEM MODULE_INCLUDE_DIRS "${AROS_NATIVE_INCLUDE_DIR}")
endif()
_aros_remove_empty_entries(MODULE_COMPILE_DEFINITIONS)
_aros_remove_empty_entries(MODULE_COMPILE_OPTIONS)
_aros_remove_empty_entries(MODULE_LINK_OPTIONS)
_aros_remove_empty_entries(MODULE_LINK_LIBS)
_aros_remove_empty_entries(MODULE_AUTO_LINK_LIBS)
_aros_remove_empty_entries(MODULE_EXPECTED_ARCHIVE_DEPS)
_aros_read_config_tokens("CONFIG_CPPFLAGS" _module_config_cppflags)
_aros_read_config_tokens("CONFIG_AFLAGS" _module_config_aflags)
_aros_read_config_tokens("TARGET_ISA_CFLAGS" _module_target_isa_cflags)
_aros_read_config_tokens("MODULE_ISA_CFLAGS" _module_isa_cflags)
_aros_read_config_tokens("OPTIMIZATION_CFLAGS" _module_target_optimization_cflags)
_aros_read_config_tokens("CFLAGS_NO_OMIT_FP" _module_target_base_cflags)
_aros_read_config_tokens("SAFETY_CFLAGS" _module_target_safety_cflags)
_aros_read_config_tokens("TARGET_ISA_LDFLAGS" _module_target_isa_ldflags)
_aros_read_config_tokens("TARGET_C_LIBS" _module_target_c_libs)
_aros_read_config_tokens("NOSTARTUP_LDFLAGS" _module_nostartup_ldflags)
_aros_read_config_tokens("NOSTDLIB_LDFLAGS" _module_nostdlib_ldflags)
_aros_read_config_tokens("NOSTARTUP_OBJECTS" _module_nostartup_objects)
_aros_read_config_tokens("AR_PLAIN" _module_ar)
_aros_read_config_tokens("RANLIB" _module_ranlib)
_aros_find_toolchain_program("ar" _module_ar_fallback)
_aros_find_toolchain_program("ranlib" _module_ranlib_fallback)
set(MODULE_RESOLVED_LAYER_MMAKEFILES)
set(MODULE_RESOLVED_LAYERS)
set(MODULE_RESOLVED_REACHABLE_ALIASES)
if(DEFINED MODULE_MMAKEFILE AND NOT MODULE_MMAKEFILE STREQUAL "")
  if((NOT DEFINED MODULE_MMAKE_NAME OR MODULE_MMAKE_NAME STREQUAL "") AND EXISTS "${MODULE_MMAKEFILE}")
    aros_layering_extract_primary_mmake_name("${MODULE_MMAKEFILE}" MODULE_MMAKE_NAME)
  endif()
  get_filename_component(_module_dir_name "${MODULE_PATH}" NAME)
  if(DEFINED MODULE_MMAKE_NAME AND NOT MODULE_MMAKE_NAME STREQUAL "")
    aros_layering_collect_resolved_module_layer_mmakefiles(
      "${_module_dir_name}"
      "${MODULE_MMAKE_NAME}"
      MODULE_RESOLVED_LAYER_MMAKEFILES
      MODULE_RESOLVED_LAYERS
      MODULE_RESOLVED_REACHABLE_ALIASES
    )
  endif()
endif()
if(DEFINED MODULE_MMAKEFILE AND NOT MODULE_MMAKEFILE STREQUAL "")
  _aros_parse_mmake_module("${MODULE_MMAKEFILE}")
  set(_module_mmake_files "${MODULE_MMAKE_PARSED_FILES}")
  set(_module_mmake_user_cppflags "${MODULE_MMAKE_PARSED_USER_CPPFLAGS}")
  set(_module_mmake_user_includes "${MODULE_MMAKE_PARSED_USER_INCLUDES}")
  set(_module_mmake_user_ldflags "${MODULE_MMAKE_PARSED_USER_LDFLAGS}")
  set(_module_mmake_user_cflags "${MODULE_MMAKE_PARSED_USER_CFLAGS}")
  set(_module_mmake_user_aflags "${MODULE_MMAKE_PARSED_USER_AFLAGS}")
  set(_module_mmake_optimization_cflags "${MODULE_MMAKE_PARSED_OPTIMIZATION_CFLAGS}")
  set(_module_mmake_uselibs "${MODULE_MMAKE_PARSED_USELIBS}")
  set(_module_mmake_linklibfiles "${MODULE_MMAKE_PARSED_LINKLIBFILES}")
  set(_module_mmake_linklibobjs "${MODULE_MMAKE_PARSED_LINKLIBOBJS}")
  set(_module_mmake_usesdks "${MODULE_MMAKE_PARSED_USESDKS}")
  set(_module_mmake_version "${MODULE_MMAKE_PARSED_VERSION}")
  if(NOT MODULE_SUFFIX)
    set(MODULE_SUFFIX "${MODULE_MMAKE_PARSED_MODSUFFIX}")
  endif()
  set(_module_mmake_resident_begin "${MODULE_MMAKE_PARSED_RESIDENT_BEGIN}")
  set(_module_mmake_active_targets "${MODULE_MMAKE_PARSED_ACTIVE_TARGETS}")

  _aros_debug_var(MODULE_MMAKE_PARSED_FILES)
  if((NOT DEFINED MODULE_BASE_SOURCES OR MODULE_BASE_SOURCES STREQUAL "") AND _module_mmake_files)
    set(MODULE_BASE_SOURCES "${_module_mmake_files}")
  endif()
  _aros_remove_empty_entries(MODULE_BASE_SOURCES)
  _aros_remove_token_entries(MODULE_BASE_SOURCES "\\")
  _aros_debug_var(MODULE_MMAKE_PARSED_USESDKS)
  set(_module_base_compile_options
    ${_module_mmake_user_cppflags}
    ${_module_mmake_user_includes}
    ${_module_mmake_user_cflags}
    ${_module_mmake_user_aflags}
    ${_module_mmake_optimization_cflags}
  )
  list(APPEND MODULE_LINK_OPTIONS ${_module_mmake_user_ldflags})
  list(APPEND MODULE_LINK_LIBS ${_module_mmake_uselibs})

  foreach(_sdk IN LISTS _module_mmake_usesdks)
    list(APPEND MODULE_COMPILE_OPTIONS "-I${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/${_sdk}/include")
    list(APPEND MODULE_COMPILE_OPTIONS "-I${AROS_NATIVE_BUILD_SDKS_DIR}/${_sdk}/include")
    list(APPEND MODULE_LINK_OPTIONS "-L${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/${_sdk}/lib")
    list(APPEND MODULE_LINK_OPTIONS "-L${AROS_NATIVE_BUILD_SDKS_DIR}/${_sdk}/lib")
  endforeach()

  if((NOT DEFINED MODULE_VERSION_EXTRA OR MODULE_VERSION_EXTRA STREQUAL "") AND DEFINED _module_mmake_version)
    set(MODULE_VERSION_EXTRA "${_module_mmake_version}")
  endif()

  get_filename_component(_module_dir_name "${MODULE_PATH}" NAME)
  set(_module_base_source_stems)
  foreach(_module_base_source IN LISTS MODULE_BASE_SOURCES)
    get_filename_component(_module_base_stem "${_module_base_source}" NAME_WE)
    list(APPEND _module_base_source_stems "${_module_base_stem}")
  endforeach()

  set(_module_layer_mmakefiles "${MODULE_RESOLVED_LAYER_MMAKEFILES}")
  set(_module_layers "${MODULE_RESOLVED_LAYERS}")
  set(MODULE_LAYER_SOURCE_FLAG_SPECS)
  if(NOT _module_layer_mmakefiles)
    _aros_get_active_layers(_module_active_layers)
    foreach(_module_layer IN LISTS _module_active_layers)
      set(_module_layer_mmakefile "${AROS_SOURCE_DIR}/arch/${_module_layer}/${_module_dir_name}/mmakefile.src")
      if(EXISTS "${_module_layer_mmakefile}")
        list(APPEND _module_layer_mmakefiles "${_module_layer_mmakefile}")
        list(APPEND _module_layers "${_module_layer}")
      endif()
    endforeach()
  endif()

  list(LENGTH _module_layer_mmakefiles _module_layer_count)
  if(_module_layer_count GREATER 0)
    math(EXPR _module_layer_last_index "${_module_layer_count} - 1")
    foreach(_module_layer_index RANGE 0 ${_module_layer_last_index})
      list(GET _module_layer_mmakefiles ${_module_layer_index} _module_layer_mmakefile)
      list(GET _module_layers ${_module_layer_index} _module_layer)

      list(APPEND MODULE_LAYER_MANIFEST_LAYERS "${_module_layer}")
      _aros_parse_mmake_module("${_module_layer_mmakefile}")
      if(DEFINED AROS_GENMODULE_DEBUG AND AROS_GENMODULE_DEBUG)
        message(STATUS "Layer ${_module_layer} arch files: ${MODULE_MMAKE_PARSED_ARCH_FILES}")
        message(STATUS "Layer ${_module_layer} asm files: ${MODULE_MMAKE_PARSED_ARCH_ASMFILES}")
      endif()

      set(_module_layer_source_c_compile_args)
      set(_module_layer_source_asm_compile_args)
      list(APPEND MODULE_LINK_OPTIONS ${MODULE_MMAKE_PARSED_USER_LDFLAGS})

      foreach(_sdk IN LISTS MODULE_MMAKE_PARSED_ARCH_USESDKS)
        list(APPEND _module_layer_source_c_compile_args "-I${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/${_sdk}/include")
        list(APPEND _module_layer_source_c_compile_args "-I${AROS_NATIVE_BUILD_SDKS_DIR}/${_sdk}/include")
        list(APPEND _module_layer_source_asm_compile_args "-I${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/${_sdk}/include")
        list(APPEND _module_layer_source_asm_compile_args "-I${AROS_NATIVE_BUILD_SDKS_DIR}/${_sdk}/include")
        list(APPEND MODULE_LINK_OPTIONS "-L${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/${_sdk}/lib")
        list(APPEND MODULE_LINK_OPTIONS "-L${AROS_NATIVE_BUILD_SDKS_DIR}/${_sdk}/lib")
      endforeach()
      _aros_remove_empty_entries(_module_layer_source_c_compile_args)
      _aros_remove_empty_entries(_module_layer_source_asm_compile_args)

      foreach(_layer_source IN LISTS MODULE_MMAKE_PARSED_ARCH_FILES MODULE_MMAKE_PARSED_ARCH_ASMFILES)
        get_filename_component(_layer_source_stem "${_layer_source}" NAME_WE)
        list(FIND _module_base_source_stems "${_layer_source_stem}" _layer_source_override_index)
        if(_layer_source_override_index EQUAL -1)
          list(APPEND MODULE_LAYER_ADDITIONS "${_module_layer}:${_layer_source}")
        else()
          list(APPEND MODULE_LAYER_OVERRIDES "${_module_layer}:${_layer_source}")
        endif()

        list(FIND MODULE_MMAKE_PARSED_ARCH_ASMFILES "${_layer_source}" _layer_source_asm_index)
        if(_layer_source_asm_index EQUAL -1)
          set(_module_layer_source_compile_args "${_module_layer_source_c_compile_args}")
        else()
          set(_module_layer_source_compile_args "${_module_layer_source_asm_compile_args}")
        endif()
        if(_module_layer_source_compile_args)
          _aros_encode_token_list("${_module_layer_source_compile_args}" _module_layer_source_compile_args_string)
          list(APPEND MODULE_LAYER_SOURCE_FLAG_SPECS
            "${_module_layer}:${_layer_source}|${_module_layer_source_compile_args_string}"
          )
        endif()

        foreach(_layer_source_flag_spec IN LISTS MODULE_MMAKE_PARSED_ARCH_SOURCE_FLAG_SPECS)
          string(REPLACE "|" ";" _layer_source_flag_parts "${_layer_source_flag_spec}")
          list(LENGTH _layer_source_flag_parts _layer_source_flag_len)
          if(_layer_source_flag_len LESS 2)
            continue()
          endif()
          list(GET _layer_source_flag_parts 0 _layer_source_flag_name)
          list(REMOVE_AT _layer_source_flag_parts 0)
          string(REPLACE ";" "|" _layer_source_flag_value "${_layer_source_flag_parts}")
          if(NOT _layer_source STREQUAL "${_layer_source_flag_name}")
            continue()
          endif()
          list(APPEND MODULE_LAYER_SOURCE_FLAG_SPECS
            "${_module_layer}:${_layer_source}|${_layer_source_flag_value}"
          )
        endforeach()
      endforeach()

      list(APPEND _module_mmake_linklibfiles ${MODULE_MMAKE_PARSED_ARCH_LINKLIBFILES})
      list(APPEND _module_mmake_linklibobjs ${MODULE_MMAKE_PARSED_ARCH_LINKLIBOBJS})
    endforeach()
    list(REMOVE_DUPLICATES MODULE_LAYER_MANIFEST_LAYERS)
    list(REMOVE_DUPLICATES MODULE_LAYER_SOURCE_FLAG_SPECS)
  endif()
  _aros_debug_var(MODULE_LAYER_MANIFEST_LAYERS)
  _aros_debug_var(MODULE_LAYER_OVERRIDES)
  _aros_debug_var(MODULE_LAYER_ADDITIONS)
  _aros_debug_var(MODULE_LAYER_SOURCE_FLAG_SPECS)
endif()
_aros_collect_layer_makeopts("USER_CPPFLAGS" _module_layer_cppflags)
_aros_collect_layer_makeopts("USER_INCLUDES" _module_layer_includes)
_aros_collect_layer_makeopts("USER_LDFLAGS" _module_layer_ldflags)
_aros_remove_empty_entries(_module_config_cppflags)
_aros_remove_empty_entries(_module_config_aflags)
_aros_remove_empty_entries(_module_target_isa_cflags)
_aros_remove_empty_entries(_module_isa_cflags)
_aros_remove_empty_entries(_module_target_optimization_cflags)
_aros_remove_empty_entries(_module_target_base_cflags)
_aros_remove_empty_entries(_module_target_safety_cflags)
_aros_remove_empty_entries(_module_layer_cppflags)
_aros_remove_empty_entries(_module_layer_includes)
_aros_remove_empty_entries(_module_layer_ldflags)
list(REMOVE_DUPLICATES MODULE_LINK_LIBS)

_aros_find_toolchain_program("gcc" _module_cc)
_aros_find_toolchain_program("strip" _module_strip)

set(_module_generated_include_root "${AROS_NATIVE_INCLUDE_DIR}")
if(DEFINED MODULE_SDK
   AND NOT MODULE_SDK STREQUAL ""
   AND NOT MODULE_SDK STREQUAL "public")
  set(_module_generated_include_root "${AROS_NATIVE_BUILD_SDKS_DIR}/${MODULE_SDK}/include")
endif()
file(MAKE_DIRECTORY "${_module_generated_include_root}")

set(_module_ar_path "")
if(_module_ar)
  list(GET _module_ar 0 _module_ar_path)
endif()
if((NOT _module_ar OR "${_module_ar_path}" STREQUAL "" OR NOT EXISTS "${_module_ar_path}") AND _module_ar_fallback)
  set(_module_ar "${_module_ar_fallback}")
endif()

set(_module_ranlib_path "")
if(_module_ranlib)
  list(GET _module_ranlib 0 _module_ranlib_path)
endif()
if((NOT _module_ranlib OR "${_module_ranlib_path}" STREQUAL "" OR NOT EXISTS "${_module_ranlib_path}") AND _module_ranlib_fallback)
  set(_module_ranlib "${_module_ranlib_fallback}")
endif()

if(NOT EXISTS "${AROS_GENMODULE}")
  message(FATAL_ERROR "genmodule executable not found: ${AROS_GENMODULE}")
endif()
if(NOT _module_cc)
  message(FATAL_ERROR
    "Target compiler for ${MODULE_PATH} is missing under ${AROS_TOOLCHAIN_DIR}. "
    "Expected ${AROS_TOOLCHAIN_PREFIX}-gcc in either the toolchain root or its bin/ directory."
  )
endif()
if(NOT _module_ar)
  message(FATAL_ERROR "Target ar was not resolved from target.cfg")
endif()
if(NOT _module_ranlib)
  message(FATAL_ERROR "Target ranlib was not resolved from target.cfg")
endif()
_aros_compiler_builtin_include_dir("${_module_cc}" _module_compiler_include_dir)

file(MAKE_DIRECTORY "${MODULE_GENERATED_DIR}")
file(MAKE_DIRECTORY "${MODULE_GENERATED_DIR}/linklib")
file(MAKE_DIRECTORY "${MODULE_GENERATED_DIR}/include")
file(MAKE_DIRECTORY "${MODULE_OBJ_DIR}")
get_filename_component(_module_output_dir "${MODULE_OUTPUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_module_output_dir}")

set(_genmodule_common_args
  -c "${MODULE_CONF}"
  -d "${MODULE_GENERATED_DIR}"
  -l "${MODULE_GENERATED_DIR}/linklib"
)
if(DEFINED MODULE_SUFFIX AND NOT MODULE_SUFFIX STREQUAL "")
  list(APPEND _genmodule_common_args -s "${MODULE_SUFFIX}")
endif()
if(DEFINED MODULE_VERSION_EXTRA AND NOT MODULE_VERSION_EXTRA STREQUAL "")
  list(APPEND _genmodule_common_args -v "${MODULE_VERSION_EXTRA}")
endif()
foreach(_genmodule_cmd IN ITEMS writemakefile writefiles writelibdefs)
  execute_process(
    COMMAND "${AROS_GENMODULE}" ${_genmodule_common_args} "${_genmodule_cmd}" "${MODULE_NAME}" "${MODULE_TYPE}"
    RESULT_VARIABLE _genmodule_result
  )
  if(NOT _genmodule_result EQUAL 0)
    message(FATAL_ERROR "genmodule ${_genmodule_cmd} failed for ${MODULE_PATH}")
  endif()
endforeach()

_aros_read_generated_makefile_value("${MODULE_NAME}_INCLUDES" _module_generated_includes)
if(_module_generated_includes)
  set(_module_generated_include_dirs "${MODULE_GENERATED_DIR}/include")
  foreach(_generated_include IN LISTS _module_generated_includes)
    get_filename_component(_generated_include_dir "${MODULE_GENERATED_DIR}/include/${_generated_include}" DIRECTORY)
    list(APPEND _module_generated_include_dirs "${_generated_include_dir}")
  endforeach()
  list(REMOVE_DUPLICATES _module_generated_include_dirs)
  foreach(_generated_include_dir IN LISTS _module_generated_include_dirs)
    file(MAKE_DIRECTORY "${_generated_include_dir}")
  endforeach()
  execute_process(
    COMMAND "${AROS_GENMODULE}"
            -c "${MODULE_CONF}"
            -d "${MODULE_GENERATED_DIR}/include"
            writeincludes "${MODULE_NAME}" "${MODULE_TYPE}"
    RESULT_VARIABLE _genmodule_includes_result
  )
  if(NOT _genmodule_includes_result EQUAL 0)
    message(FATAL_ERROR "genmodule writeincludes failed for ${MODULE_PATH}")
  endif()
  _aros_stage_generated_includes("${_module_generated_includes}")
endif()

if(DEFINED MODULE_MMAKEFILE AND NOT MODULE_MMAKEFILE STREQUAL "")
  _aros_stage_copy_includes_from_mmake("${MODULE_MMAKEFILE}")
endif()
foreach(_layer_mmakefile IN LISTS MODULE_RESOLVED_LAYER_MMAKEFILES)
  _aros_stage_copy_includes_from_mmake("${_layer_mmakefile}")
endforeach()
if(DEFINED _module_mmake_active_targets AND NOT _module_mmake_active_targets STREQUAL "")
  _aros_stage_reachable_copy_includes_targets(${_module_mmake_active_targets})
endif()

_aros_read_generated_makefile_value("${MODULE_NAME}_STARTFILES" _module_start_files)
_aros_read_generated_makefile_value("${MODULE_NAME}_ENDFILES" _module_end_files)
_aros_read_generated_makefile_value("${MODULE_NAME}_LINKLIBFILES" _module_generated_linklib_files)
_aros_read_generated_makefile_value("${MODULE_NAME}_RELLINKLIBFILES" _module_generated_rellinklib_files)
_aros_read_generated_makefile_value("${MODULE_NAME}_LINKLIBAFILES" _module_generated_linklib_afiles)
_aros_read_generated_makefile_value("${MODULE_NAME}_RELLINKLIBAFILES" _module_generated_rellinklib_afiles)
_aros_read_generated_makefile_value("${MODULE_NAME}_CPPFLAGS" _module_generated_cppflags)
_aros_read_generated_makefile_value("${MODULE_NAME}_CFLAGS" _module_generated_cflags)
_aros_read_generated_makefile_value("${MODULE_NAME}_LINKLIBCPPFLAGS" _module_generated_linklib_cppflags)
_aros_read_generated_makefile_value("${MODULE_NAME}_LINKLIBCFLAGS" _module_generated_linklib_cflags)
# SDK interfaces depend on declarations and stub sources, not on downloaded or
# generated implementation sources that are only needed for the runtime module.
set(_module_sources)
if(NOT INTERFACE_ONLY)
  _aros_resolve_module_sources(_module_sources)
endif()
_aros_remove_empty_entries(_module_start_files)
_aros_remove_empty_entries(_module_end_files)
_aros_remove_empty_entries(_module_sources)
_aros_remove_empty_entries(_module_generated_linklib_files)
_aros_remove_empty_entries(_module_generated_rellinklib_files)
_aros_remove_empty_entries(_module_generated_linklib_afiles)
_aros_remove_empty_entries(_module_generated_rellinklib_afiles)
_aros_remove_empty_entries(_module_generated_cppflags)
_aros_remove_empty_entries(_module_generated_cflags)
_aros_remove_empty_entries(_module_generated_linklib_cppflags)
_aros_remove_empty_entries(_module_generated_linklib_cflags)
_aros_remove_empty_entries(_module_generated_entrypoint_flags)
_aros_debug_var(_module_start_files)
_aros_debug_var(_module_end_files)
_aros_debug_var(_module_sources)
set(_module_generated_start_sources)
foreach(_module_start_file IN LISTS _module_start_files)
  set(_module_generated_start_source "${MODULE_GENERATED_DIR}/${_module_start_file}.c")
  if(EXISTS "${_module_generated_start_source}")
    list(APPEND _module_generated_start_sources "${_module_generated_start_source}")
  endif()
endforeach()

set(_module_generated_start_uses_autoinit FALSE)
set(_module_generated_start_uses_libinit FALSE)
set(_module_generated_start_handles_libs FALSE)
set(_module_generated_linklib_uses_library_handling FALSE)
foreach(_module_generated_start_source IN LISTS _module_generated_start_sources)
  file(STRINGS "${_module_generated_start_source}" _module_generated_start_autoinit_lines
    REGEX
      "set_open_libraries\\(|set_call_funcs\\(|set_call_devfuncs\\(|__showerror\\b|THIS_PROGRAM_HANDLES_SYMBOLSET\\((LIBS|RELLIBS|INIT|EXIT|PROGRAM_ENTRIES|CTORS|DTORS|INIT_ARRAY|FINI_ARRAY)\\)|DECLARESET\\((LIBS|RELLIBS|INIT|EXIT|PROGRAM_ENTRIES|CTORS|DTORS|INIT_ARRAY|FINI_ARRAY)\\)|AROS_USERFUNC_(INIT|EXIT)"
  )
  if(_module_generated_start_autoinit_lines)
    set(_module_generated_start_uses_autoinit TRUE)
  endif()

  file(STRINGS "${_module_generated_start_source}" _module_generated_start_libinit_lines
    REGEX
      "set_call_libfuncs\\(|THIS_PROGRAM_HANDLES_SYMBOLSET\\((INITLIB|OPENLIB|CLOSELIB|EXPUNGELIB)\\)|DECLARESET\\((INITLIB|OPENLIB|CLOSELIB|EXPUNGELIB)\\)|AROS_(LIB|DEV)FUNC_(INIT|EXIT)"
  )
  if(_module_generated_start_libinit_lines)
    set(_module_generated_start_uses_libinit TRUE)
  endif()

  file(STRINGS "${_module_generated_start_source}" _module_generated_start_libs_lines
    REGEX
      "THIS_PROGRAM_HANDLES_SYMBOLSET\\(LIBS\\)|DECLARESET\\(LIBS\\)"
  )
  if(_module_generated_start_libs_lines)
    set(_module_generated_start_handles_libs TRUE)
  endif()

  if(_module_generated_start_uses_autoinit
     AND _module_generated_start_uses_libinit
     AND _module_generated_start_handles_libs)
    break()
  endif()
endforeach()
foreach(_generated_linklib_source IN LISTS _module_generated_linklib_files)
  set(_generated_linklib_source_path "${MODULE_GENERATED_DIR}/linklib/${_generated_linklib_source}.c")
  if(NOT EXISTS "${_generated_linklib_source_path}")
    continue()
  endif()

  file(STRINGS "${_generated_linklib_source_path}" _module_generated_linklib_library_handling_lines
    REGEX "__includelibrarieshandling"
  )
  if(_module_generated_linklib_library_handling_lines)
    set(_module_generated_linklib_uses_library_handling TRUE)
    break()
  endif()
endforeach()
set(_module_deflibdefs "${MODULE_GENERATED_DIR}/include/${MODULE_NAME}_deflibdefs.h")
file(WRITE "${_module_deflibdefs}" "#define LC_LIBDEFS_FILE \"${MODULE_GENERATED_DIR}/${MODULE_NAME}_libdefs.h\"\n")


# Build each surface from its own inputs. Subtracting individual base tokens
# breaks shared option names such as -isystem and leaves their operands behind.
_aros_module_compile_args(TRUE _common_compile_args)
_aros_module_compile_args(FALSE _layer_source_compile_args_template)
_aros_debug_var(_common_compile_args)

_aros_prefer_host_headers("${_common_compile_args}" _hosted_layer_compile_args)
_aros_prefer_host_headers("${_layer_source_compile_args_template}" _hosted_layer_source_compile_args_template)
# A module can request host headers for all of its sources, including generated
# startup/linklib sources, rather than only for architecture overrides.
_aros_mmake_uses_kernel_includes("${_module_mmake_user_includes}" _module_uses_host_headers)
if(_module_uses_host_headers)
  set(_common_compile_args ${_hosted_layer_compile_args})
  set(_layer_source_compile_args_template ${_hosted_layer_source_compile_args_template})
endif()

file(MAKE_DIRECTORY "${MODULE_OBJ_DIR}/linklib")

set(_module_linklib_compile_args ${_common_compile_args})
list(APPEND _module_linklib_compile_args ${_module_generated_linklib_cppflags})
list(APPEND _module_linklib_compile_args ${_module_generated_linklib_cflags})

set(_common_asm_compile_args ${_common_compile_args})
list(APPEND _common_asm_compile_args ${_module_config_aflags})
list(APPEND _common_asm_compile_args ${_module_mmake_user_aflags})

_aros_prefer_host_headers("${_common_asm_compile_args}" _hosted_layer_asm_compile_args)

set(_layer_asm_source_compile_args_template ${_layer_source_compile_args_template} ${_module_config_aflags})
_aros_prefer_host_headers("${_layer_asm_source_compile_args_template}" _hosted_layer_asm_source_compile_args_template)

if(DEFINED MODULE_SUFFIX AND NOT MODULE_SUFFIX STREQUAL "")
  set(_module_linklib_suffix ".${MODULE_SUFFIX}")
elseif(MODULE_TYPE STREQUAL "library")
  set(_module_linklib_suffix "")
else()
  set(_module_linklib_suffix ".${MODULE_TYPE}")
endif()

set(_module_public_linklib "${AROS_NATIVE_PUBLIC_LIB_DIR}/lib${MODULE_NAME}${_module_linklib_suffix}.a")
if(_module_generated_rellinklib_files OR _module_generated_rellinklib_afiles)
  set(_module_rel_linklib "${AROS_NATIVE_REL_LIB_DIR}/lib${MODULE_NAME}_rel${_module_linklib_suffix}.a")
else()
  set(_module_rel_linklib "")
endif()

if(DEFINED INTERFACE_ONLY AND INTERFACE_ONLY)
  set(_module_common_linklib_objects)
  foreach(_manual_linklib_source IN LISTS _module_mmake_linklibfiles)
    _aros_resolve_source_candidate("${AROS_SOURCE_DIR}/${MODULE_PATH}" "${_manual_linklib_source}" _resolved_linklib_source)
    if(NOT _resolved_linklib_source)
      message(FATAL_ERROR "Could not resolve linklib source '${_manual_linklib_source}' under ${MODULE_PATH}")
    endif()
    string(REPLACE "/" "_" _manual_linklib_obj_name "${_manual_linklib_source}")
    get_filename_component(_manual_linklib_obj_base "${_manual_linklib_obj_name}" NAME_WE)
    set(_manual_linklib_object "${MODULE_OBJ_DIR}/linklib/${_manual_linklib_obj_base}.o")
    execute_process(
      COMMAND "${_module_cc}" ${_module_linklib_compile_args} -c "${_resolved_linklib_source}" -o "${_manual_linklib_object}"
      RESULT_VARIABLE _compile_result
    )
    if(NOT _compile_result EQUAL 0)
      message(FATAL_ERROR "Failed compiling ${_resolved_linklib_source}")
    endif()
    list(APPEND _module_common_linklib_objects "${_manual_linklib_object}")
  endforeach()
  list(APPEND _module_common_linklib_objects ${_module_mmake_linklibobjs})
  _aros_remove_empty_entries(_module_common_linklib_objects)

  set(_module_public_linklib_objects ${_module_common_linklib_objects})
  foreach(_generated_linklib_source IN LISTS _module_generated_linklib_files)
    set(_generated_linklib_path "${MODULE_GENERATED_DIR}/linklib/${_generated_linklib_source}.c")
    set(_generated_linklib_object "${MODULE_OBJ_DIR}/linklib/${_generated_linklib_source}.o")
    execute_process(
      COMMAND "${_module_cc}" ${_module_linklib_compile_args} -c "${_generated_linklib_path}" -o "${_generated_linklib_object}"
      RESULT_VARIABLE _compile_result
    )
    if(NOT _compile_result EQUAL 0)
      message(FATAL_ERROR "Failed compiling ${_generated_linklib_path}")
    endif()
    list(APPEND _module_public_linklib_objects "${_generated_linklib_object}")
  endforeach()
  foreach(_generated_linklib_asm_source IN LISTS _module_generated_linklib_afiles)
    set(_generated_linklib_asm_path "${MODULE_GENERATED_DIR}/linklib/${_generated_linklib_asm_source}.S")
    set(_generated_linklib_asm_object "${MODULE_OBJ_DIR}/linklib/${_generated_linklib_asm_source}.o")
    execute_process(
      COMMAND "${_module_cc}" -x assembler-with-cpp ${_module_linklib_compile_args} -c "${_generated_linklib_asm_path}" -o "${_generated_linklib_asm_object}"
      RESULT_VARIABLE _compile_result
    )
    if(NOT _compile_result EQUAL 0)
      message(FATAL_ERROR "Failed compiling ${_generated_linklib_asm_path}")
    endif()
    list(APPEND _module_public_linklib_objects "${_generated_linklib_asm_object}")
  endforeach()
  _aros_remove_empty_entries(_module_public_linklib_objects)

  if(_module_public_linklib_objects)
    file(MAKE_DIRECTORY "${AROS_NATIVE_PUBLIC_LIB_DIR}")
    execute_process(
      COMMAND ${_module_ar} cr "${_module_public_linklib}" ${_module_public_linklib_objects}
      RESULT_VARIABLE _module_ar_result
    )
    if(NOT _module_ar_result EQUAL 0)
      message(FATAL_ERROR "Failed archiving ${_module_public_linklib}")
    endif()
    execute_process(
      COMMAND ${_module_ranlib} "${_module_public_linklib}"
      RESULT_VARIABLE _module_ranlib_result
    )
    if(NOT _module_ranlib_result EQUAL 0)
      message(FATAL_ERROR "Failed indexing ${_module_public_linklib}")
    endif()
  endif()

  set(_module_rel_linklib_objects ${_module_common_linklib_objects})
  foreach(_generated_rellinklib_source IN LISTS _module_generated_rellinklib_files)
    set(_generated_rellinklib_path "${MODULE_GENERATED_DIR}/linklib/${_generated_rellinklib_source}.c")
    set(_generated_rellinklib_object "${MODULE_OBJ_DIR}/linklib/${_generated_rellinklib_source}.o")
    execute_process(
      COMMAND "${_module_cc}" ${_module_linklib_compile_args} -c "${_generated_rellinklib_path}" -o "${_generated_rellinklib_object}"
      RESULT_VARIABLE _compile_result
    )
    if(NOT _compile_result EQUAL 0)
      message(FATAL_ERROR "Failed compiling ${_generated_rellinklib_path}")
    endif()
    list(APPEND _module_rel_linklib_objects "${_generated_rellinklib_object}")
  endforeach()
  foreach(_generated_rellinklib_asm_source IN LISTS _module_generated_rellinklib_afiles)
    set(_generated_rellinklib_asm_path "${MODULE_GENERATED_DIR}/linklib/${_generated_rellinklib_asm_source}.S")
    set(_generated_rellinklib_asm_object "${MODULE_OBJ_DIR}/linklib/${_generated_rellinklib_asm_source}.o")
    execute_process(
      COMMAND "${_module_cc}" -x assembler-with-cpp ${_module_linklib_compile_args} -c "${_generated_rellinklib_asm_path}" -o "${_generated_rellinklib_asm_object}"
      RESULT_VARIABLE _compile_result
    )
    if(NOT _compile_result EQUAL 0)
      message(FATAL_ERROR "Failed compiling ${_generated_rellinklib_asm_path}")
    endif()
    list(APPEND _module_rel_linklib_objects "${_generated_rellinklib_asm_object}")
  endforeach()
  _aros_remove_empty_entries(_module_rel_linklib_objects)

  if(_module_rel_linklib_objects AND _module_generated_rellinklib_files)
    file(MAKE_DIRECTORY "${AROS_NATIVE_REL_LIB_DIR}")
    execute_process(
      COMMAND ${_module_ar} cr "${_module_rel_linklib}" ${_module_rel_linklib_objects}
      RESULT_VARIABLE _module_ar_result
    )
    if(NOT _module_ar_result EQUAL 0)
      message(FATAL_ERROR "Failed archiving ${_module_rel_linklib}")
    endif()
    execute_process(
      COMMAND ${_module_ranlib} "${_module_rel_linklib}"
      RESULT_VARIABLE _module_ranlib_result
    )
    if(NOT _module_ranlib_result EQUAL 0)
      message(FATAL_ERROR "Failed indexing ${_module_rel_linklib}")
    endif()
  endif()

  return()
endif()

set(_module_missing_expected_archives)
foreach(_expected_archive IN LISTS MODULE_EXPECTED_ARCHIVE_DEPS)
  if(NOT EXISTS "${_expected_archive}")
    list(APPEND _module_missing_expected_archives "${_expected_archive}")
  endif()
endforeach()
if(_module_missing_expected_archives)
  string(REPLACE ";" "\n  " _module_missing_expected_archives_formatted "${_module_missing_expected_archives}")
  message(FATAL_ERROR
    "Missing expected native archive dependencies for ${MODULE_PATH}:\n"
    "  ${_module_missing_expected_archives_formatted}\n"
    "Run the build through the generated Ninja/CMake target graph so these archives are staged first."
  )
endif()

set(_module_start_objects)
if(NOT DEFINED _module_mmake_resident_begin OR _module_mmake_resident_begin STREQUAL "")
  set(_module_mmake_resident_begin "compiler/libinit/libentry")
endif()
if(NOT MODULE_TYPE STREQUAL "handler")
  _aros_resolve_source_candidate("${AROS_SOURCE_DIR}" "${_module_mmake_resident_begin}" _module_resident_begin_source)
  if(_module_resident_begin_source)
    set(_module_resident_begin_object "${MODULE_OBJ_DIR}/__resident_begin.o")
    execute_process(
      COMMAND "${_module_cc}" ${_common_compile_args} -c "${_module_resident_begin_source}" -o "${_module_resident_begin_object}"
      RESULT_VARIABLE _compile_result
    )
    if(NOT _compile_result EQUAL 0)
      message(FATAL_ERROR "Failed compiling ${_module_resident_begin_source}")
    endif()
    list(APPEND _module_start_objects "${_module_resident_begin_object}")
  endif()
endif()
foreach(_generated_source IN LISTS _module_start_files)
  set(_source "${MODULE_GENERATED_DIR}/${_generated_source}.c")
  set(_object "${MODULE_OBJ_DIR}/${_generated_source}.o")
  execute_process(
    COMMAND "${_module_cc}" ${_common_compile_args} -c "${_source}" -o "${_object}"
    RESULT_VARIABLE _compile_result
  )
  if(NOT _compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_source}")
  endif()
  list(APPEND _module_start_objects "${_object}")
endforeach()

set(_module_objects)
foreach(_source IN LISTS _module_sources)
  get_filename_component(_basename "${_source}" NAME_WE)
  get_filename_component(_source_ext "${_source}" EXT)
  set(_object "${MODULE_OBJ_DIR}/${_basename}.o")
  set(_source_is_layer FALSE)
  string(FIND "${_source}" "${AROS_SOURCE_DIR}/arch/" _source_arch_index)
  if(_source_arch_index EQUAL 0)
    set(_source_is_layer TRUE)
    string(FIND "${_source}" "${AROS_SOURCE_DIR}/${MODULE_PATH}/" _source_module_root_index)
    if(_source_module_root_index EQUAL 0)
      set(_source_is_layer FALSE)
    endif()
  endif()

  set(_source_compile_args ${_common_compile_args})
  if(_source_is_layer)
    set(_source_compile_args ${_layer_source_compile_args_template})
  endif()
  if(_source_is_layer AND _source MATCHES "/arch/(all-(unix|hosted)|[^/]+-(unix|hosted))/")
    set(_source_compile_args ${_hosted_layer_source_compile_args_template})
  endif()
  if(_source_ext STREQUAL ".s" OR _source_ext STREQUAL ".S")
    set(_source_compile_args ${_common_asm_compile_args})
    if(_source_is_layer)
      set(_source_compile_args ${_layer_asm_source_compile_args_template})
    endif()
    if(_source_is_layer AND _source MATCHES "/arch/(all-(unix|hosted)|[^/]+-(unix|hosted))/")
      set(_source_compile_args ${_hosted_layer_asm_source_compile_args_template})
    endif()
  endif()
  set(_source_extra_compile_args)
  foreach(_layer_source_flag_spec IN LISTS MODULE_LAYER_SOURCE_FLAG_SPECS)
    string(REPLACE "|" ";" _layer_source_flag_parts "${_layer_source_flag_spec}")
    list(LENGTH _layer_source_flag_parts _layer_source_flag_len)
    if(_layer_source_flag_len LESS 2)
      continue()
    endif()
    list(GET _layer_source_flag_parts 0 _layer_source_key)
    list(REMOVE_AT _layer_source_flag_parts 0)
    string(REPLACE ";" " " _layer_source_flag_value "${_layer_source_flag_parts}")
    string(REPLACE ":" ";" _layer_source_key_parts "${_layer_source_key}")
    list(LENGTH _layer_source_key_parts _layer_source_key_len)
    if(_layer_source_key_len LESS 2)
      continue()
    endif()
    list(GET _layer_source_key_parts 0 _layer_source_layer)
    list(REMOVE_AT _layer_source_key_parts 0)
    string(REPLACE ";" ":" _layer_source_name "${_layer_source_key_parts}")
    _aros_resolve_layer_source_candidate(
      "${AROS_SOURCE_DIR}/arch/${_layer_source_layer}/${_module_dir_name}"
      "${_layer_source_name}"
      _layer_source_flag_path
    )
    if(NOT _source STREQUAL "${_layer_source_flag_path}")
      continue()
    endif()
    _aros_decode_token_list("${_layer_source_flag_value}" _layer_source_extra_compile_args)
    list(APPEND _source_extra_compile_args ${_layer_source_extra_compile_args})
  endforeach()
  _aros_merge_source_compile_args("${_source_compile_args}" "${_source_extra_compile_args}" _source_compile_args)
  if(DEFINED AROS_GENMODULE_DEBUG AND AROS_GENMODULE_DEBUG)
    message(STATUS "Compile args for ${_source}: ${_source_compile_args}")
  endif()
  if(_source_ext STREQUAL ".s" OR _source_ext STREQUAL ".S")
    execute_process(
      COMMAND "${_module_cc}" -x assembler-with-cpp ${_source_compile_args} -c "${_source}" -o "${_object}"
      RESULT_VARIABLE _compile_result
    )
  else()
    execute_process(
      COMMAND "${_module_cc}" ${_source_compile_args} -c "${_source}" -o "${_object}"
      RESULT_VARIABLE _compile_result
    )
  endif()
  if(NOT _compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_source}")
  endif()
  list(APPEND _module_objects "${_object}")
endforeach()

set(_module_end_objects)
foreach(_generated_source IN LISTS _module_end_files)
  set(_source "${MODULE_GENERATED_DIR}/${_generated_source}.c")
  set(_object "${MODULE_OBJ_DIR}/${_generated_source}.o")
  execute_process(
    COMMAND "${_module_cc}" ${_common_compile_args} -c "${_source}" -o "${_object}"
    RESULT_VARIABLE _compile_result
  )
  if(NOT _compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_source}")
  endif()
  list(APPEND _module_end_objects "${_object}")
endforeach()
_aros_remove_empty_entries(_module_start_objects)
_aros_remove_empty_entries(_module_objects)
_aros_remove_empty_entries(_module_end_objects)
set(_module_link_objects ${_module_start_objects} ${_module_objects} ${_module_end_objects})
# Kickstart objects omit the stand-alone module entry and runtime-only markers.
set(_module_kobj_objects ${_module_link_objects})
if(_module_resident_begin_object)
  list(REMOVE_ITEM _module_kobj_objects "${_module_resident_begin_object}")
endif()
if(NOT _module_generated_start_uses_autoinit)
  # Hand-written noresident startup paths can still pull objects that use
  # ADD2INIT() without linking the full init/exit runtime. Provide the marker
  # symbol weakly so those modules link without forcing initexitsets.o in.
  set(_module_init_symbol_marker_source "${MODULE_OBJ_DIR}/__init_symbolset_marker.c")
  set(_module_init_symbol_marker_object "${MODULE_OBJ_DIR}/__init_symbolset_marker.o")
  file(WRITE "${_module_init_symbol_marker_source}"
    "int __INIT__symbol_set_handler_missing __attribute__((weak));\n"
  )
  execute_process(
    COMMAND "${_module_cc}" ${_common_compile_args} -c "${_module_init_symbol_marker_source}" -o "${_module_init_symbol_marker_object}"
    RESULT_VARIABLE _module_init_symbol_marker_compile_result
  )
  if(NOT _module_init_symbol_marker_compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_module_init_symbol_marker_source}")
  endif()
  list(APPEND _module_link_objects "${_module_init_symbol_marker_object}")
endif()
if(_module_generated_linklib_uses_library_handling AND NOT _module_generated_start_handles_libs)
  # Some genmodule noautolib paths still emit *_autoinit linklib stubs that
  # pull in autoinit's library-handling entrypoints without declaring the LIBS
  # symbolset in the generated startup. Mirror the weak-marker fallback used
  # for INIT so these modules can link without forcing full autolib handling on.
  set(_module_libs_symbol_marker_source "${MODULE_OBJ_DIR}/__libs_symbolset_marker.c")
  set(_module_libs_symbol_marker_object "${MODULE_OBJ_DIR}/__libs_symbolset_marker.o")
  file(WRITE "${_module_libs_symbol_marker_source}"
    "int __LIBS__symbol_set_handler_missing __attribute__((weak));\n"
  )
  execute_process(
    COMMAND "${_module_cc}" ${_common_compile_args} -c "${_module_libs_symbol_marker_source}" -o "${_module_libs_symbol_marker_object}"
    RESULT_VARIABLE _module_libs_symbol_marker_compile_result
  )
  if(NOT _module_libs_symbol_marker_compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_module_libs_symbol_marker_source}")
  endif()
  list(APPEND _module_link_objects "${_module_libs_symbol_marker_object}")
endif()
_aros_remove_empty_entries(_module_link_objects)
_aros_remove_empty_entries(_module_target_isa_ldflags)
_aros_remove_empty_entries(_module_target_c_libs)
_aros_remove_empty_entries(_module_nostartup_ldflags)
_aros_remove_empty_entries(_module_nostdlib_ldflags)
_aros_remove_empty_entries(_module_nostartup_objects)
_aros_remove_empty_entries(_module_layer_ldflags)
set(_module_compiler_runtime_libs)
if(_module_nostdlib_ldflags)
  execute_process(
    COMMAND "${_module_cc}" -print-libgcc-file-name
    RESULT_VARIABLE _module_libgcc_result
    OUTPUT_VARIABLE _module_libgcc
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(_module_libgcc_result EQUAL 0 AND IS_ABSOLUTE "${_module_libgcc}" AND EXISTS "${_module_libgcc}")
    list(APPEND _module_compiler_runtime_libs "${_module_libgcc}")
  endif()
endif()
_aros_remove_empty_entries(_module_compiler_runtime_libs)
set(_module_runtime_self_linklibs)
if(EXISTS "${_module_public_linklib}" AND (_module_generated_linklib_files OR _module_generated_linklib_afiles OR _module_mmake_linklibfiles OR _module_mmake_linklibobjs))
  list(APPEND _module_runtime_self_linklibs "${_module_public_linklib}")
endif()
_aros_remove_empty_entries(_module_runtime_self_linklibs)
_aros_collect_existing_public_linklibs(_module_available_auto_link_libs ${MODULE_AUTO_LINK_LIBS})
set(_module_manual_link_libs)
foreach(_manual_link_lib IN LISTS MODULE_LINK_LIBS)
  if(_manual_link_lib STREQUAL "")
    continue()
  endif()
  list(FIND _module_available_auto_link_libs "${_manual_link_lib}" _manual_link_lib_auto_index)
  if(_manual_link_lib_auto_index EQUAL -1)
    list(APPEND _module_manual_link_libs "${_manual_link_lib}")
  endif()
endforeach()

set(_module_effective_link_libs ${_module_manual_link_libs})
list(APPEND _module_effective_link_libs ${_module_available_auto_link_libs})
list(REMOVE_DUPLICATES _module_effective_link_libs)
list(FIND _module_effective_link_libs "exec" _module_exec_link_index)
list(FIND _module_mmake_uselibs "autoinit" _module_autoinit_explicit_index)
if(NOT _module_generated_start_uses_autoinit
   AND _module_autoinit_explicit_index EQUAL -1
   AND _module_exec_link_index EQUAL -1)
  list(REMOVE_ITEM _module_effective_link_libs autoinit)
endif()
_aros_debug_var(_module_objects)
_aros_debug_var(_module_link_objects)
_aros_debug_var(_module_manual_link_libs)
_aros_debug_var(_module_available_auto_link_libs)
_aros_debug_var(_module_effective_link_libs)
_aros_debug_var(_module_compiler_runtime_libs)
_aros_debug_var(_module_runtime_self_linklibs)

# Keep the legacy-like startup/autolib cycle grouped, but leave the rest of
# the auto-link chain ordered normally. Grouping every available library pulls
# in extra stdlib/crt bodies and breaks parity for modules like uuid.library.
set(_module_core_group_link_libs
  arossupport
  amiga
  exec
  autoinit
  libinit
)
set(_module_grouped_link_libs)
set(_module_ungrouped_link_libs)
foreach(_effective_lib IN LISTS _module_effective_link_libs)
  if(_effective_lib IN_LIST _module_core_group_link_libs)
    list(APPEND _module_grouped_link_libs "${_effective_lib}")
  else()
    list(APPEND _module_ungrouped_link_libs "${_effective_lib}")
  endif()
endforeach()
_aros_debug_var(_module_grouped_link_libs)
_aros_debug_var(_module_ungrouped_link_libs)

get_filename_component(_module_native_sysroot "${AROS_NATIVE_PUBLIC_LIB_DIR}" DIRECTORY)
set(_link_command
  "${_module_cc}"
  "--sysroot=${_module_native_sysroot}"
)
list(APPEND _link_command ${_module_target_isa_ldflags})
list(APPEND _link_command ${_module_nostartup_ldflags})
list(APPEND _link_command ${_module_nostdlib_ldflags})
list(APPEND _link_command ${_module_nostartup_objects})
list(APPEND _link_command ${_module_link_objects})
list(APPEND _link_command -o "${MODULE_OUTPUT}")
list(APPEND _link_command "-L${AROS_NATIVE_PUBLIC_LIB_DIR}")
list(APPEND _link_command "-L${AROS_NATIVE_PRIVATE_LIB_DIR}")
list(APPEND _link_command "-L${AROS_NATIVE_REL_LIB_DIR}")
list(APPEND _link_command ${_module_layer_ldflags})
list(APPEND _link_command ${MODULE_LINK_OPTIONS})
# The resident function table retains implementation symbols. Forcing the
# public entrypoint names instead can pull in self-calling linklib stubs when
# a .conf declaration maps a public name to a different implementation.
list(APPEND _link_command ${_module_runtime_self_linklibs})
foreach(_lib IN LISTS _module_ungrouped_link_libs)
  list(APPEND _link_command "-l${_lib}")
endforeach()
if(_module_grouped_link_libs OR _module_target_c_libs OR _module_compiler_runtime_libs)
  list(APPEND _link_command "-Wl,--start-group")
endif()
foreach(_lib IN LISTS _module_grouped_link_libs)
  list(APPEND _link_command "-l${_lib}")
endforeach()
list(APPEND _link_command ${_module_target_c_libs})
list(APPEND _link_command ${_module_compiler_runtime_libs})
if(_module_grouped_link_libs OR _module_target_c_libs OR _module_compiler_runtime_libs)
  list(APPEND _link_command "-Wl,--end-group")
endif()
_aros_debug_var(_link_command)
if(MODULE_LINK_MANIFEST)
  _aros_read_generated_makefile_value("${MODULE_NAME}_LIBS" _module_generated_libs)
  set(_module_kobj_libs ${_module_mmake_uselibs})
  list(REMOVE_ITEM _module_kobj_libs hiddstubs amiga arossupport autoinit libinit stdc.static)
  list(APPEND _module_kobj_libs dos intuition layers graphics oop utility expansion keymap ${_module_generated_libs})
  set(_module_kobj_ldflags ${_module_mmake_user_ldflags})
  list(REMOVE_ITEM _module_kobj_ldflags -noclibs)
  file(WRITE "${MODULE_LINK_MANIFEST}" "# Generated module link inputs.\n")
  foreach(_variable IN ITEMS
      AROS_SOURCE_DIR AROS_CONFIG_BUILD_DIR AROS_TARGET AROS_TOOLCHAIN_DIR AROS_TOOLCHAIN_PREFIX
      AROS_NATIVE_CONFIG_FILE
      AROS_NATIVE_PUBLIC_LIB_DIR AROS_NATIVE_PRIVATE_LIB_DIR AROS_NATIVE_REL_LIB_DIR
      MODULE_OUTPUT _link_command _module_strip _module_kobj_objects _module_kobj_libs _module_kobj_ldflags)
    file(APPEND "${MODULE_LINK_MANIFEST}" "set(${_variable} [==[${${_variable}}]==])\n")
  endforeach()
else()
  include("${CMAKE_CURRENT_LIST_DIR}/link_genmodule_module.cmake")
endif()
