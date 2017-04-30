#!/bin/bash
JOBS=48

if [[ -z "$NDK" ]]; then
  >&2 echo "\$NDK must point to your Android NDK."
  exit 1
fi

major=$(grep -oP 'Pkg\.Revision = \K\d+(?=\..*)' $NDK/source.properties)
beta=$(grep -oP 'Pkg\.Revision = .*-beta\K\d+' $NDK/source.properties)

if [[ "$major" -lt 15 ]]; then
  >&2 echo "NDK must be at least r15 beta 2."
  exit 1
fi

if [[ "$major" -eq 15 ]]; then
  if [[ "$beta" -lt 2 ]]; then
    >&2 echo "NDK must be at least r15 beta 2."
    exit 1
  fi
fi

# The NDK's standalone toolchains are the simplest way to port arbitrary code to
# the NDK. These build a single target cross compiler that can be invoked
# directly rather than needing to fiddle with various cross compilation flags.
#
# For more information about standalone toolchains, see our documentation:
# https://developer.android.com/ndk/guides/standalone_toolchain.html
$NDK/build/tools/make_standalone_toolchain.py \
  --arch arm --api 26 --install-dir=toolchain --force
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to create toolchain."
  exit 1
fi

# Building libreadline is a little clunky because the config.guess that’s
# shipped with it is so old it doesn’t know about Android. Following
# http://stackoverflow.com/a/20152865/632035, we can fix this by copying the
# newer copy from our system.
cp config.{sub,guess} readline-5.2/support/

cd readline-5.2

# libreadline has a header file that is not compatible with C libraries that
# enable FORTIFY support for Clang. FORTIFY'd functions are marked with
# `__attribure__((overloadable))`, which makes redefinitions of those functions
# without that attribute incompatible. Fortunately, the redefinition in
# libreadline is superfluous.
#
# For more information about FORTIFY, see our blog post on the subject:
# https://android-developers.googleblog.com/2017/04/fortify-in-android.html
if [[ ! -e .already_patched ]]; then
  patch -p1 < ../readline-no-redef.patch
  if [[ $? -ne 0 ]]; then
    >&2 echo "Failed to patch libreadline."
    exit 1
  fi
  touch .already_patched
fi

CC=`realpath ../toolchain/bin/clang` ./configure \
  --prefix `realpath ..`/libreadline --host arm-linux-androideabi
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to configure libreadline."
  exit 1
fi

make -j$JOBS install
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to build libreadline."
  exit 1
fi

cd ../ncurses-5.9

# ncurses 5.9 doesn't build with Clang out of the box. Fortunately the home brew
# folks have already dug into this problem for us:
# https://github.com/Homebrew/homebrew-dupes/issues/43#issuecomment-6936547
if [[ ! -e .already_patched ]]; then
  patch -p1 < ../ncurses-clang.patch
  if [[ $? -ne 0 ]]; then
    >&2 echo "Failed to patch libncurses."
    exit 1
  fi
  touch .already_patched
fi

CC=`realpath ../toolchain/bin/clang` CXX=`realpath ../toolchain/bin/clang++` \
  ./configure --prefix `realpath ..`/libncurses --host arm-linux-androideabi
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to configure libncurses."
  exit 1
fi

make -j$JOBS install
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to build libncurses."
  exit 1
fi

cd ../lua

# The Lua makefile isn’t particularly welcoming of cross compiling. It assumes
# that libreadline is available in the system paths, and it assumes that termcap
# APIs are available in libc. We can make it work with a couple simple
# modifications though.
if [[ ! -e .already_patched ]]; then
  patch -p1 < ../lua-crosscompile.patch
  if [[ $? -ne 0 ]]; then
    >&2 echo "Failed to patch lua."
    exit 1
  fi
  touch .already_patched
fi

make -j$JOBS \
  CC=`realpath ../toolchain/bin/clang` \
  LIBREADLINE_PATH=`realpath ../libreadline` \
  LIBNCURSES_PATH=`realpath ../libncurses`

if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to build lua."
  exit 1
fi

echo "Successfully built lua!"
