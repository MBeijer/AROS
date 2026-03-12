cmake_minimum_required(VERSION 3.20)

aros_register_layered_module_sources_target(aros-rom-exec-layered-sources rom/exec)

aros_register_mmake_genmodule_module(
  aros-rom-exec-native
  MODULE_PATH rom/exec
)
