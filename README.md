# containers-kk

Koka weight-balanced tree containers library.

## Using it

From another Koka project:

    koki add path:wbt-kk

or by hand, in that project's `flake.nix`:

    inputs.containers-kk.url = "github:LitFill/containers-kk";

```nix
kokaLibsFor = pkgs: [
  self.inputs.containers-kk.kokaLibraries.${pkgs.stdenv.hostPlatform.system}.containers-kk.includePath
];
```

## Layout

- `src/wbt.kk` — Weight balanced trees
- `src/set.kk` — Sets defined in term of WBTs
- `src/map.kk` — Maps defined in term of WBTs
- `example.kk` — a tiny program that imports it
- `flake.nix` — the build, and the `kokaLibraries` output other flakes use

## Commands

    koki build      # nix build
    koki check      # nix flake check
    koki dev        # nix develop
