#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# Windows MSVC / Clang Compatibility Shims
# ==============================================================================
if [[ "${target_platform:-}" == win-* || "$OSTYPE" == "msys" ]]; then
    mkdir -p tools/chafa

    # strings.h: Map POSIX string comparison functions to MSVC CRT
    cat << 'EOF' > strings.h
#pragma once
#include <string.h>
#ifndef strcasecmp
#define strcasecmp _stricmp
#endif
#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif
EOF
    cp strings.h tools/chafa/strings.h

    # unistd.h: Provide ssize_t, POSIX I/O constants, and remap to MSVC CRT
    cat << 'EOF' > unistd.h
#pragma once
#include <io.h>
#include <process.h>
#include <sys/stat.h>
#include <string.h>
#include <stddef.h>
#include <stdio.h>

#ifndef _SSIZE_T_DEFINED
#define _SSIZE_T_DEFINED
typedef ptrdiff_t ssize_t;
#endif

#ifndef strcasecmp
#define strcasecmp _stricmp
#endif
#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif

#ifndef STDIN_FILENO
#define STDIN_FILENO 0
#endif
#ifndef STDOUT_FILENO
#define STDOUT_FILENO 1
#endif
#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif

#ifndef S_IRUSR
#define S_IRUSR 0000400
#endif
#ifndef S_IWUSR
#define S_IWUSR 0000200
#endif
#ifndef S_IXUSR
#define S_IXUSR 0000100
#endif
#ifndef S_IRWXU
#define S_IRWXU (S_IRUSR | S_IWUSR | S_IXUSR)
#endif

#define read    _read
#define write   _write
#define close   _close
#define lseek   _lseek
#define isatty  _isatty
#define fileno  _fileno
#define setmode _setmode
#define open    _open
EOF
    cp unistd.h tools/chafa/unistd.h

    # Supply an empty manifest object to satisfy the tools/chafa Makefile target
    clang.exe -c -x c /dev/null -o tools/chafa/manifest.o

    # Neutralize GCC CPU detection builtins absent in clang-cl
    sed -i 's/__builtin_cpu_init[[:space:]]*()/((void)0)/g' \
        chafa/chafa-features.c \
        chafa/internal/smolscale/smolscale.c

    sed -i 's/__builtin_cpu_supports[[:space:]]*([^)]*)/(0)/g' \
        chafa/chafa-features.c \
        chafa/internal/smolscale/smolscale.c

    # Windows native pkgconf requires semicolon (;) path separation
    export PKG_CONFIG_PATH="$(cygpath -m "$PREFIX/lib/pkgconfig");$(cygpath -m "$PREFIX/share/pkgconfig")"
    export WINDRES="llvm-windres"
    export LDFLAGS="${LDFLAGS} -L$(cygpath -m "$PREFIX/lib") -loldnames"

    # Force discovery and linking of libavif
    export AVIF_CFLAGS="-I$(cygpath -m "$PREFIX/include")"
    export AVIF_LIBS="-L$(cygpath -m "$PREFIX/lib") -lavif"

    # Wrap make to apply patch_libtool after configure and maintain manifest.o
    make() {
        if [ -f libtool ]; then
            patch_libtool
        fi
        if [ -f tools/chafa/Makefile ]; then
            touch tools/chafa/manifest.o
        fi
        command make "$@"
    }
    export -f make
fi

# ==============================================================================

# By installing from a release tar-ball (see meta.yaml), we avoid the
# need for ./autogen.sh and additional dependencies

./configure \
    --disable-debug \
    --disable-dependency-tracking \
    --prefix="${PREFIX}" \
    --disable-silent-rules
make install
