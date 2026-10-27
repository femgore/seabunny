#!/usr/bin/env fish
# Preview the development chooser without changing the session's active backend.
set --local seabunny_root (path resolve (path dirname (status filename)))
exec /usr/bin/python3 -u -B "$seabunny_root/tests/manual_development_portal.py" $argv
