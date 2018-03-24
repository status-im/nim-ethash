# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).


# Pending https://github.com/alehander42/zero-functional/issues/6
# A zip + map that avoids heap allocation
iterator enumerateZip[N: static[int], T, U](
                      a: array[N, T],
                      b: array[N, U]
                    ): (int, T, U) {.inline, noSideEffect.}=
  for i in 0 ..< N:
    yield (i, a[i], b[i])

template zipMap*[N: static[int], T, U](
                      a: array[N, T],
                      b: array[N, U],
                      op: untyped): untyped =
  ## Inline zip + map of an operation
  ## Use proc(x, y) or x `proc` y (x and y are injected inline into the template)
  ## For example `zipMap(foo, bar, x xor y) to take the xor of foo and bar

  type outType = type((
    block:
      var x{.inject.}: T;
      var y{.inject.}: U;
      op
  ))

  {.pragma: align64, codegenDecl: "$# $# __attribute__((aligned(64)))".}
  var result{.noInit, align64.}: array[N, outType]

  for i, x {.inject.}, y {.inject.} in enumerateZip(a, b):
    {.unroll: 4.} # This is a no-op at the moment
    result[i] = op

  result
