cmake_minimum_required(VERSION 3.20)

aros_register_layered_module_sources_target(
  aros-arch-hostlib-layered-sources
  arch/all-hosted/hostlib
)

aros_register_mmake_genmodule_module(
  aros-arch-hostlib-native
  MODULE_PATH arch/all-hosted/hostlib
)

# Hostlib headers are needed by other native modules before the full arch-side
# hostlib module conversion is complete, so expose the generated interface
# without forcing ABI/output build-order edges yet.
set_target_properties(
  aros-arch-hostlib-native-interface
  PROPERTIES
    AROS_MODULE_OWNER_TARGET ""
    AROS_MODULE_OWNER_ABI_TARGET ""
)

if(TARGET aros-sdk-interfaces-native)
  add_dependencies(
    aros-sdk-interfaces-native
    aros-arch-hostlib-native-interfaces
  )
endif()
