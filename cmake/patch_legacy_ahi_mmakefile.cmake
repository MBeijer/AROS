if(NOT DEFINED AROS_PARITY_LEGACY_BUILD_DIR OR AROS_PARITY_LEGACY_BUILD_DIR STREQUAL "")
  message(FATAL_ERROR "AROS_PARITY_LEGACY_BUILD_DIR must be set")
endif()

set(_ahi_mmakefile "${AROS_PARITY_LEGACY_BUILD_DIR}/workbench/devs/AHI/mmakefile")
if(NOT EXISTS "${_ahi_mmakefile}")
  message(STATUS "AHI mmakefile not found at ${_ahi_mmakefile}; skipping parity patch")
  return()
endif()

file(READ "${_ahi_mmakefile}" _ahi_mmakefile_content)

# Keep AHI probe AS as the GCC driver (not raw as) so ASDEFSYM resolves to -Wa,--defsym,.
string(REGEX REPLACE
  "TARGET_AS:=[^\r\n]*"
  "TARGET_AS:=$(strip $(CC) $(TARGET_SYSROOT))"
  _ahi_mmakefile_content
  "${_ahi_mmakefile_content}")

# Preserve required stdin assembly mode while avoiding problematic inherited AFLAGS payload.
string(REPLACE
  "AHI_OPTIONS+=--with-target-asflags=\"\""
  "AHI_OPTIONS+=--with-target-asflags=\"-x assembler-with-cpp -c\""
  _ahi_mmakefile_content
  "${_ahi_mmakefile_content}")

if(NOT _ahi_mmakefile_content MATCHES "AHI_OPTIONS\\+=--with-target-asflags=\"-x assembler-with-cpp -c\"")
  string(REPLACE
    "AHI_OPTIONS+=--with-target-asflags=\"$(AFLAGS)\""
    "AHI_OPTIONS+=--with-target-asflags=\"$(AFLAGS)\"\n# START LEGACY: parity-only workaround for AHI configure ASFLAGS probing.\nAHI_OPTIONS+=--with-target-asflags=\"-x assembler-with-cpp -c\"\n# END LEGACY"
    _ahi_mmakefile_content
    "${_ahi_mmakefile_content}")
endif()

file(WRITE "${_ahi_mmakefile}" "${_ahi_mmakefile_content}")
