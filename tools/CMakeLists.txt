cmake_minimum_required(VERSION 3.20)

if(AROS_BUILD_METAMAKE)
  add_subdirectory(MetaMake)
endif()

if(AROS_BUILD_ZOPFLI)
  add_subdirectory(zopfli)
endif()

if(AROS_BUILD_GENMF)
  add_subdirectory(genmf)
endif()

if(AROS_BUILD_GENMODULE)
  add_subdirectory(genmodule)
endif()

if(AROS_BUILD_SETREV)
  add_subdirectory(setrev)
endif()

if(AROS_BUILD_ELF2HUNK)
  add_subdirectory(elf2hunk)
endif()

if(AROS_BUILD_ILBMTOC)
  add_subdirectory(ilbmtoc)
endif()

if(AROS_BUILD_ARCHTOOL)
  add_subdirectory(archtools)
endif()

if(AROS_BUILD_ILBMTOICON)
  add_subdirectory(ilbmtoicon)
endif()

if(AROS_BUILD_DTDESC)
  add_subdirectory(dtdesc)
endif()

if(AROS_BUILD_GENCTBL)
  add_subdirectory(genctbl)
endif()

if(AROS_BUILD_MKAMIKEYMAP)
  add_subdirectory(mkamikeymap)
endif()

if(AROS_BUILD_FD2PRAGMA)
  add_subdirectory(fd2pragma)
endif()

if(AROS_BUILD_ADFLIB)
  add_subdirectory(ADFlib)
endif()

if(AROS_BUILD_FLEXCAT)
  add_subdirectory(flexcat)
endif()

if(AROS_BUILD_LHA)
  add_subdirectory(lha)
endif()

add_subdirectory(crosstools)
