#!/usr/bin/env fish
set -l karing_project_root (realpath (path dirname (status filename))/..)
set -gx LD_LIBRARY_PATH "$karing_project_root/build/linux/x64/debug/bundle/lib" $LD_LIBRARY_PATH
set -l karing_local_libraries "$karing_project_root/.dart_tool/linux-toolchain/usr/lib/x86_64-linux-gnu"
if test -d "$karing_local_libraries"
    set -gx LD_LIBRARY_PATH "$karing_local_libraries" $LD_LIBRARY_PATH
end
exec "$karing_project_root/build/linux/x64/debug/bundle/karing" $argv
