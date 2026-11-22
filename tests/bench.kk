module tests/bench

import containers/set
import containers/map
import containers/wbt

// Benchmark sizes
val small = 1000
val medium = 10000
val large = 100000

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