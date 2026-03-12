cmake_minimum_required(VERSION 3.20)

project(genctbl LANGUAGES C)

add_executable(genctbl genctbl.c)

set(AROS_UCD_DIR "${CMAKE_BINARY_DIR}/ucd" CACHE PATH "Directory containing UnicodeData.txt used by genctbl")
set(AROS_CHTBL_OUT_DIR "${CMAKE_BINARY_DIR}/charsets" CACHE PATH "Output directory for generated .ctbl files")

set(_aros_ctbl_languages
  en_GB.ISO8859-1
  en_US.ISO8859-1
  de_DE.ISO8859-1
  fr_FR.ISO8859-1
  es_ES.ISO8859-1
  it_IT.ISO8859-1
  nl_NL.ISO8859-1
  sv_SE.ISO8859-1
  pl_PL.ISO8859-2
  cs_CZ.ISO8859-2
  hu_HU.ISO8859-2
  hr_HR.ISO8859-2
  tr_TR.ISO8859-9
  ru_RU.ISO8859-5
  bg_BG.ISO8859-5
  el_GR.ISO8859-7
  he_IL.ISO8859-8
  ar_SA.ISO8859-6
  et_EE.ISO8859-4
  lt_LT.ISO8859-4
  lv_LV.ISO8859-4
  fi_FI.ISO8859-10
  is_IS.ISO8859-10
  ga_IE.ISO8859-14
  cy_GB.ISO8859-14
  ro_RO.ISO8859-16
  sq_AL.ISO8859-16
  en_IE.ISO8859-15
  fr_BE.ISO8859-15
)
string(REPLACE ";" "|" _aros_ctbl_languages_pipe "${_aros_ctbl_languages}")

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/generate_ctbls.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/generate_ctbls.cmake"
  @ONLY
)

add_custom_target(aros-localize-ctbls
  COMMAND "${CMAKE_COMMAND}" -DGENCTBL_EXE=$<TARGET_FILE:genctbl> -DUCD_DIR=${AROS_UCD_DIR} -DOUT_DIR=${AROS_CHTBL_OUT_DIR} -P "${CMAKE_CURRENT_BINARY_DIR}/generate_ctbls.cmake"
  DEPENDS genctbl "${AROS_UCD_DIR}/UnicodeData.txt"
  COMMENT "Generating .ctbl locale tables with genctbl"
  VERBATIM
)

install(TARGETS genctbl RUNTIME DESTINATION bin)
