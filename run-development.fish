#!/usr/bin/env fish
# Keep development preferences separate from the installed application.
set --local seabunny_root (path resolve (path dirname (status filename)))
set --local seabunny_binary "$seabunny_root/target/release/seabunny"
set --local seabunny_profile "$seabunny_root/target/development-profile"
if not test -x "$seabunny_binary"
    echo 'Build this checkout first: cargo build --release --locked' >&2
    exit 1
end
for directory in config data cache state
    mkdir -p -- "$seabunny_profile/$directory"; or exit 1
end
env XDG_CONFIG_HOME="$seabunny_profile/config" \
    XDG_DATA_HOME="$seabunny_profile/data" \
    XDG_CACHE_HOME="$seabunny_profile/cache" \
    XDG_STATE_HOME="$seabunny_profile/state" \
    "$seabunny_binary" --new-window $argv
