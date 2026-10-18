#!/usr/bin/env fish
set -l here (path dirname (status filename))
if not test -x "$here/target/release/seabunny"
    printf 'Build Seabunny first with cargo build --release --locked\n' >&2
    exit 1
end
exec "$here/target/release/seabunny" $argv
