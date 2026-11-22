# containers-kk — status and plan

Snapshot: 2026-11-23 · version 0.2.0 · `nix build .#default` green · `nix build .#docs` red.

## What the library is

`wbt` (weight-balanced tree) → `set` → `map`, 1,947 lines, 229 public definitions.
The tree stores subtree sizes and rebalances through `balance-left`/`balance-right`
with parameterised `delta`/`gamma` (AFP `25/10/14/10`, Hirayama `3/1/2/1`).
`set` and `map` are thin wrappers; `map` is a `set` of key/value pairs.

## Defects fixed in the working tree

### 1. `wbt/find-le` and `wbt/find-ge` returned wrong results

Both recursed into their **strict** variants, so a key present in the tree was
skipped:

    find-le({1,5}, 5)   → Just(1)   want Just(5)
    find-ge({1,3,5}, 5) → Nothing    want Just(5)

Fix (`wbt.kk`): recurse with `find-le` / `find-ge`, not `find-lt` / `find-gt`.
Reaches `set/find-le`, `set/find-ge`, `map/find-le`, `map/find-ge`.

Verification: brute-force reference over 10 sets × 14 probes × 4 queries
(lt/le/gt/ge) — 0 mismatches. All ten documented examples now match actual output.

### 2. `set/eq` was structural, so equal sets compared unequal

`s1.tree == s2.tree` compared tree shape, so insertion order changed the answer:

    eq({1,2,3,4,5} built ascending, built descending) → False   want True

Fix (`set.kk`): compare sorted lists. This also repairs `map/eq`
(`m.set == n.set`) and `is-subset-of` / `is-proper-subset-of`, which are built on
`union == s2`.

Verification: 8/8 cases, including map equality across insertion orders.

## Name collisions — audit

Koka resolves overloads statically by first-argument type, so sharing a name with
the standard library is harmless. Confirmed by running both directions with
`import containers/set` and `import containers/map` in scope:

| Call | Result |
| --- | --- |
| `xs.map/filter/foldl/foldr/take/drop/partition/index-of/foreach/show` | std version, correct |
| `xs.maximum` / `xs.minimum` | std version (returns `int`, not `maybe<int>`) |
| `s.map/filter/foldl/foldr/show/size/take/drop/partition/split/is-empty` | set version, correct |
| `m.map/filter/foldl/show/size/take` | map version, correct |

Two real ambiguities remain:

1. **`set.map(f)` is ambiguous once `containers/map` is imported.** It collides
   with `map.kk`'s `set/function/map(s : set<k>, f : k -> e v)` — same name, same
   first-argument type. With only `containers/set` imported it resolves fine;
   adding `containers/map` (which most consumers will) breaks it. The awkward
   name is the problem, not the overload set. Rename `set/function/map` to
   something that does not start with `set/` (e.g. `map/from-set`), or accept
   `containers/set/map(...)` qualification.
2. **`map.kk`'s `list/map` is shadowed by std `list/map`.** Same name, same
   first-argument type (`list<...>`); the bare call picks std's and reports a
   missing argument. Reachable as `containers/map/list/map(...)`. Low impact, but
   the builder cannot be called by its documented name.

Non-issues: bare `empty` needs a type annotation when both `set` and `map` are
imported (polymorphic value, expected); `wbt`'s `show`/`size`/`maximum`/`minimum`
never collide because `tree<a>` differs from `list<a>`.

## Plan

### Now

- [ ] Rename `set/function/map` → `map/from-set` (or similar); update the
      `map.kk` doc example that uses `[6, 7].set.map("a".repeat(_))`. This is a
      breaking rename, so do it before 0.3.0 and note it in the commit.
- [ ] Decide on `list/map`: rename to `map/of-list` or keep and document the
      qualified call. The current name is unusable as written.

### Next

- [ ] **Repair the docs build.** `nix build .#docs` fails in `verify_links`:
  - `broken link in src_containers_map-source.html: set.html#_null_`
  - `broken link in src_containers_set-source.html: wbt.html#_null_`
  - `broken anchor in src_containers_map-source.html: src_containers_map.html#map_fs_set`
  - `broken anchor in src_containers_set-source.html: src_containers_set.html#set_fs_tree`

  Koka names pages from the module *path* (`src_containers_set.html`) but emits
  cross-references from the module *name* (`set.html`), and the script's fallback
  only tries `src_set.html`. Either rewrite those hrefs to slugs or align the
  module declarations with the paths (`module containers/set`). The second pair
  of failures is the struct field projection `map/set`: `retarget_anchors` does
  not cover anchors that live only on the API page.

- [ ] **Add tests.** There is no test target; `checks` only builds. Both bugs
  above would have been caught by a property test comparing against sorted-list
  references: neighbour queries, `==`, `is-subset-of`, `is-valid` after mixed
  insert/delete. Wire it as `checks.tests`.

- [ ] **Regenerate `docs/`.** The committed pages predate the `src/containers/`
  restructure (`src_map.html`, `src_set.html`, `src_wbt.html`) and are stale.
  Once the build is green, regenerate and commit, or drop them from the repo and
  publish from CI.

- [ ] **Fix the stale metadata.**
  - `example.kk:8` imports `src/set`; the module is now `containers/set`.
  - README layout section lists `src/wbt.kk`, `src/set.kk`, `src/map.kk`.
  - README says `koki add path:wbt-kk`; the repo is `containers-kk`.
  - README shows `kokaLibraries.…containers-kk.includePath`; the attribute is
    `wbt` (the flake comment on line 157 already says so).

- [ ] **Derive the library's src filter from `srcFor`.** The `default` package
  repeats the filter inline and omits `docs`, so editing `docs/` invalidates the
  library derivation. `srcFor` already excludes it.

- [ ] **Tidy the tree.** `files/` holds a stale flake from another project
  (`pname = "util"`, v0.1.1) and a pre-`shfmt` copy of the docs script; `files.zip`
  and `wbt.hs` are scratch; `result` is a dangling symlink to 0.1.0. Delete or
  commit intentionally.

### Later

- [ ] **Join-based set algebra.** `union`, `difference`, `intersection` are list
  folds (`t1.list.foldl(t2, insert)`), and `is-subset-of` is
  `union(s1, s2) == s2` with a literal `// todo: refactor`. `combine` and
  `split-min` already exist, so an O(m log(n/m+1)) merge is available. This is
  the main performance gap.
- [ ] **`wbt/eq` is now unused by `set`.** It still compares shapes, which is
  correct for a tree but surprising next to value-based `set/eq`. Either document
  it as structural or drop it from the public surface.
- [ ] **Versioning.** Add a changelog; `kokaLibraries` reports `version` from
  `pkgs.koka`, not from `flake.nix`'s `version`, which makes the two disagree in
  metadata.