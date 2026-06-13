# mediaremote-adapter (vendored)

Source: https://github.com/ungive/mediaremote-adapter  (commit 3ac3d4b, MIT/BSD-3)
Built locally with:
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build

Artifacts vendored here:
- MediaRemoteAdapter.framework  (built from src/)
- mediaremote-adapter.pl        (bin/)

Used by OpenNook to read Now Playing info and send media commands, since
Apple locked down direct MediaRemote access in macOS 15.4+.
