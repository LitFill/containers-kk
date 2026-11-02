{
  description = "Koka weight-balanced tree containers library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # koki:inputs:start
    # koki:inputs:end
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      pname = "containers";
      version = "0.1.0";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);

      # One Koka include directory per dependency. `koki add` writes the
      # lines between the markers below and `koki remove` takes them out;
      # the compiler flags and the editor include list further down are both
      # derived from them, so they cannot drift out of step with each other.
      kokaLibsFor = pkgs: [
        # koki:libs:start
        # koki:libs:end
      ];

      # `--include` flags for the compiler.
      kokaLibArgs = pkgs: builtins.concatStringsSep " " (map (d: "--include=${d}") (kokaLibsFor pkgs));

      # The same list as a `koka.json` `include_dirs` array, which is what
      # editors and the Koka language server read.
      kokaJson =
        pkgs:
        ''{"include_dirs":[${builtins.concatStringsSep "," (map (d: "\"${d}\"") (kokaLibsFor pkgs))}]}'';

      srcFor =
        pkgs:
        pkgs.lib.cleanSourceWith {
          name = "${pname}-source";
          src = pkgs.lib.cleanSource self;
          filter =
            path: type:
            !(builtins.elem (baseNameOf (toString path)) [
              "result"
              "koka.json"
              ".koka"
              ".koka-build"
              ".direnv"
              "docs"
            ]);
        };
    in
    {

      packages = forAllSystems (
        pkgs: system: {
          default = pkgs.stdenv.mkDerivation {
            inherit pname version;
            src = pkgs.lib.cleanSourceWith {
              src = self;
              filter =
                path: type:
                let
                  base = baseNameOf (toString path);
                in
                !(builtins.elem base [
                  "result"
                  "koka.json"
                  ".koka"
                ]);
            };
            nativeBuildInputs = [
              pkgs.koka
              pkgs.stdenv.cc
            ];

            buildPhase = ''
              runHook preBuild
              koka -l --output=containers --builddir="$PWD/.koka-build" src/containers.kk src/containers/*
              runHook postBuild
            '';

            # A Koka library is its source: consumers resolve it with
            # `--include=<includePath>` and compile against these modules.
            installPhase = ''
              runHook preInstall
              dest=$out/share/koka/${pkgs.koka.version}
              mkdir -p $dest
              cp src/containers.kk $dest/
              cp -r src/containers $dest/
              chmod -R u+w,a+r $dest
              runHook postInstall
            '';

            meta = {
              description = "Koka weight-balanced tree containers library";
              platforms = pkgs.lib.platforms.unix;
            };
          };

          docs = pkgs.stdenv.mkDerivation {
            pname = "${pname}-docs";
            inherit version;
            src = srcFor pkgs;

            nativeBuildInputs = [
              pkgs.koka
            ];

            dontConfigure = true;

            buildPhase = ''
              runHook preBuild

              # The sandbox has a read-only, nonexistent $HOME; give koka
              # somewhere writable in case it wants a cache/config dir.
              export HOME="$TMPDIR"

              # Invoked through bash explicitly: the build sandbox has no
              # /usr/bin/env for the script's shebang to resolve.
              # KOKA_FLAGS carries the dependency `--include` flags so the
              # docs can be built for modules that import other libraries.
              KOKA=${pkgs.koka}/bin/koka \
              KOKA_FLAGS="${kokaLibArgs pkgs}" \
              PROJECT_NAME=${pname} \
                bash scripts/build-docs.sh docs

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              test -n "$(ls -A docs)" || { echo "docs/ is empty" >&2; exit 1; }
              mkdir -p "$out"
              cp -r docs/. "$out/"
              runHook postInstall
            '';

            # Cheap to build and not worth a remote builder round-trip.
            preferLocalBuild = true;

            meta = {
              description = "API reference for this library";
              platforms = pkgs.lib.platforms.unix;
            };
          };
        }
      );

      # How a consuming flake reaches this library. `koki add` writes
      # `self.inputs.<input>.kokaLibraries.<system>.wbt.includePath`
      # when this flake is added as a dependency.
      kokaLibraries = forAllSystems (
        pkgs: system: {
          wbt = {
            path = self.packages.${system}.default;
            includePath = "${self.packages.${system}.default}/share/koka/${pkgs.koka.version}";
            version = pkgs.koka.version;
            libVersion = self.packages.${system}.default.version;
          };
        }
      );

      apps = forAllSystems (
        pkgs: system: {
          docs = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "gen-docs";
                runtimeInputs = [
                  pkgs.koka
                  pkgs.stdenv.cc # `koka -l` compiles C; not on PATH outside a devShell
                  pkgs.bash # a recent bash for the script (macOS ships 3.2)
                  pkgs.git
                ];
                text = ''
                  # Selalu tulis ke <root repo>/docs, dari subfolder mana pun
                  # perintah ini dijalankan.
                  cd "$(git rev-parse --show-toplevel)"

                  KOKA=${pkgs.koka}/bin/koka \
                  KOKA_FLAGS="${kokaLibArgs pkgs}" \
                  PROJECT_NAME=${pname} \
                    bash scripts/build-docs.sh docs
                '';
              }
            }/bin/gen-docs";
          };
        }
      );

      devShells = forAllSystems (
        pkgs: system: {
          default =
            with pkgs;
            mkShell {
              packages = [
                koka
                shfmt
                shellcheck
              ];
              shellHook = "printf '%s\\n' '${kokaJson pkgs}' > \"$PWD/koka.json\"";
            };
        }
      );

      checks = forAllSystems (
        pkgs: system: {
          build = self.packages.${system}.default;
        }
      );
    };
}
