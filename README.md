# wbt-kk

Weight Balanced Tree for Koka

## Using it

From another Koka project:

    koki add path:wbt-kk

or by hand, in that project's `flake.nix`:

    inputs.my-lib.url = "path:../wbt-kk";

```nix
kokaLibsFor = pkgs: [
  self.inputs.my-lib.kokaLibraries.${pkgs.stdenv.hostPlatform.system}.wbt.includePath
];
```

## Layout

- `src/wbt.kk` — the library itself
- `example.kk` — a tiny program that imports it
- `flake.nix` — the build, and the `kokaLibraries` output other flakes use

## Commands

    koki build      # nix build
    koki check      # nix flake check
    koki dev        # nix develop
