# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  ../src/ethash, unittest, strutils,
        keccak_tiny


suite "Base hashing algorithm":
  test "FNV hashing":

    let
      x = 1235'u32
      y = 9999999'u32
      FNV_PRIME = 0x01000193'u32

    check: ((FNV_PRIME * x) xor y) == fnv(x, y)


  test "Keccak-256 - Note: spec mentions sha3 but it is Keccak":

    let
      input = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      expected = "2b5ddf6f4d21c23de216f44d5e4bdc68e044b71897837ea74c83908be7037cd7".toUpperASCII
      actual = toUpperASCII($input.keccak_256) # using keccak built-in conversion proc
      actual2 = cast[array[256 div 8, byte]](input.keccak_256).toHex.toUpperAscii

    check: expected == actual
    check: expected == actual2

