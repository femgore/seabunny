#!/usr/bin/env fish
set -l application "$HOME/.local/opt/seabunny/current/bin/seabunny"
if not test -x "$application"
    printf 'Seabunny is not installed at %s\n' "$application" >&2
    exit 1
end
exec "$application" $argv
