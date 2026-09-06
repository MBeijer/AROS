if(NOT DEFINED AROS_SOURCE_DIR
   OR NOT DEFINED AROS_BINARY_DIR
   OR NOT DEFINED AROS_CONFIG_BUILD_DIR
   OR NOT DEFINED AROS_TARGET
   OR NOT DEFINED AROS_NATIVE_INCLUDE_DIR
   OR NOT DEFINED AROS_HOST_CC
   OR NOT DEFINED AROS_TARGET_CC)
  message(FATAL_ERROR "Missing required native include staging parameters")
endif()

function(_aros_resolve_target_cc out_var)
  if(AROS_TARGET_CC AND EXISTS "${AROS_TARGET_CC}")
    set(${out_var} "${AROS_TARGET_CC}" PARENT_SCOPE)
    return()
  endif()

  string(REPLACE "-" ";" _target_parts "${AROS_TARGET}")
  list(LENGTH _target_parts _target_parts_len)
  if(_target_parts_len GREATER 1)
    list(GET _target_parts 1 _target_cpu)
  else()
    set(_target_cpu "")
  endif()

  set(_toolchain_prefix "")
  if(DEFINED AROS_TARGET_TOOLCHAIN_PREFIX AND NOT AROS_TARGET_TOOLCHAIN_PREFIX STREQUAL "")
    set(_toolchain_prefix "${AROS_TARGET_TOOLCHAIN_PREFIX}")
  elseif(_target_cpu)
    set(_toolchain_prefix "${_target_cpu}-aros")
  endif()

  set(_toolchain_dirs)
  if(DEFINED AROS_TARGET_TOOLCHAIN_DIR AND NOT AROS_TARGET_TOOLCHAIN_DIR STREQUAL "")
    list(APPEND _toolchain_dirs "${AROS_TARGET_TOOLCHAIN_DIR}")
  endif()
  list(APPEND _toolchain_dirs
    "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/tools/crosstools"
    "${AROS_BINARY_DIR}/bin/${AROS_TARGET}/tools/crosstools"
  )
  list(REMOVE_DUPLICATES _toolchain_dirs)

  if(_toolchain_prefix)
    foreach(_toolchain_dir IN LISTS _toolchain_dirs)
      foreach(_candidate IN ITEMS
          "${_toolchain_dir}/bin/${_toolchain_prefix}-gcc"
          "${_toolchain_dir}/${_toolchain_prefix}-gcc")
        if(EXISTS "${_candidate}")
          set(${out_var} "${_candidate}" PARENT_SCOPE)
          return()
        endif()
      endforeach()
    endforeach()
  endif()

  set(${out_var} "" PARENT_SCOPE)
endfunction()

function(_aros_copy_directory_contents src_dir dst_dir)
  if(NOT IS_DIRECTORY "${src_dir}")
    return()
  endif()
  file(MAKE_DIRECTORY "${dst_dir}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${src_dir}" "${dst_dir}"
    RESULT_VARIABLE _copy_result
  )
  if(NOT _copy_result EQUAL 0)
    message(FATAL_ERROR "Failed copying include tree ${src_dir} -> ${dst_dir}")
  endif()
endfunction()

function(_aros_copy_files_to_dir dst_dir)
  file(MAKE_DIRECTORY "${dst_dir}")
  foreach(_src IN LISTS ARGN)
    if(NOT EXISTS "${_src}")
      continue()
    endif()
    get_filename_component(_name "${_src}" NAME)
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_src}" "${dst_dir}/${_name}"
      RESULT_VARIABLE _copy_result
    )
    if(NOT _copy_result EQUAL 0)
      message(FATAL_ERROR "Failed copying include file ${_src} -> ${dst_dir}/${_name}")
    endif()
  endforeach()
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

  set(_target_cfg "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg")
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

function(_aros_append_dir_if_exists list_var dir_path)
  set(_dirs "${${list_var}}")
  if(IS_DIRECTORY "${dir_path}")
    list(APPEND _dirs "${dir_path}")
  endif()
  set(${list_var} "${_dirs}" PARENT_SCOPE)
endfunction()

function(_aros_append_file_if_exists list_var file_path)
  set(_files "${${list_var}}")
  if(EXISTS "${file_path}")
    list(APPEND _files "${file_path}")
  endif()
  set(${list_var} "${_files}" PARENT_SCOPE)
endfunction()

function(_aros_collect_arch_include_mmakefiles out_var)
  _aros_get_target_context(_arch _cpu _variant _family)

  set(_mmakefiles)

  set(_cpu_all_include_mmake "${AROS_SOURCE_DIR}/arch/${_cpu}-all/include/mmakefile.src")
  if(EXISTS "${_cpu_all_include_mmake}")
    file(STRINGS "${_cpu_all_include_mmake}" _support_lines REGEX "compiler-includes-[A-Za-z0-9_\\-]+")
    foreach(_line IN LISTS _support_lines)
      string(REGEX MATCHALL "compiler-includes-([A-Za-z0-9_\\-]+)" _matches "${_line}")
      foreach(_match IN LISTS _matches)
        string(REGEX REPLACE "^compiler-includes-" "" _support_name "${_match}")
        if(_support_name STREQUAL "${_cpu}" OR _support_name STREQUAL "${_arch}" OR _support_name STREQUAL "${_family}")
          continue()
        endif()
        _aros_append_file_if_exists(_mmakefiles "${AROS_SOURCE_DIR}/arch/all-${_support_name}/include/mmakefile.src")
      endforeach()
    endforeach()
  endif()

  foreach(_candidate IN ITEMS
      "${AROS_SOURCE_DIR}/arch/all-${_family}/include/mmakefile.src"
      "${AROS_SOURCE_DIR}/arch/all-${_arch}/include/mmakefile.src"
      "${AROS_SOURCE_DIR}/arch/${_cpu}-${_family}/include/mmakefile.src"
      "${AROS_SOURCE_DIR}/arch/${_cpu}-${_arch}/include/mmakefile.src"
      "${AROS_SOURCE_DIR}/arch/${_cpu}-all/include/mmakefile.src")
    _aros_append_file_if_exists(_mmakefiles "${_candidate}")
  endforeach()

  list(REMOVE_DUPLICATES _mmakefiles)
  set(${out_var} "${_mmakefiles}" PARENT_SCOPE)
endfunction()

function(_aros_copy_matching_files src_dir dst_dir)
  if(NOT IS_DIRECTORY "${src_dir}")
    return()
  endif()

  file(MAKE_DIRECTORY "${dst_dir}")
  file(GLOB _header_files
    RELATIVE "${src_dir}"
    "${src_dir}/*.h"
    "${src_dir}/*.hpp"
  )
  foreach(_header IN LISTS _header_files)
    get_filename_component(_header_name "${_header}" NAME)
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
              "${src_dir}/${_header}"
              "${dst_dir}/${_header_name}"
      RESULT_VARIABLE _copy_result
    )
    if(NOT _copy_result EQUAL 0)
      message(FATAL_ERROR "Failed copying staged include ${src_dir}/${_header} -> ${dst_dir}/${_header_name}")
    endif()
  endforeach()
endfunction()

function(_aros_publish_root_include_alias source_relative_path alias_name)
  set(_source_path "${AROS_NATIVE_INCLUDE_DIR}/${source_relative_path}")
  if(NOT EXISTS "${_source_path}")
    return()
  endif()

  set(_dest_path "${AROS_NATIVE_INCLUDE_DIR}/${alias_name}")
  file(RELATIVE_PATH _source_link_target
    "${AROS_NATIVE_INCLUDE_DIR}"
    "${_source_path}"
  )
  if(EXISTS "${_dest_path}" OR IS_SYMLINK "${_dest_path}")
    return()
  endif()
  file(CREATE_LINK "${_source_link_target}" "${_dest_path}" SYMBOLIC COPY_ON_ERROR)
endfunction()

function(_aros_stage_copy_includes_mmake mmakefile_path)
  if(NOT EXISTS "${mmakefile_path}")
    return()
  endif()

  get_filename_component(_mmake_dir "${mmakefile_path}" DIRECTORY)
  file(STRINGS "${mmakefile_path}" _copy_lines REGEX "^%copy_includes ")
  foreach(_line IN LISTS _copy_lines)
    string(REGEX REPLACE "^%copy_includes[ \t]+" "" _args_string "${_line}")
    separate_arguments(_args NATIVE_COMMAND "${_args_string}")

    set(_copy_dir "")
    set(_copy_path ".")
    foreach(_arg IN LISTS _args)
      if(_arg MATCHES "^dir=(.*)$")
        set(_copy_dir "${CMAKE_MATCH_1}")
      elseif(_arg MATCHES "^path=(.*)$")
        set(_copy_path "${CMAKE_MATCH_1}")
      endif()
    endforeach()

    if(_copy_dir STREQUAL "")
      set(_copy_dir ".")
    endif()

    if(IS_ABSOLUTE "${_copy_dir}")
      set(_source_dir "${_copy_dir}")
    else()
      set(_source_dir "${_mmake_dir}/${_copy_dir}")
    endif()

    if(_copy_path STREQUAL "." OR _copy_path STREQUAL "")
      set(_dest_dir "${AROS_NATIVE_INCLUDE_DIR}")
    else()
      set(_dest_dir "${AROS_NATIVE_INCLUDE_DIR}/${_copy_path}")
    endif()
    _aros_copy_matching_files("${_source_dir}" "${_dest_dir}")
  endforeach()
endfunction()

function(_aros_generate_execbase_header)
  set(_execbase_src "${AROS_SOURCE_DIR}/compiler/include/exec/execbase.inc")
  if(NOT EXISTS "${_execbase_src}")
    return()
  endif()

  set(_execbase_dir "${AROS_NATIVE_INCLUDE_DIR}/exec")
  file(MAKE_DIRECTORY "${_execbase_dir}")

  set(_execbase_out "${_execbase_dir}/execbase.h")
  file(READ "${_execbase_src}" _execbase_content)

  set(_smpready FALSE)
  set(_geninc_cfg "${AROS_CONFIG_BUILD_DIR}/compiler/include/geninc.cfg")
  if(EXISTS "${_geninc_cfg}")
    file(STRINGS "${_geninc_cfg}" _smp_lines REGEX "^SMPREADY=")
    foreach(_smp_line IN LISTS _smp_lines)
      if(_smp_line MATCHES "__AROSPLATFORM_SMP__")
        set(_smpready TRUE)
        break()
      endif()
    endforeach()
  elseif(EXISTS "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/include/aros/config.h")
    file(STRINGS "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/include/aros/config.h"
      _config_smp_lines REGEX "__AROSPLATFORM_SMP__")
    if(_config_smp_lines)
      set(_smpready TRUE)
    endif()
  endif()

  if(_smpready)
    string(REGEX REPLACE "[^\r\n]*ThisTask;[^\r\n]*" "    IPTR         Private1;" _execbase_content "${_execbase_content}")
    string(REGEX REPLACE "[^\r\n]*Quantum;[^\r\n]*" "    UWORD        Private2;" _execbase_content "${_execbase_content}")
    string(REGEX REPLACE "[^\r\n]*Elapsed;[^\r\n]*" "    UWORD        Private3;" _execbase_content "${_execbase_content}")
    string(REGEX REPLACE "[^\r\n]*IDNestCnt;[^\r\n]*" "    BYTE         Private4;" _execbase_content "${_execbase_content}")
    string(REGEX REPLACE "[^\r\n]*TDNestCnt;[^\r\n]*" "    BYTE         Private5;" _execbase_content "${_execbase_content}")
  endif()

  file(WRITE "${_execbase_out}" "${_execbase_content}")
endfunction()

function(_aros_generate_arch_libcall_header)
  _aros_get_target_context(_arch _cpu _variant _family)
  set(_gencall_source "${AROS_SOURCE_DIR}/arch/${_cpu}-all/include/gencall.c")
  if(NOT EXISTS "${_gencall_source}")
    return()
  endif()

  set(_gencall_root "${AROS_BINARY_DIR}/native-include-tools")
  set(_gencall_exe "${_gencall_root}/gencall_${_cpu}")
  set(_gencall_out_dir "${AROS_NATIVE_INCLUDE_DIR}/aros/${_cpu}")
  file(MAKE_DIRECTORY "${_gencall_root}")
  file(MAKE_DIRECTORY "${_gencall_out_dir}")

  execute_process(
    COMMAND "${AROS_HOST_CC}" -Wall -Werror -o "${_gencall_exe}" "${_gencall_source}"
    RESULT_VARIABLE _compile_result
  )
  if(NOT _compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_gencall_source}")
  endif()

  execute_process(
    COMMAND "${_gencall_exe}"
    OUTPUT_FILE "${_gencall_out_dir}/libcall.h"
    RESULT_VARIABLE _run_result
  )
  if(NOT _run_result EQUAL 0)
    message(FATAL_ERROR "Failed generating ${_gencall_out_dir}/libcall.h")
  endif()
endfunction()

function(_aros_generate_arch_asm_header)
  _aros_get_target_context(_arch _cpu _variant _family)
  set(_asm_source "${AROS_SOURCE_DIR}/compiler/include/asm.c")
  if(NOT EXISTS "${_asm_source}")
    return()
  endif()
  _aros_resolve_target_cc(_aros_target_cc)
  if(NOT _aros_target_cc)
    message(FATAL_ERROR "Target compiler not found for asm.h generation")
  endif()

  set(_asm_gen_root "${AROS_BINARY_DIR}/native-include-tools")
  set(_asm_out_dir "${AROS_NATIVE_INCLUDE_DIR}/aros/${_cpu}")
  set(_asm_s "${_asm_gen_root}/asm_${_cpu}.s")
  file(MAKE_DIRECTORY "${_asm_gen_root}")
  file(MAKE_DIRECTORY "${_asm_out_dir}")

  execute_process(
    COMMAND
      "${_aros_target_cc}"
      "-I${AROS_NATIVE_INCLUDE_DIR}"
      "-isystem" "${AROS_NATIVE_INCLUDE_DIR}/aros/posixc"
      "-isystem" "${AROS_NATIVE_INCLUDE_DIR}/aros/stdc"
      -S "${_asm_source}" -o "${_asm_s}"
    RESULT_VARIABLE _compile_result
  )
  if(NOT _compile_result EQUAL 0)
    message(FATAL_ERROR "Failed compiling ${_asm_source} for asm.h generation")
  endif()

  file(STRINGS "${_asm_s}" _asm_lines REGEX "\\.(asciz|ascii)[ \t]+\"")
  set(_asm_header_content "")
  foreach(_asm_line IN LISTS _asm_lines)
    if(_asm_line MATCHES "^[^\"]*\"(.*)\"[^\"]*$")
      set(_asm_entry "${CMAKE_MATCH_1}")
      string(REPLACE "$" "" _asm_entry "${_asm_entry}")
      string(REGEX REPLACE "\\$$" "" _asm_entry "${_asm_entry}")
      string(APPEND _asm_header_content "${_asm_entry}\n")
    endif()
  endforeach()

  if(_asm_header_content STREQUAL "")
    message(FATAL_ERROR "Failed extracting generated asm.h content from ${_asm_s}")
  endif()

  file(WRITE "${_asm_out_dir}/asm.h" "${_asm_header_content}")
endfunction()

file(REMOVE_RECURSE "${AROS_NATIVE_INCLUDE_DIR}")
file(MAKE_DIRECTORY "${AROS_NATIVE_INCLUDE_DIR}")

foreach(_source_root IN ITEMS
    "${AROS_SOURCE_DIR}/compiler/include"
    "${AROS_SOURCE_DIR}/compiler/boost"
    "${AROS_SOURCE_DIR}/compiler/crt/include"
    "${AROS_SOURCE_DIR}/compiler/crt/posixc/include"
    "${AROS_SOURCE_DIR}/compiler/crt/stdc/include"
    "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/include"
    "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/buildsdks/config/include")
  if(_source_root STREQUAL "${AROS_SOURCE_DIR}/compiler/boost")
    _aros_copy_directory_contents("${_source_root}" "${AROS_NATIVE_INCLUDE_DIR}/boost")
  else()
    _aros_copy_directory_contents("${_source_root}" "${AROS_NATIVE_INCLUDE_DIR}")
  endif()
endforeach()

file(GLOB _aros_rom_include_roots LIST_DIRECTORIES true "${AROS_SOURCE_DIR}/rom/*/include")
foreach(_source_root IN LISTS _aros_rom_include_roots)
  _aros_copy_directory_contents("${_source_root}" "${AROS_NATIVE_INCLUDE_DIR}")
endforeach()

_aros_copy_directory_contents("${AROS_SOURCE_DIR}/compiler/arossupport/include" "${AROS_NATIVE_INCLUDE_DIR}/aros")
_aros_copy_files_to_dir("${AROS_NATIVE_INCLUDE_DIR}/aros"
  "${AROS_SOURCE_DIR}/compiler/autoinit/autoinit.h"
  "${AROS_SOURCE_DIR}/compiler/autoinit/detach.h"
  "${AROS_SOURCE_DIR}/compiler/startup/startup.h"
)
_aros_copy_directory_contents("${AROS_SOURCE_DIR}/compiler/dynmodule/include" "${AROS_NATIVE_INCLUDE_DIR}/dynmod")
_aros_copy_files_to_dir("${AROS_NATIVE_INCLUDE_DIR}"
  "${AROS_SOURCE_DIR}/compiler/pthread/pthread.h"
  "${AROS_SOURCE_DIR}/compiler/pthread/sched.h"
  "${AROS_SOURCE_DIR}/compiler/pthread/semaphore.h"
)

# The installed target SDK intentionally keeps a few libc-facing headers in the
# stdc namespace only. Do not expose the raw posixc copies here or native
# module builds will resolve a different public header set than the legacy SDK.
foreach(_legacy_pruned_posixc_header IN ITEMS
    ctype.h
    langinfo.h
    nl_types.h
    wchar.h
    wctype.h)
  file(REMOVE "${AROS_NATIVE_INCLUDE_DIR}/aros/posixc/${_legacy_pruned_posixc_header}")
endforeach()

_aros_collect_arch_include_mmakefiles(_arch_include_mmakefiles)
foreach(_arch_include_mmake IN LISTS _arch_include_mmakefiles)
  _aros_stage_copy_includes_mmake("${_arch_include_mmake}")
endforeach()

# Stage compiler-owned public headers that are published through
# %copy_includes in their local mmakefiles rather than through compiler/include.
file(GLOB _compiler_include_mmakefiles
  "${AROS_SOURCE_DIR}/compiler/*/mmakefile.src"
)
foreach(_compiler_include_mmake IN LISTS _compiler_include_mmakefiles)
  _aros_stage_copy_includes_mmake("${_compiler_include_mmake}")
endforeach()

# Some active arch headers inherit support headers from other CPU namespaces
# (for example x86_64 -> i386). Those are published by the generic *-all
# include mmakefiles, so stage that namespaced support set as well.
file(GLOB _support_arch_include_mmakefiles
  "${AROS_SOURCE_DIR}/arch/*-all/include/mmakefile.src"
)
foreach(_support_arch_include_mmake IN LISTS _support_arch_include_mmakefiles)
  _aros_stage_copy_includes_mmake("${_support_arch_include_mmake}")
endforeach()

# Libc headers stay in their published namespaces. The compiler's ordered
# POSIXC/STDC search paths select them; flat aliases shadow that selection.
_aros_publish_root_include_alias("dos/dos.h" "dos.h")

_aros_generate_execbase_header()
_aros_generate_arch_libcall_header()
_aros_generate_arch_asm_header()

# Native producers take precedence over any legacy-generated snapshot.
if(AROS_NATIVE_GENERATED_INCLUDE_DIR)
  _aros_copy_directory_contents("${AROS_NATIVE_GENERATED_INCLUDE_DIR}" "${AROS_NATIVE_INCLUDE_DIR}")
endif()
