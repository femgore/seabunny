#!/usr/bin/env fish
set -l here (path dirname (status filename))
python3 "$here/package_user.py" install $argv
