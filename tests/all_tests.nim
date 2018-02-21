# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  ../src/ethash, unittest, strutils, algorithm,
        keccak_tiny


suite "Base hashing algorithm":
  test "FNV hashing":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L104-L116
    let
      x = 1235'u32
      y = 9999999'u32
      FNV_PRIME = 0x01000193'u32

    check: ((FNV_PRIME * x) xor y) == fnv(x, y)


  test "Keccak-256 - Note: spec mentions sha3 but it is Keccak":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L118-L129
    let
      input = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      expected = "2b5ddf6f4d21c23de216f44d5e4bdc68e044b71897837ea74c83908be7037cd7".toUpperASCII
      actual = toUpperASCII($input.keccak_256) # using keccak built-in conversion proc
      actual2 = cast[array[256 div 8, byte]](input.keccak_256).toHex.toUpperAscii

    check: expected == actual
    check: expected == actual2

  test "Keccak-512 - Note: spec mentions sha3 but it is Keccak":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L131-L141
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
  # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L155-L180
  let
    full_size = get_datasize(0)
    cache_size = get_cachesize(0)

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

suite "Epoch change":
  # https://github.com/paritytech/parity/blob/05f47b635951f942b493747ca3bc71de90a95d5d/ethash/src/compute.rs#L319-L342
  test "Full dataset size at the change of epochs":
    check: get_data_size(EPOCH_LENGTH - 1) == 1073739904'u
    check: get_data_size(EPOCH_LENGTH)     == 1082130304'u
    check: get_data_size(EPOCH_LENGTH + 1) == 1082130304'u
    check: get_data_size(EPOCH_LENGTH * 2046) == 18236833408'u
    check: get_data_size(EPOCH_LENGTH * 2047) == 18245220736'u

  test "Cache size at the change of epochs":
    check: get_cache_size(EPOCH_LENGTH - 1) == 16776896'u
    check: get_cache_size(EPOCH_LENGTH)     == 16907456'u
    check: get_cache_size(EPOCH_LENGTH + 1) == 16907456'u
    check: get_cache_size(EPOCH_LENGTH * 2046) == 284950208'u
    check: get_cache_size(EPOCH_LENGTH * 2047) == 285081536'u
    check: get_cache_size(EPOCH_LENGTH * 2048 - 1) == 285081536'u

  test "Full dataset size at the change of epochs - Look-up tables":
    check: get_data_size_lut(EPOCH_LENGTH - 1) == 1073739904'u
    check: get_data_size_lut(EPOCH_LENGTH)     == 1082130304'u
    check: get_data_size_lut(EPOCH_LENGTH + 1) == 1082130304'u
    check: get_data_size_lut(EPOCH_LENGTH * 2046) == 18236833408'u
    check: get_data_size_lut(EPOCH_LENGTH * 2047) == 18245220736'u

  test "Cache size at the change of epochs - Look-up tables":
    check: get_cache_size_lut(EPOCH_LENGTH - 1) == 16776896'u
    check: get_cache_size_lut(EPOCH_LENGTH)     == 16907456'u
    check: get_cache_size_lut(EPOCH_LENGTH + 1) == 16907456'u
    check: get_cache_size_lut(EPOCH_LENGTH * 2046) == 284950208'u
    check: get_cache_size_lut(EPOCH_LENGTH * 2047) == 285081536'u
    check: get_cache_size_lut(EPOCH_LENGTH * 2048 - 1) == 285081536'u

suite "Seed hash":
  # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/python/test_pyethash.py#L97-L105
  test "Seed hash of block 0":
    var zeroHex = newString(64)
    zeroHex.fill('0')

    check: $get_seedhash(0) == zeroHex

  test "Seed hash of the next 2048 blocks":
    var expected: Hash[256]
    for i in countup(0'u32, 30000 * 2048, 30000):
      check: get_seedhash(i) == expected
      expected = keccak_256(expected.toByteArrayBE)

suite "[Not Implemented] Dagger hashimoto computation":
  test "Light compute":
    # Taken from https://github.com/paritytech/parity/blob/05f47b635951f942b493747ca3bc71de90a95d5d/ethash/src/compute.rs#L372-L394

    let hash = cast[Hash[256]]([
      byte 0xf5, 0x7e, 0x6f, 0x3a, 0xcf, 0xc0, 0xdd, 0x4b, 0x5b, 0xf2, 0xbe, 0xe4, 0x0a, 0xb3,
      0x35, 0x8a, 0xa6, 0x87, 0x73, 0xa8, 0xd0, 0x9f, 0x5e, 0x59, 0x5e, 0xab, 0x55, 0x94,
      0x05, 0x52, 0x7d, 0x72
    ])

    let expected_mix_hash = cast[array[8, uint32]]([
      byte 0x1f, 0xff, 0x04, 0xce, 0xc9, 0x41, 0x73, 0xfd, 0x59, 0x1e, 0x3d, 0x89, 0x60, 0xce,
      0x6b, 0xdf, 0x8b, 0x19, 0x71, 0x04, 0x8c, 0x71, 0xff, 0x93, 0x7b, 0xb2, 0xd3, 0x2a,
      0x64, 0x31, 0xab, 0x6d
    ])

    let expected_boundary = cast[Hash[256]]([
      byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x3e, 0x9b, 0x6c, 0x69, 0xbc, 0x2c, 0xe2, 0xa2,
      0x4a, 0x8e, 0x95, 0x69, 0xef, 0xc7, 0xd7, 0x1b, 0x33, 0x35, 0xdf, 0x36, 0x8c, 0x9a,
      0xe9, 0x7e, 0x53, 0x84
    ])

    let nonce = 0xd7b3ac70a301a249'u64
    ## difficulty = 0x085657254bd9u64