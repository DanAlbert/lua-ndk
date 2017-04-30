#!/bin/bash

if [[ -z "$NDK" ]]; then
  >&2 echo "\$NDK must point to your Android NDK."
  exit 1
fi

# The NDK's standalone toolchains are the simplest way to port arbitrary code to
# the NDK. These build a single target cross compiler that can be invoked
# directly rather than needing to fiddle with various cross compilation flags.
#
# For more information about standalone toolchains, see our documentation:
# https://developer.android.com/ndk/guides/standalone_toolchain.html
$NDK/build/tools/make_standalone_toolchain.py \
  --arch arm --api 14 --stl libc++ --install-dir=toolchain --force
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to create toolchain."
  exit 1
fi

toolchain/bin/clang lua/*.c -landroid_support -lm -o lua.exe
if [[ $? -ne 0 ]]; then
  >&2 echo "Failed to build lua."
  exit 1
fi

echo "Successfully built lua!"
