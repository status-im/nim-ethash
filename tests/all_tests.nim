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

  test "Keccak-512 - Note: spec mentions sha3 but it is Keccak":

    let
      input = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      expected = "0be8a1d334b4655fe58c6b38789f984bb13225684e86b20517a55ab2386c7b61c306f25e0627c60064cecd6d80cd67a82b3890bd1289b7ceb473aad56a359405".toUpperASCII
      actual = toUpperASCII($input.keccak_512) # using keccak built-in conversion proc
      actual2 = cast[array[512 div 8, byte]](input.keccak_512).toHex.toUpperAscii

    check: expected == actual
    check: expected == actual2


suite "Endianness (not implemented)":
  discard

suite "Genesis parameters":
  let
    full_size = get_datasize(0).int
    cache_size = get_cachesize(0).int

  test "Full dataset size should be less or equal DATASET_BYTES_INIT":
    check: full_size <= DATASET_BYTES_INIT

  test "Full dataset size + 20*MIBYTES should be greater than DATASET_BYTES_INIT":
    check: full_size + 20 * MIX_BYTES >= DATASET_BYTES_INIT

  test "Cache size should be less or equal to DATASET_BYTES_INIT / 32":
    check: cache_size <= DATASET_BYTES_INIT div 32

  test "Full dataset size == 1073739904":
    check: full_size == 1073739904

  test "Cache size == 16776896":
    check: cache_size == 16776896
