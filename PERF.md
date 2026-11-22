# containers-kk — Performance Improvements

Snapshot: 2026-11-23 · version 0.5.0

## Since v0.4.0

`tests/bench.kk` as it stands now, 100k-element sets and maps, wall clock for
the whole program:

| Version | Time |
| --- | --- |
| v0.4.0 | 23.4s |
| This change | **2.46s** |

9.5x, and nearly all of it is the index phase: 1000 `s[i]` lookups went from
18.7s to 6ms.

Per operation (n = 100000, `std/time` around the call):

| Operation | v0.4.0 | Now | Note |
| --- | --- | --- | --- |
| `s[50000]` | 18.7 ms | 6 µs | rank walk on stored sizes |
| `s.take(1000)` | 28 ms | 8 µs | idem |
| `set.foreach` | 18.7 ms | 4.0 ms | no intermediate list |
| `set.filter` | 357 ms | 21.9 ms | join rebuild instead of n inserts |
| `map.filter` | 379 ms | 32.2 ms | follows `set/filter` |
| `map.map` | 829 ms | 37.3 ms | shape-preserving rebuild |
| `set.map` | 781 ms | 843 ms | unchanged, see below |

### What changed

1. **Rank-based indexing** (`wbt.kk`): `wbt/at`, `wbt/take`, `wbt/drop` walk
   the spine using the `size` field every node already carries; `take`/`drop`
   rebuild with `link` so the balance ratio holds for whatever sizes come out.
   `set/@index`, `set/at`, `set/take`, `set/drop` use them instead of
   `s.list.@index(i)` / `s.list-op(_.take)`, which flattened the whole set.
   `delete-at`, `split-at`, `update-at` and the `*_at` map functions inherit it.
2. **`set/foreach`** walks the tree (`s.tree.foldl`) instead of `s.list.foreach`.
   `filter'` and `cartesian-product` go through it.
3. **`set/map-monotonic`** — `map` that keeps the tree shape, O(n). `map/map`,
   `map/map-with-key` and `map/bimap` use it: their keys are unchanged (or
   documented strictly monotone), so no re-sort is needed. Before, all three
   went through `set/map` = list round-trip plus n inserts.
4. **`wbt/filter`** rebuilds bottom-up with `link`/`merge`. `set/filter` (and
   `filter'`, `map/filter`, `filter-keys`, `restrict-keys`, `without-keys`) use
   it.

## Since v0.3.0

The first round, recorded here because it set up everything above.

| Version | Time |
| --- | --- |
| Original (list-fold set algebra, `list.last/head` max/min) | 2.57s |
| `union` join-based; `intersection`/`difference` still folds | 1.82s |
| All three join-based, `set` delegating to `wbt` (v0.4.0) | 1.31s |

(Those numbers are from the older, smaller `bench.kk`; the file has since grown
the foreach/index/map/filter phases, which is why the totals are not comparable
with the table above.)

1. **Join-based set algebra** (`wbt.kk`): `union`/`intersection`/`difference`
   use `split` + `link`/`merge` ("Just Join"), O(m log(n/m+1)) instead of
   O(n log m). The classic `combine` survives as `glue`, used only by `delete`,
   where the subtrees are already within the balance ratio.
2. **`set.kk` delegates to it**, with qualified calls (`wbt/union` and friends)
   because `set` and `map` define their own `union`, `intersection`,
   `difference` and `split`.
3. **Tree-direct `foldl`/`foldr`**, **O(log n) `maximum`/`minimum`**,
   **`is-subset-of`** without building a union, **`split-max`**.

Bugs fixed along the way: `maximum` matched the *minimum* pattern
(`Node(x, Leaf, _)`); `insert-with` recursed with `insert` instead of
`insert-with`, so the combining function only ran at the root.

## Why link/merge instead of fixing combine

`combine` is the classic *glue* operation — valid only when both trees are
already within the balance ratio, i.e. when they are the two children of a
valid node. `delete` meets that precondition; a top-level `union` of two
arbitrary sets does not, which is why a single "more general" rotation is the
wrong fix: one rotation is the correct tool exactly when the imbalance is
bounded, and `glue` is the right tool exactly when the sizes are.

The standard answer (Adams 1993, Hirai–Yamamoto 2011, Blelloch et al. "Just
Join") is to keep the rotations as they are and add a descending `link`/`merge`
that walks down the spine of the heavier tree until the sizes are comparable,
then rebuilds on the way back up, doing at most one rebalance per level. Each
step then has bounded imbalance, so the existing `balance-*` are sufficient.

## Balance parameters

`afp/params` (Δ=2.5, Γ=1.4) is the default. `hirayama/params'` (Δ=3, Γ=2) is
also exported. The join checks in `tests/verify.kk` run under both, which is
the empirical answer to "is the Just Join range satisfied here" — the proof in
Blelloch et al. covers a range of α and both parameter sets sit inside the
range we exercise.

## Other future work

- `set.map` (843 ms) is now the dominant cost in the benchmark and cannot be
  improved for a non-monotone `f`: it is inherently O(n log n). It could skip
  the intermediate list and insert straight from a tree walk (~17 ms).
- `set.union-with` / `wbt.union-with` still fold over `t2.list`
  (788 ms at n=100000); it can go join-based the way `union` does.
- `set.symmetric-difference` (862 ms) builds two sets with per-element inserts;
  `(s1 \ s2) ++ (s2 \ s1)` with the join-based `difference`/`union` would be
  far cheaper.
- `set.take-while-antitone` / `drop-while-antitone` / `span-antitone` and
  `set.index-of` still go through `s.list`.
- Reduce allocation in `insert`/`delete` hot paths.
- `wbt/eq` (structural) is unused by `set` — document or drop.