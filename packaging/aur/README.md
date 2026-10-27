# the AUR packaging draft

the PKGBUILD installs the 0.2.0 app and its portal backend. installing the
package registers the backend with D-Bus, but it does not select Seabunny in
`portals.conf`. FileChooser stays opt-in, and the other portal preferences stay
where they are. because apparently the whole desktop doesn't need a surprise
renovation.

after the repository has a `v0.2.0` tag, make and inspect the package with
`makepkg -si`. regenerate `.SRCINFO` from `PKGBUILD` before publishing it:

```fish
makepkg --printsrcinfo > .SRCINFO
```

the source currently points at the future `v0.2.0` tag. no tag, no package
download. AUR expects the release to exist first; shockingly, it cannot install
a branch that hasn't been pushed yet.
