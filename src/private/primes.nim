# Copyright (c) 2018-2024 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

# Primality testing. TODO: a scalable implementation (i.e. Miller-Rabin)
# See https://github.com/mratsim/nim-projecteuler/blob/master/src/lib/primes.nim

import ./intmath

func isPrime*[T: SomeUnsignedInt](x: T): bool =
  for i in 2.T .. isqrt x:
    if x mod i == 0:
      return false
  return true

func isPrime*(x: Natural): bool =
  for i in 2 .. isqrt x:
    if x mod i == 0:
      return false
  return true
