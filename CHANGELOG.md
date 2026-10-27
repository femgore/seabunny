# changelog

the big bits first. the everyday fixes are in there too, because apparently
those count as features once enough people ask.

## 0.2.1

this release brings the complete 0.2 feature set together: the shared file
browser, the desktop file picker, the larger preview and navigation work, and
the quality fixes that make copying files less of a trust exercise.

- one browser powers both Seabunny windows and the XDG file picker. Open, Save,
  Save Multiple, and Select Folder share the same navigation, sidebar, previews,
  icons, and live colors
- portal dialogs support multiple selection, filters, suggested names, overwrite
  confirmation, cancellation, choices, and separate saved sidebar state. they
  don't read or write the files for the application that opened the dialog
- new launches make a separate window when Seabunny isn't focused. when it is,
  the new tab goes to the focused Seabunny window
- tabs, split view, recursive search, Quick Look, batch rename, and asynchronous
  background jobs with progress and cancellation
- larger thumbnails, square grid cells, column-by-column Ctrl+scroll zoom, and
  selection highlights that match each item's actual hitbox
- live Serpantinum colors, light and dark palettes, reduced motion, and
  Phosphor, Serpantinum Symbols, System, and Adwaita icon choices
- Open With, remembered app defaults, direct executable and AppImage launching,
  and a Make executable switch in Properties
- matching folders can merge with per-file collision choices, apply-to-all,
  cancellation, and grouped undo/redo
- per-folder sorting is saved only when it differs from the default. hidden files
  are shown by default, and explorer and picker remember their sidebars separately
- network bookmarks are handed to the desktop's URI handler; Seabunny keeps its
  own local file navigation
- copy, move, archive extraction, and cut clipboard handling use safer
  background operations, with failed or skipped sources left available
- release automation prepares Arch, Debian, RPM, AppImage, standalone, and
  user-installable downloads with SHA-256 checksums

the portal remains opt-in. installing the backend doesn't change which portal
handles FileChooser, or touch screen sharing and the rest of the desktop setup.
release downloads appear after the package builds and checksum step succeed.

## earlier 0.2 work included here

the 0.2.0 feature set is part of this release too: Seabunny branding, the
standalone portal, large thumbnails and zoom, live colors, all icon choices,
Open With, executable permissions, folder merging, sparse sorting memory,
default hidden files, independent sidebar persistence, and the chooser's open,
save, multiple-save, and folder modes. the gallery and limitations are described
in the [release notes](NEXT-VERSION.md).
