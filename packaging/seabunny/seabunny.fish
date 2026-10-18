#!/usr/bin/env fish
set -l application "$HOME/.local/opt/seabunny/current/bin/seabunny"
if not test -x "$application"
    printf 'Seabunny is not installed at %s\n' "$application" >&2
    exit 1
end
if not set -q SEABUNNY_SERPANTINUM_COLORS; or test -z "$SEABUNNY_SERPANTINUM_COLORS"
    if set -q QS_COLORS_JSON; and test -r "$QS_COLORS_JSON"
        set -gx SEABUNNY_SERPANTINUM_COLORS "$QS_COLORS_JSON"
    else
        set -l state "$HOME/.local/state"
        if set -q XDG_STATE_HOME; and test -n "$XDG_STATE_HOME"
            set state "$XDG_STATE_HOME"
        end
        for palette in "$state/serpantinum/qs_colors.json"
            if test -r "$palette"
                set -gx SEABUNNY_SERPANTINUM_COLORS "$palette"
                break
            end
        end
    end
end
exec "$application" $argv
