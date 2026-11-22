module tests/verify

import containers/set
import std/core/undiv

// Reference set operations on sorted lists.
fun ref-insert(xs : list<int>, x : int) : list<int>
  match xs
    Nil -> [x]
    Cons(y, ys) -> if x < y then Cons(x, xs) elif x == y then xs else Cons(y, ref-insert(ys, x))

fun lm(xs : list<int>, x : int) : bool
  xs.foldl(False) fn(acc, y) acc || y == x

fun ref-union(xs : list<int>, ys : list<int>) : list<int>
  xs.foldl(ys) fn(acc, x) ref-insert(acc, x)

fun ref-intersect(xs : list<int>, ys : list<int>) : list<int>
  xs.foldl(Nil) fn(acc, x) if lm(ys, x) then ref-insert(acc, x) else acc

fun ref-diff(xs : list<int>, ys : list<int>) : list<int>
  xs.foldl(Nil) fn(acc, x) if lm(ys, x) then acc else ref-insert(acc, x)

fun lcg(seed : int) : int
  val n = seed * 1103515245 + 12345
  n % 2147483647

fun rand-to(seed : int, m : int) : int
  lcg(seed) % m

// Build a sorted reference list from a seed (n inserts).
fun build-list-rec(xs : list<int>, st : int, i : int, n : int) : list<int>
  if i >= n then
    xs
  else
    val st1 = lcg(st)
    val x = rand-to(st1, 40)
    build-list-rec(ref-insert(xs, x), st1, pretend-decreasing(i + 1), n)

fun build-list(seed : int, n : int) : list<int>
  build-list-rec((Nil : list<int>), seed, 0, n)

// Check one round: compare join-based results against the reference.
// Pure (no printing); returns True when all three operations agree.
fun check-round(seed : int) : e bool
  val xs1 = build-list(seed, 20)
  val xs2 = build-list(seed + 1000, 20)
  val s1 = xs1.set
  val s2 = xs2.set
  val u = s1.union(s2)
  val inter = s1.intersection(s2)
  val diff = s1.difference(s2)
  val refu = ref-union(xs1, xs2)
  val refi = ref-intersect(xs1, xs2)
  val refd = ref-diff(xs1, xs2)
  val c1 = u.list == refu
  val c2 = inter.list == refi
  val c3 = diff.list == refd
  val c4 = u.is-valid
  val c5 = inter.is-valid
  val c6 = diff.is-valid
  c1 && c2 && c3 && c4 && c5 && c6

// Run up to `rounds` rounds; return Just(seed) on the first failure, else Nothing.
fun run(seed : int, r : int, rounds : int) : e maybe<int>
  if r >= rounds then
    Nothing
  else
    val ok = check-round(seed)
    if not(ok) then
      Just(seed)
    else
      run(seed + 1, pretend-decreasing(r + 1), rounds)

fun main()
  val result = run(1, 0, 50)
  match result
    Nothing -> println("all join-based correctness checks passed")
    Just(s) ->
      println("FAILED at seed " ++ s.show)
      (1 / 0).println