cmake_minimum_required(VERSION 3.20)

# rom/ migration entrypoint.
# Native rom/* CMake module conversions should be added here incrementally,
# with arch-layer aware source selection and parity checks against legacy outputs.
set(_aros_rom_native_modules_default "aros;battclock;bootloader;disk;dos;dosboot;exec;expansion;filesystem;filesys/ram;filesys/console_handler;graphics;hyperlayers;intuition;kernel;keymap;lddemon;devs/console;devs/gameport;devs/input;devs/keyboard;hidds/hidd;hidds/gfx;hidds/input;hidds/kbd;hidds/mouse;hidds/pci;misc;oop;partition;task;utility;debug;processor;timer")
set(AROS_ROM_NATIVE_MODULES "${_aros_rom_native_modules_default}" CACHE STRING "Semicolon-separated rom modules enabled for native CMake migration")
set(_aros_rom_current_native_modules ${AROS_ROM_NATIVE_MODULES})
set(_aros_rom_native_modules_missing)
foreach(_aros_rom_default_module IN LISTS _aros_rom_native_modules_default)
  list(FIND _aros_rom_current_native_modules "${_aros_rom_default_module}" _aros_rom_default_index)
  if(_aros_rom_default_index EQUAL -1)
    list(APPEND _aros_rom_native_modules_missing "${_aros_rom_default_module}")
  endif()
endforeach()
set(_aros_rom_native_modules_extra ${_aros_rom_current_native_modules})
foreach(_aros_rom_default_module IN LISTS _aros_rom_native_modules_default)
  list(REMOVE_ITEM _aros_rom_native_modules_extra "${_aros_rom_default_module}")
endforeach()
list(LENGTH _aros_rom_native_modules_missing _aros_rom_missing_count)
if("${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;exec;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "exec;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;bootloader;exec;filesystem;keymap;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;battclock;bootloader;disk;exec;expansion;filesystem;keymap;misc;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;battclock;bootloader;disk;dos;dosboot;exec;expansion;filesystem;keymap;misc;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;battclock;bootloader;disk;dos;dosboot;exec;expansion;filesystem;graphics;hyperlayers;keymap;misc;oop;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;battclock;bootloader;disk;dos;dosboot;exec;expansion;filesystem;graphics;hyperlayers;intuition;keymap;lddemon;misc;oop;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;battclock;bootloader;disk;dos;dosboot;exec;expansion;filesystem;filesys/ram;filesys/console_handler;graphics;hyperlayers;intuition;keymap;lddemon;devs/console;devs/gameport;devs/input;devs/keyboard;misc;oop;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "aros;battclock;bootloader;disk;dos;dosboot;exec;expansion;filesystem;filesys/ram;filesys/console_handler;graphics;hyperlayers;intuition;keymap;lddemon;devs/console;devs/gameport;devs/input;devs/keyboard;hidds/hidd;hidds/gfx;hidds/input;hidds/kbd;hidds/mouse;misc;oop;utility;debug;processor;timer"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "utility"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "utility;debug"
   OR "${AROS_ROM_NATIVE_MODULES}" STREQUAL "utility;debug;processor;timer"
   OR (_aros_rom_missing_count EQUAL 1
       AND "${_aros_rom_native_modules_missing}" STREQUAL "kernel"
       AND NOT _aros_rom_native_modules_extra))
  set(AROS_ROM_NATIVE_MODULES "${_aros_rom_native_modules_default}" CACHE STRING "Semicolon-separated rom modules enabled for native CMake migration" FORCE)
endif()
foreach(_aros_rom_module IN LISTS AROS_ROM_NATIVE_MODULES)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_rom_module}/CMakeLists.txt")
    add_subdirectory("${_aros_rom_module}")
  endif()
endforeach()

set(_aros_rom_kernel_package_base_native_deps
  aros-rom-aros-native
  aros-rom-bootloader-native
  aros-rom-dos-native
  aros-rom-dosboot-native
  aros-rom-debug-native
  aros-rom-filesystem-native
  aros-rom-fs-ram-native
  aros-rom-fs-con-native
  aros-rom-graphics-native
  aros-rom-hidd-gfx-native
  aros-rom-hidd-input-native
  aros-rom-hidd-kbd-native
  aros-rom-hidd-mouse-native
  aros-rom-utility-native
  aros-rom-intuition-native
  aros-rom-keymap-native
  aros-rom-lddemon-native
  aros-rom-console-native
  aros-rom-gameport-native
  aros-rom-input-native
  aros-rom-keyboard-native
  aros-rom-hiddclass-native
  aros-rom-oop-native
  aros-rom-hyperlayers-native
)
set(_aros_rom_kernel_package_base_available_deps)
foreach(_aros_rom_kernel_package_dep IN LISTS _aros_rom_kernel_package_base_native_deps)
  if(TARGET "${_aros_rom_kernel_package_dep}")
    list(APPEND _aros_rom_kernel_package_base_available_deps "${_aros_rom_kernel_package_dep}")
  endif()
endforeach()

add_custom_target(
  aros-rom-kernel-package-base-native
  DEPENDS ${_aros_rom_kernel_package_base_available_deps}
)
set_target_properties(aros-rom-kernel-package-base-native PROPERTIES FOLDER "aros/rom")

add_custom_target(kernel-package-base DEPENDS aros-rom-kernel-package-base-native)
set_target_properties(kernel-package-base PROPERTIES FOLDER "aros/rom")

set(_aros_rom_legacy_interface_modules_default "aros;dos;graphics;intuition;kernel")
list(APPEND _aros_rom_legacy_interface_modules_default ${AROS_ROM_NATIVE_MODULES})
list(REMOVE_DUPLICATES _aros_rom_legacy_interface_modules_default)
set(_aros_rom_minimal_interface_modules_default "kernel")
list(APPEND _aros_rom_minimal_interface_modules_default ${AROS_ROM_NATIVE_MODULES})
list(REMOVE_DUPLICATES _aros_rom_minimal_interface_modules_default)
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/mmakefile.src" _aros_rom_mmake_lines)
set(_aros_rom_native_interface_modules_default)
foreach(_aros_rom_line IN LISTS _aros_rom_mmake_lines)
  if(_aros_rom_line MATCHES "kernel-([A-Za-z0-9_.+-]+)-includes")
    set(_aros_rom_interface_module "${CMAKE_MATCH_1}")
    set(_aros_rom_interface_mmakefile "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_rom_interface_module}/mmakefile.src")
    if(EXISTS "${_aros_rom_interface_mmakefile}")
      file(STRINGS "${_aros_rom_interface_mmakefile}" _aros_rom_interface_build_module REGEX "^%build_module[^ \t]*[ \t]+")
      if(_aros_rom_interface_build_module)
        list(APPEND _aros_rom_native_interface_modules_default "${_aros_rom_interface_module}")
      endif()
    endif()
  endif()
endforeach()
list(APPEND _aros_rom_native_interface_modules_default ${AROS_ROM_NATIVE_MODULES})
list(REMOVE_DUPLICATES _aros_rom_native_interface_modules_default)
set(
  AROS_ROM_NATIVE_INTERFACE_MODULES
  "${_aros_rom_native_interface_modules_default}"
  CACHE STRING
  "Semicolon-separated ROM modules registered for native interface generation"
)
set(_aros_rom_needs_interface_cache_upgrade FALSE)
set(_aros_rom_current_interface_modules ${AROS_ROM_NATIVE_INTERFACE_MODULES})
foreach(_aros_rom_native_module IN LISTS AROS_ROM_NATIVE_MODULES)
  list(FIND _aros_rom_current_interface_modules "${_aros_rom_native_module}" _aros_rom_native_index)
  if(_aros_rom_native_index EQUAL -1)
    set(_aros_rom_needs_interface_cache_upgrade TRUE)
    break()
  endif()
endforeach()

list(FIND _aros_rom_current_interface_modules "kernel" _aros_rom_kernel_index)
if(NOT _aros_rom_needs_interface_cache_upgrade AND NOT _aros_rom_kernel_index EQUAL -1)
  list(FIND _aros_rom_current_interface_modules "aros" _aros_rom_aros_index)
  list(FIND _aros_rom_current_interface_modules "dos" _aros_rom_dos_index)
  list(FIND _aros_rom_current_interface_modules "graphics" _aros_rom_graphics_index)
  list(FIND _aros_rom_current_interface_modules "intuition" _aros_rom_intuition_index)
  list(FIND _aros_rom_current_interface_modules "bootloader" _aros_rom_bootloader_index)
  if(_aros_rom_aros_index EQUAL -1
     OR _aros_rom_dos_index EQUAL -1
     OR _aros_rom_graphics_index EQUAL -1
     OR _aros_rom_intuition_index EQUAL -1
     OR _aros_rom_bootloader_index EQUAL -1)
    set(_aros_rom_needs_interface_cache_upgrade TRUE)
  endif()
endif()

if(_aros_rom_needs_interface_cache_upgrade)
  set(
    AROS_ROM_NATIVE_INTERFACE_MODULES
    "${_aros_rom_native_interface_modules_default}"
    CACHE STRING
    "Semicolon-separated ROM modules registered for native interface generation"
    FORCE
  )
endif()
foreach(_aros_rom_interface_module IN LISTS AROS_ROM_NATIVE_INTERFACE_MODULES)
  string(REPLACE "/" "-" _aros_rom_interface_target_id "${_aros_rom_interface_module}")
  aros_register_mmake_genmodule_module(
    "aros-rom-${_aros_rom_interface_target_id}-sdk-native"
    MODULE_PATH "rom/${_aros_rom_interface_module}"
  )
  if(TARGET aros-sdk-interfaces-native)
    add_dependencies(
      aros-sdk-interfaces-native
      "aros-rom-${_aros_rom_interface_target_id}-sdk-native-interfaces"
    )
  endif()
endforeach()

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(aros-rom rom ${_aros_legacy_crosstools_dep})
  aros_register_legacy_make_target(aros-rom-kernel-package-base kernel-package-base ${_aros_legacy_crosstools_dep})
endif()
