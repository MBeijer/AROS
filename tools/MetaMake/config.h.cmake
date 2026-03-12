#ifndef CONFIG_H
#define CONFIG_H

#define PACKAGE "@PACKAGE@"
#define PROTOTYPES @PROTOTYPES@
#define VERSION "@VERSION@"

#cmakedefine01 HAVE_DIRENT_H
#cmakedefine01 HAVE_GETCWD
#cmakedefine01 HAVE_INTTYPES_H
#cmakedefine01 HAVE_NDIR_H
#cmakedefine01 HAVE_NETINET_IN_H
#cmakedefine01 HAVE_STDARG_H
#cmakedefine01 HAVE_STDINT_H
#cmakedefine01 HAVE_STDIO_H
#cmakedefine01 HAVE_STDLIB_H
#cmakedefine01 HAVE_STRDUP
#cmakedefine01 HAVE_STRERROR
#cmakedefine01 HAVE_STRINGS_H
#cmakedefine01 HAVE_STRING_H
#cmakedefine01 HAVE_STRNDUP
#cmakedefine01 HAVE_SYS_DIR_H
#cmakedefine01 HAVE_SYS_NDIR_H
#cmakedefine01 HAVE_SYS_STAT_H
#cmakedefine01 HAVE_SYS_TYPES_H
#cmakedefine01 HAVE_UNISTD_H
#cmakedefine01 HAVE_VPRINTF

#define PACKAGE_BUGREPORT "@PACKAGE_BUGREPORT@"
#define PACKAGE_NAME "@PACKAGE_NAME@"
#define PACKAGE_STRING "@PACKAGE_STRING@"
#define PACKAGE_TARNAME "@PACKAGE_TARNAME@"
#define PACKAGE_URL "@PACKAGE_URL@"
#define PACKAGE_VERSION "@PACKAGE_VERSION@"
#define STDC_HEADERS @STDC_HEADERS@

#if HAVE_UNISTD_H
# include <sys/types.h>
# include <unistd.h>
#endif

#if HAVE_DIRENT_H
# include <dirent.h>
# define NAMLEN(dirent) strlen((dirent)->d_name)
#else
# define dirent direct
# define NAMLEN(dirent) (dirent)->d_namlen
# if HAVE_SYS_NDIR_H
#  include <sys/ndir.h>
# endif
# if HAVE_SYS_DIR_H
#  include <sys/dir.h>
# endif
# if HAVE_NDIR_H
#  include <ndir.h>
# endif
#endif

#endif /* CONFIG_H */
