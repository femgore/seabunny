# changelog

the useful changes. the tiny fixes. the bits that took longer than they had any
right to. in roughly that order.

## 0.2.0

this is the upstream-based rebuild. it keeps the features that made seabunny
seabunny, and borrows the newer file model and background-job plumbing from
[Loaf](https://github.com/m-uvex/loaf-fm). one browser now serves both the normal
file manager and the portal picker. maintaining two almost-identical browsers
would have been an extremely dumb hobby.

- brought back live Serpantinum colors, the icon choices, larger thumbnails,
  grid zoom, and the bits of the old layout everyone kept asking about
- added Open With, remembered app defaults, executable and AppImage launching,
  and the make-executable switch in Properties
- added folder merging with per-file collision choices, apply-to-all, and undo
- kept sparse per-folder sorting, hidden files by default, and separate saved
  sidebar width and open/closed state for explorer and picker
- added the standalone XDG portal backend for open, save, multiple-save, and
  folder selection, with filters, cancellation, suggested names, and overwrite
  confirmation
- fixed a few upstream copy and thumbnail-lifecycle footguns while moving the
  feature set over
- fixed zoom reflow and selection hitboxes so the highlight follows the actual
  item instead of hovering over the empty space next to it

the app and portal both report 0.2.0. the portal remains opt-in: installing its
backend doesn't change which portal handles FileChooser, and it doesn't touch
screen sharing or the rest of your desktop setup.

the gallery still shows the old layout, because screenshots are a whole other
errand. SMB, sharing, removable-drive disconnects, and privileged operations
still need real-world testing. the upstream MIT license is now included, so the
legal folder is slightly less embarrassing. bundled fonts still have their own
notices; see [NOTICE.md](NOTICE.md).
