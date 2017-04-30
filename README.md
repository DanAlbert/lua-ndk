# Lua NDK Cross-Compilation Example

This project is intended as an example of how to port Linux software for use
with the NDK. To build:

```bash
NDK=/path/to/ndk ./build_lua.sh
```

This command will build Lua and its dependencies for Android. Note that at the
time of writing, this will only succeed with a not-yet-released NDK (NDK r15
beta 2, due to release at Google I/O on 17 May 2017) when targeting an
unreleased version of Android (Android O). Providing support for old releases of
Android is something we will be improving with the NDK compatibility library
(see [our roadmap] for details).

The reason this doesn't work until O is because Android didn't have `setpwent`
in libc until then.

For more information about what was needed for this port, see the comments in
[build\_lua.sh](build_lua.sh).

[our roadmap]: https://android.googlesource.com/platform/ndk/+/master/docs/Roadmap.md
