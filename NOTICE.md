# the legal bits

the boring legal shit. still matters.

i maintain seabunny as femgore. it also includes earlier application code by
m-uvex, and the existing contributor notices are still in the source.

## the application license, or the unresolved bit

the imported application's README said MIT, but the source snapshot didn't come
with a standalone application license or an original copyright notice. this repo
doesn't add a new license grant for that code. that needs sorting out before
public redistribution or publishing binary packages. a README saying MIT doesn't
magically fill in the missing paperwork.

## the fonts brought their paperwork

the fonts have their own notices:

- Phosphor icon fonts: MIT; see `assets/fonts/Phosphor-LICENSE.txt`.
- Symbols Nerd Font: MIT; see `assets/fonts/NerdFontsSymbolsOnly-LICENSE.txt`.

the rust dependencies and qt/kde libraries keep their own licenses. the artwork
and screenshots were supplied by the repository owner; the font licenses don't
cover those. putting things in the same folder doesn't merge their licenses.

if you have the missing application license or a correction to these notices,
please open an issue with the source. actual documentation would help here.
