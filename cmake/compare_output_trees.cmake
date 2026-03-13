if(NOT DEFINED LEFT_DIR OR NOT DEFINED RIGHT_DIR)
  message(FATAL_ERROR "LEFT_DIR and RIGHT_DIR must be defined")
endif()

if(NOT EXISTS "${LEFT_DIR}")
  message(FATAL_ERROR "LEFT_DIR does not exist: ${LEFT_DIR}")
endif()
if(NOT EXISTS "${RIGHT_DIR}")
  message(FATAL_ERROR "RIGHT_DIR does not exist: ${RIGHT_DIR}")
endif()

if(NOT DEFINED FAIL_ON_DIFF)
  set(FAIL_ON_DIFF ON)
endif()

find_program(_PARITY_AR NAMES ar)

function(_collect_files root out_var)
  get_filename_component(_root_abs "${root}" ABSOLUTE)
  file(GLOB_RECURSE _abs_files RELATIVE "${_root_abs}" "${_root_abs}/*")
  set(_files)
  foreach(_f IN LISTS _abs_files)
    if(NOT IS_DIRECTORY "${_root_abs}/${_f}")
      list(APPEND _files "${_f}")
    endif()
  endforeach()
  list(SORT _files)
  set(${out_var} "${_files}" PARENT_SCOPE)
endfunction()

function(_compare_static_archives left_path right_path out_var)
  if(NOT _PARITY_AR)
    set(${out_var} FALSE PARENT_SCOPE)
    return()
  endif()

  execute_process(
    COMMAND "${_PARITY_AR}" t "${left_path}"
    RESULT_VARIABLE _left_result
    OUTPUT_VARIABLE _left_members_raw
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  execute_process(
    COMMAND "${_PARITY_AR}" t "${right_path}"
    RESULT_VARIABLE _right_result
    OUTPUT_VARIABLE _right_members_raw
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT _left_result EQUAL 0 OR NOT _right_result EQUAL 0)
    set(${out_var} FALSE PARENT_SCOPE)
    return()
  endif()

  string(REPLACE "\r" "" _left_members_raw "${_left_members_raw}")
  string(REPLACE "\r" "" _right_members_raw "${_right_members_raw}")

  if(_left_members_raw STREQUAL "")
    set(_left_members)
  else()
    string(REPLACE "\n" ";" _left_members "${_left_members_raw}")
  endif()
  if(_right_members_raw STREQUAL "")
    set(_right_members)
  else()
    string(REPLACE "\n" ";" _right_members "${_right_members_raw}")
  endif()

  list(LENGTH _left_members _left_member_count)
  list(LENGTH _right_members _right_member_count)
  if(NOT _left_member_count EQUAL _right_member_count)
    set(${out_var} FALSE PARENT_SCOPE)
    return()
  endif()

  if(_left_member_count GREATER 0)
    math(EXPR _last_member_index "${_left_member_count} - 1")
    foreach(_member_index RANGE 0 ${_last_member_index})
      list(GET _left_members ${_member_index} _left_member)
      list(GET _right_members ${_member_index} _right_member)
      if(NOT _left_member STREQUAL _right_member)
        set(${out_var} FALSE PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endif()

  file(MAKE_DIRECTORY "/tmp/aros-parity-archive-compare")
  string(SHA256 _archive_compare_id "${left_path}|${right_path}")

  foreach(_member IN LISTS _left_members)
    string(SHA256 _member_id "${_archive_compare_id}|${_member}")
    set(_left_member_file "/tmp/aros-parity-archive-compare/${_member_id}.left")
    set(_right_member_file "/tmp/aros-parity-archive-compare/${_member_id}.right")

    execute_process(
      COMMAND "${_PARITY_AR}" p "${left_path}" "${_member}"
      RESULT_VARIABLE _left_extract_result
      OUTPUT_FILE "${_left_member_file}"
      ERROR_QUIET
    )
    execute_process(
      COMMAND "${_PARITY_AR}" p "${right_path}" "${_member}"
      RESULT_VARIABLE _right_extract_result
      OUTPUT_FILE "${_right_member_file}"
      ERROR_QUIET
    )
    if(NOT _left_extract_result EQUAL 0 OR NOT _right_extract_result EQUAL 0)
      file(REMOVE "${_left_member_file}" "${_right_member_file}")
      set(${out_var} FALSE PARENT_SCOPE)
      return()
    endif()

    file(SHA256 "${_left_member_file}" _left_member_sha)
    file(SHA256 "${_right_member_file}" _right_member_sha)
    file(REMOVE "${_left_member_file}" "${_right_member_file}")
    if(NOT _left_member_sha STREQUAL _right_member_sha)
      set(${out_var} FALSE PARENT_SCOPE)
      return()
    endif()
  endforeach()

  set(${out_var} TRUE PARENT_SCOPE)
endfunction()

_collect_files("${LEFT_DIR}" _left_files)
_collect_files("${RIGHT_DIR}" _right_files)

set(_missing_in_right)
set(_missing_in_left)
set(_diff_files)
set(_same_count 0)

foreach(_f IN LISTS _left_files)
  if(NOT EXISTS "${RIGHT_DIR}/${_f}" AND NOT IS_SYMLINK "${RIGHT_DIR}/${_f}")
    list(APPEND _missing_in_right "${_f}")
    continue()
  endif()

  if(IS_SYMLINK "${LEFT_DIR}/${_f}" OR IS_SYMLINK "${RIGHT_DIR}/${_f}")
    if(NOT (IS_SYMLINK "${LEFT_DIR}/${_f}" AND IS_SYMLINK "${RIGHT_DIR}/${_f}"))
      list(APPEND _diff_files "${_f}")
      continue()
    endif()
    file(READ_SYMLINK "${LEFT_DIR}/${_f}" _llink)
    file(READ_SYMLINK "${RIGHT_DIR}/${_f}" _rlink)
    if(NOT _llink STREQUAL _rlink)
      list(APPEND _diff_files "${_f}")
    else()
      math(EXPR _same_count "${_same_count} + 1")
    endif()
    continue()
  endif()

  file(SIZE "${LEFT_DIR}/${_f}" _lsize)
  file(SIZE "${RIGHT_DIR}/${_f}" _rsize)
  if(_f MATCHES "\\.a$" AND _PARITY_AR)
    _compare_static_archives("${LEFT_DIR}/${_f}" "${RIGHT_DIR}/${_f}" _archives_match)
    if(NOT _archives_match)
      list(APPEND _diff_files "${_f}")
    else()
      math(EXPR _same_count "${_same_count} + 1")
    endif()
    continue()
  endif()

  if(NOT _lsize EQUAL _rsize)
    list(APPEND _diff_files "${_f}")
    continue()
  endif()

  file(SHA256 "${LEFT_DIR}/${_f}" _lsha)
  file(SHA256 "${RIGHT_DIR}/${_f}" _rsha)
  if(NOT _lsha STREQUAL _rsha)
    list(APPEND _diff_files "${_f}")
  else()
    math(EXPR _same_count "${_same_count} + 1")
  endif()
endforeach()

foreach(_f IN LISTS _right_files)
  if(NOT EXISTS "${LEFT_DIR}/${_f}" AND NOT IS_SYMLINK "${LEFT_DIR}/${_f}")
    list(APPEND _missing_in_left "${_f}")
  endif()
endforeach()

list(LENGTH _missing_in_right _miss_r_n)
list(LENGTH _missing_in_left _miss_l_n)
list(LENGTH _diff_files _diff_n)
list(LENGTH _left_files _left_n)
list(LENGTH _right_files _right_n)

message(STATUS "[parity] left files:  ${_left_n}")
message(STATUS "[parity] right files: ${_right_n}")
message(STATUS "[parity] identical:   ${_same_count}")
message(STATUS "[parity] missing right: ${_miss_r_n}")
message(STATUS "[parity] missing left:  ${_miss_l_n}")
message(STATUS "[parity] differing:     ${_diff_n}")

if(_miss_r_n GREATER 0)
  message(STATUS "[parity] sample missing in right:")
  list(SUBLIST _missing_in_right 0 20 _sample)
  foreach(_f IN LISTS _sample)
    message(STATUS "  - ${_f}")
  endforeach()
endif()

if(_miss_l_n GREATER 0)
  message(STATUS "[parity] sample missing in left:")
  list(SUBLIST _missing_in_left 0 20 _sample)
  foreach(_f IN LISTS _sample)
    message(STATUS "  - ${_f}")
  endforeach()
endif()

if(_diff_n GREATER 0)
  message(STATUS "[parity] sample differing files:")
  list(SUBLIST _diff_files 0 20 _sample)
  foreach(_f IN LISTS _sample)
    message(STATUS "  - ${_f}")
  endforeach()
endif()

if(FAIL_ON_DIFF AND (_miss_r_n GREATER 0 OR _miss_l_n GREATER 0 OR _diff_n GREATER 0))
  message(FATAL_ERROR "[parity] output trees differ")
endif()
