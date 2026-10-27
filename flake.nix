{
  description = "seabunny - Material 3 Expressive file manager in Rust and QML";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        qtEnv = pkgs.qt6.env "qt6-env" [
          pkgs.qt6.qtbase
          pkgs.qt6.qtdeclarative
          pkgs.qt6.qtsvg
          pkgs.qt6.qtwayland
        ];
      in {
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "seabunny";
          version = "0.2.1";
          src = ./.;
          cargoLock = {
            lockFile = ./Cargo.lock;
          };
          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
            ninja
            rustc
            cargo
          ];
          buildInputs = [
            qtEnv
            pkgs.libGL
            pkgs.kdePackages.kwindowsystem
            pkgs.glib
            pkgs.python3
            pkgs.libarchive
            pkgs.p7zip
            pkgs.zip
          ];
          QMAKE = "${qtEnv}/bin/qmake";
          QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
          QML2_IMPORT_PATH = "${qtEnv}/lib/qt-6/qml";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ qtEnv pkgs.libGL ]}";
          postInstall = ''
            install -Dm644 packaging/seabunny/org.femgore.Seabunny.desktop $out/share/applications/org.femgore.Seabunny.desktop
            install -Dm644 packaging/seabunny/org.femgore.Seabunny.svg $out/share/icons/hicolor/scalable/apps/org.femgore.Seabunny.svg
          '';
        };
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/seabunny";
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            pkg-config
            cmake
            ninja
            rustc
            cargo
            rustfmt
            clippy
          ];

          buildInputs = [
            qtEnv
            pkgs.libGL
            pkgs.kdePackages.kwindowsystem
            pkgs.glib
            pkgs.python3
            pkgs.libarchive
            pkgs.p7zip
            pkgs.zip
          ];

          QMAKE = "${qtEnv}/bin/qmake";
          QT_PLUGIN_PATH = "${qtEnv}/lib/qt-6/plugins";
          QML2_IMPORT_PATH = "${qtEnv}/lib/qt-6/qml";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ qtEnv pkgs.libGL ]}:$LD_LIBRARY_PATH";
          LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ qtEnv pkgs.libGL ]}:$LIBRARY_PATH";
        };
      });
}
