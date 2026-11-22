module tests/bench

import containers/set
import containers/map
import containers/wbt

// Benchmark sizes
val small = 1000
val medium = 10000
val large = 100000

fun bump(x : int) : int
  x + 1

fun mod2(x : int) : bool
  x % 2 == 0

fun main()
  println("=== Union benchmark ===")
  val s1 = list(1, large).set
  val s2 = list(large/2, large).set
  val u = s1.union(s2)
  println("union size: " ++ u.size.show)

  println("\n=== Intersection benchmark ===")
  val i = s1.intersection(s2)
  println("intersection size: " ++ i.size.show)

  println("\n=== Difference benchmark ===")
  val d = s1.difference(s2)
  println("difference size: " ++ d.size.show)

  println("\n=== Maximum/Minimum benchmark ===")
  val max = s1.maximum
  val min = s1.minimum
  println("maximum: " ++ max.show)
  println("minimum: " ++ min.show)

  println("\n=== Fold benchmark ===")
  val sum1 = s1.foldl(0, fn(acc, x) acc + x)
  val sum2 = s1.foldr(0, fn(x, acc) x + acc)
  println("foldl sum: " ++ sum1.show)
  println("foldr sum: " ++ sum2.show)

  println("\n=== is-subset-of benchmark ===")
  val s_small = list(1, small).set
  val sub = s_small.is-subset-of(s1)
  println("is-subset-of: " ++ sub.show)

  println("\n=== Foreach benchmark ===")
  var visited := 0
  s1.foreach fn(x) visited := visited + 1
  println("foreach count: " ++ visited.show)

  println("\n=== Index benchmark ===")
  val at = s1[large/2]
  println("s1[large/2]: " ++ at.show)
  val tk = s1.take(small)
  val dr = s1.drop(small)
  println("take/drop size: " ++ tk.size.show ++ "/" ++ dr.size.show)
  var acc := 0
  var ix := 0
  while { ix < small }
    acc := acc + s1[ix * 100].default(0)
    ix := ix + 1
  println("1000 lookups sum: " ++ acc.show)

  println("\n=== Map benchmark ===")
  val m : map<int, int> = list(1, large).foldl((empty : map<int, int>)) fn(z, x) z.insert(x, x)
  val m2 = m.map(bump)
  println("map size: " ++ m2.size.show ++ "  sum: " ++ m2.foldl(0, fn(z, v) z + v).show)

  println("\n=== Filter benchmark ===")
  val ev = s1.filter(mod2)
  println("filtered size: " ++ ev.size.show)
  val mev = m.filter(mod2)
  println("map filtered size: " ++ mev.size.show)