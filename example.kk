module example

// Run this from the dev shell, where the library is on the include path:
//
//     nix develop
//     koka -o example example.kk && ./example

import src/set

fun testing-set()
  var s : set<int> := empty
  [1, 66, 3,5, 6, 7, 5, 4, 3, 3, 3, 4, 5, 6, 7, 8, 8, 8, 7, 6, 4, 32, 2, 2].foreach fn(x)
    s := x.insert(s)
  s

fun main()
  val s = testing-set()
  s.println
  s.size.println
  s.member(23).println
  println("hello")
