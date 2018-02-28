# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

include ../src/mining

import unittest, random

suite "[Internal] Testing multi-precision arithmetic":
  test "Multi-Precision multiplication gives the proper unit (modulo 2^64)":

    randomize(42) # random seed for reproducibility
    for _ in 0 ..< 10_000_000:
      let
        a = random(high(int)).uint64
        b = random(high(int)).uint64

      check: a * b == mulCarry(a, b).unit


  test "Multi-Precision multiplication gives the proper carry (TODO: improve tests)":

    check: mulCarry(2'u64^32, 2'u64^31).carry == 0
    check: mulCarry(2'u64^32, 2'u64^32).carry == 1
    check: mulCarry(2'u64^33, 2'u64^33).carry == 4
    check: mulCarry(2'u64^63, 1).carry == 0
    check: mulCarry(2'u64^63, 3).carry == 1
    check: mulCarry(2'u64^63, 4).carry == 2
