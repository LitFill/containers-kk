module tests/link-test

import containers/wbt

fun build-tree(xs : list<int>) : tree<int>
  xs.foldl(empty) fn(acc, x) insert(x, acc)

fun main()
  // link: all of l < x < all of r, extreme size ratios
  val l1 = build-tree([1])
  val r1 = build-tree(list(100, 112))
  val link1 = link(50, l1, r1)
  println("link(1,13) valid: " ++ link1.is-valid.show ++ " list: " ++ link1.list.show)

  val l2 = build-tree([1])
  val r2 = build-tree(list(100, 1099))
  val link2 = link(50, l2, r2)
  println("link(1,1000) valid: " ++ link2.is-valid.show)

  val l3 = build-tree(Nil)
  val r3 = build-tree(list(100, 112))
  val link3 = link(50, l3, r3)
  println("link(0,13) valid: " ++ link3.is-valid.show)

  val l4 = build-tree(list(1, 50))
  val r4 = build-tree(Nil)
  val link4 = link(75, l4, r4)
  println("link(50,0) valid: " ++ link4.is-valid.show)

  val l5 = build-tree(list(1, 50))
  val r5 = build-tree(list(100, 149))
  val link5 = link(75, l5, r5)
  println("link(50,50) valid: " ++ link5.is-valid.show)

  // merge: all of l < all of r, extreme size ratios
  val ml1 = build-tree([1])
  val mr1 = build-tree(list(100, 112))
  val merge1 = merge(ml1, mr1)
  println("merge(1,13) valid: " ++ merge1.is-valid.show ++ " list: " ++ merge1.list.show)

  val ml2 = build-tree([1])
  val mr2 = build-tree(list(100, 1099))
  val merge2 = merge(ml2, mr2)
  println("merge(1,1000) valid: " ++ merge2.is-valid.show)

  val ml3 = build-tree(Nil)
  val mr3 = build-tree(list(100, 112))
  val merge3 = merge(ml3, mr3)
  println("merge(0,13) valid: " ++ merge3.is-valid.show)

  val ml4 = build-tree(list(1, 50))
  val mr4 = build-tree(Nil)
  val merge4 = merge(ml4, mr4)
  println("merge(50,0) valid: " ++ merge4.is-valid.show)

  val ml5 = build-tree(list(1, 50))
  val mr5 = build-tree(list(100, 149))
  val merge5 = merge(ml5, mr5)
  println("merge(50,50) valid: " ++ merge5.is-valid.show)