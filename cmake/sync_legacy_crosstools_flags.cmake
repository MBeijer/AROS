if(NOT DEFINED AROS_CROSSTOOLS_INSTALL_DIR OR AROS_CROSSTOOLS_INSTALL_DIR STREQUAL "")
  message(FATAL_ERROR "AROS_CROSSTOOLS_INSTALL_DIR is required")
endif()

if(NOT DEFINED AROS_CROSSTOOLS_TARGET_CPU OR AROS_CROSSTOOLS_TARGET_CPU STREQUAL "")
  message(FATAL_ERROR "AROS_CROSSTOOLS_TARGET_CPU is required")
endif()

if(NOT EXISTS "${AROS_CROSSTOOLS_INSTALL_DIR}")
  return()
endif()

set(_aros_legacy_bin_dir "${AROS_CROSSTOOLS_INSTALL_DIR}/bin")

set(_aros_tool_prefix "${AROS_CROSSTOOLS_TARGET_CPU}-aros")
set(_aros_has_binutils FALSE)
set(_aros_has_gcc FALSE)

if(EXISTS "${_aros_legacy_bin_dir}/${_aros_tool_prefix}-ld" OR EXISTS "${AROS_CROSSTOOLS_INSTALL_DIR}/${_aros_tool_prefix}-ld")
  set(_aros_has_binutils TRUE)
endif()

if(EXISTS "${_aros_legacy_bin_dir}/${_aros_tool_prefix}-gcc" OR EXISTS "${AROS_CROSSTOOLS_INSTALL_DIR}/${_aros_tool_prefix}-gcc")
  set(_aros_has_gcc TRUE)
endif()

function(_aros_symlink_tool_if_missing _tool_name)
  set(_bin_tool "${_aros_legacy_bin_dir}/${_aros_tool_prefix}-${_tool_name}")
  set(_top_tool "${AROS_CROSSTOOLS_INSTALL_DIR}/${_aros_tool_prefix}-${_tool_name}")
  if(EXISTS "${_bin_tool}" AND NOT EXISTS "${_top_tool}")
    file(CREATE_LINK "bin/${_aros_tool_prefix}-${_tool_name}" "${_top_tool}" SYMBOLIC)
  endif()
endfunction()

# Keep top-level wrappers compatible with legacy collect-aros behavior.
_aros_symlink_tool_if_missing("ld")
_aros_symlink_tool_if_missing("nm")
_aros_symlink_tool_if_missing("objcopy")
_aros_symlink_tool_if_missing("objdump")
_aros_symlink_tool_if_missing("strip")
_aros_symlink_tool_if_missing("ar")
_aros_symlink_tool_if_missing("ranlib")
_aros_symlink_tool_if_missing("as")
_aros_symlink_tool_if_missing("gcc")
_aros_symlink_tool_if_missing("g++")
_aros_symlink_tool_if_missing("cpp")

function(_aros_touch_if_missing _flag_path)
  if(NOT EXISTS "${_flag_path}")
    file(TOUCH "${_flag_path}")
  endif()
endfunction()

if(_aros_has_binutils)
  _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-binutils-${AROS_BINUTILS_VERSION}-${AROS_CROSSTOOLS_TARGET_CPU}")
endif()

if(_aros_has_gcc)
  _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-gcc-${AROS_GCC_VERSION}-${AROS_CROSSTOOLS_TARGET_CPU}")
endif()

# START LEGACY: native crosstools compatibility shim for legacy startup C++ deps.
# Some native gcc builds do not install the legacy-expected compatibility header
# at lib/gcc/<triplet>/<ver>/include/c++/stdlib.h. Create a forwarding wrapper
# so legacy make dependencies can resolve identically.
if(_aros_has_gcc)
  set(_aros_legacy_cxx_include_dir
    "${AROS_CROSSTOOLS_INSTALL_DIR}/lib/gcc/${_aros_tool_prefix}/${AROS_GCC_VERSION}/include/c++")
  file(MAKE_DIRECTORY "${_aros_legacy_cxx_include_dir}")

  # Try to reuse native crosstools libstdc++ source headers when the install
  # layout does not include the full legacy-expected include/c++ tree.
  get_filename_component(_aros_build_root "${AROS_CROSSTOOLS_INSTALL_DIR}" DIRECTORY)
  get_filename_component(_aros_build_root "${_aros_build_root}" DIRECTORY)
  get_filename_component(_aros_build_root "${_aros_build_root}" DIRECTORY)
  get_filename_component(_aros_build_root "${_aros_build_root}" DIRECTORY)
  set(_aros_libstdcxx_src_include
    "${_aros_build_root}/_deps/crosstools-gnu/src/gcc-${AROS_GCC_VERSION}/libstdc++-v3/include")

  function(_aros_symlink_tree_missing _src_dir _dst_dir)
    if(NOT EXISTS "${_src_dir}")
      return()
    endif()
    file(MAKE_DIRECTORY "${_dst_dir}")
    file(GLOB _entries RELATIVE "${_src_dir}" "${_src_dir}/*")
    foreach(_entry IN LISTS _entries)
      if(_entry STREQUAL "." OR _entry STREQUAL "..")
        continue()
      endif()
      set(_src_path "${_src_dir}/${_entry}")
      set(_dst_path "${_dst_dir}/${_entry}")
      if(NOT EXISTS "${_dst_path}")
        if(IS_DIRECTORY "${_src_path}")
          file(CREATE_LINK "${_src_path}" "${_dst_path}" SYMBOLIC)
        else()
          file(CREATE_LINK "${_src_path}" "${_dst_path}" SYMBOLIC)
        endif()
      endif()
    endforeach()
  endfunction()

  # Populate core libstdc++ header trees expected by legacy dependency files.
  _aros_symlink_tree_missing("${_aros_libstdcxx_src_include}/bits" "${_aros_legacy_cxx_include_dir}/bits")
  _aros_symlink_tree_missing("${_aros_libstdcxx_src_include}/ext" "${_aros_legacy_cxx_include_dir}/ext")
  _aros_symlink_tree_missing("${_aros_libstdcxx_src_include}/backward" "${_aros_legacy_cxx_include_dir}/backward")
  if(EXISTS "${_aros_libstdcxx_src_include}")
    file(GLOB _aros_libstdcxx_toplevel RELATIVE "${_aros_libstdcxx_src_include}" "${_aros_libstdcxx_src_include}/*")
    foreach(_hdr IN LISTS _aros_libstdcxx_toplevel)
      if(_hdr STREQUAL "bits" OR _hdr STREQUAL "ext" OR _hdr STREQUAL "backward")
        continue()
      endif()
      set(_src_hdr "${_aros_libstdcxx_src_include}/${_hdr}")
      set(_dst_hdr "${_aros_legacy_cxx_include_dir}/${_hdr}")
      if(EXISTS "${_src_hdr}" AND NOT EXISTS "${_dst_hdr}" AND NOT IS_DIRECTORY "${_src_hdr}")
        file(CREATE_LINK "${_src_hdr}" "${_dst_hdr}" SYMBOLIC)
      endif()
    endforeach()
  endif()

  function(_aros_write_forward_header_if_missing _path _guard _include_line)
    if(NOT EXISTS "${_path}")
      file(WRITE "${_path}" "#ifndef ${_guard}\n#define ${_guard} 1\n${_include_line}\n#endif\n")
    endif()
  endfunction()

  # Provide the legacy-expected C++ include surface used by compiler/startup/cxx.
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/stdlib.h"
    "_GLIBCXX_STDLIB_H"
    "#include_next <stdlib.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/cstdlib"
    "_GLIBCXX_CSTDLIB"
    "#include_next <stdlib.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/stdio.h"
    "_GLIBCXX_STDIO_H"
    "#include_next <stdio.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/cstdio"
    "_GLIBCXX_CSTDIO"
    "#include_next <stdio.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/string.h"
    "_GLIBCXX_STRING_H"
    "#include_next <string.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/cstring"
    "_GLIBCXX_CSTRING"
    "#include_next <string.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/stddef.h"
    "_GLIBCXX_STDDEF_H"
    "#include_next <stddef.h>"
  )
  _aros_write_forward_header_if_missing(
    "${_aros_legacy_cxx_include_dir}/cstddef"
    "_GLIBCXX_CSTDDEF"
    "#include_next <stddef.h>"
  )
  set(_aros_legacy_cxx_bits_dir "${_aros_legacy_cxx_include_dir}/${_aros_tool_prefix}/bits")
  set(_aros_legacy_cxx_config_h "${_aros_legacy_cxx_bits_dir}/c++config.h")
  if(NOT EXISTS "${_aros_legacy_cxx_config_h}")
    file(MAKE_DIRECTORY "${_aros_legacy_cxx_bits_dir}")
    file(WRITE "${_aros_legacy_cxx_config_h}"
"#ifndef _GLIBCXX_CXX_CONFIG_H\n#define _GLIBCXX_CXX_CONFIG_H 1\n#define _GLIBCXX_RELEASE 10\n#define __GLIBCXX__ 20210101\n#define _GLIBCXX_USE_CXX11_ABI 1\n#define _GLIBCXX_VISIBILITY(V)\n#define _GLIBCXX_BEGIN_NAMESPACE_VERSION\n#define _GLIBCXX_END_NAMESPACE_VERSION\n#define _GLIBCXX_BEGIN_NAMESPACE_CONTAINER\n#define _GLIBCXX_END_NAMESPACE_CONTAINER\n#define _GLIBCXX_USE_NOEXCEPT noexcept\n#define _GLIBCXX_NOTHROW noexcept\n#define _GLIBCXX_BEGIN_EXTERN_C extern \"C\" {\n#define _GLIBCXX_END_EXTERN_C }\n#endif\n")
  endif()
  set(_aros_legacy_cxx_os_defines_h "${_aros_legacy_cxx_bits_dir}/os_defines.h")
  if(NOT EXISTS "${_aros_legacy_cxx_os_defines_h}")
    file(WRITE "${_aros_legacy_cxx_os_defines_h}"
"#ifndef _GLIBCXX_OS_DEFINES\n#define _GLIBCXX_OS_DEFINES 1\n/* Legacy CMake bridge fallback for missing libstdc++ target install headers. */\n#endif\n")
  endif()
  set(_aros_legacy_cxx_cpu_defines_h "${_aros_legacy_cxx_bits_dir}/cpu_defines.h")
  if(NOT EXISTS "${_aros_legacy_cxx_cpu_defines_h}")
    file(WRITE "${_aros_legacy_cxx_cpu_defines_h}"
"#ifndef _GLIBCXX_CPU_DEFINES\n#define _GLIBCXX_CPU_DEFINES 1\n/* Legacy CMake bridge fallback for missing target cpu defines header. */\n#endif\n")
  endif()
  if(NOT EXISTS "${_aros_legacy_cxx_include_dir}/new")
    file(WRITE "${_aros_legacy_cxx_include_dir}/new" "#ifndef _GLIBCXX_NEW\n#define _GLIBCXX_NEW 1\nextern \"C++\" {\nvoid *operator new(unsigned long);\nvoid operator delete(void *) noexcept;\n}\n#endif\n")
  endif()
endif()
# END LEGACY

# GNU dependencies are installed as part of the crosstools toolchain and are
# treated as immutable versioned artifacts by legacy mmake once present.
if(_aros_has_gcc OR _aros_has_binutils)
  _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-gmp-${AROS_GMP_VERSION}")
  _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-isl-${AROS_ISL_VERSION}")
  _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-mpfr-${AROS_MPFR_VERSION}")
  _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-mpc-${AROS_MPC_VERSION}")
endif()

if(DEFINED AROS_TOUCH_CROSSTOOLS_FLAG AND AROS_TOUCH_CROSSTOOLS_FLAG)
  if(_aros_has_gcc OR _aros_has_binutils)
    _aros_touch_if_missing("${AROS_CROSSTOOLS_INSTALL_DIR}/.installflag-crosstools")
  endif()
endif()
