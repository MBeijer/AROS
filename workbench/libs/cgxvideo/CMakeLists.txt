cmake_minimum_required(VERSION 3.20)

aros_register_mmake_genmodule_module(
  aros-workbench-libs-cgxvideo-native
  MODULE_PATH workbench/libs/cgxvideo
  COMPILE_DEFINITIONS __IHidd_Overlay=HiddOverlayAttrBase
  LINK_LIBS oop
)

if(AROS_ENABLE_LEGACY_PIPELINE AND COMMAND aros_register_legacy_make_target)
  aros_register_legacy_make_target(
    aros-workbench-libs-cgxvideo
    workbench-libs-cgxvideo
    ${_aros_legacy_crosstools_dep}
  )
endif()
