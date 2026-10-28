# the AUR packaging draft

the PKGBUILD installs the 0.2.2 app and its portal backend. installing the
package registers the backend with D-Bus, but it does not select Seabunny in
`portals.conf`. FileChooser stays opt-in, and the other portal preferences stay
where they are. because apparently the whole desktop doesn't need a surprise
renovation.

after the repository has a `v0.2.2` tag, make and inspect the package with
`makepkg -si`. regenerate `.SRCINFO` from `PKGBUILD` before publishing it:

```fish
makepkg --printsrcinfo > .SRCINFO
```

the source points at the matching release tag. no tag, no package download.
publish the release first, then regenerate `.SRCINFO` if the build details change.
