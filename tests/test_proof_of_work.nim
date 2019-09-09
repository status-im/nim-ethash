# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  ../src/ethash, unittest, strutils, algorithm, random, sequtils, nimcrypto

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
      actual = toUpperASCII($keccak256.digest(input)) # using keccak built-in conversion proc
      actual2 = cast[array[256 div 8, byte]](keccak_256.digest(input)).toHex.toUpperAscii

    check: expected == actual
    check: expected == actual2

  test "Keccak-512 - Note: spec mentions sha3 but it is Keccak":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L131-L141
    let
      input = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      expected = "0be8a1d334b4655fe58c6b38789f984bb13225684e86b20517a55ab2386c7b61c306f25e0627c60064cecd6d80cd67a82b3890bd1289b7ceb473aad56a359405".toUpperASCII
      actual = toUpperASCII($keccak512.digest(input)) # using keccak built-in conversion proc
      actual2 = cast[array[512 div 8, byte]](keccak_512.digest(input)).toHex.toUpperAscii

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

  test "Random testing of full size":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/python/test_pyethash.py#L23-L28

    for _ in 0 ..< 100:
      let block_num = rand(12456789).uint
      let out1 = get_data_size(block_num)
      let out2 = get_data_size((block_num div EPOCH_LENGTH) * EPOCH_LENGTH)
      check: out1 == out2

  test "Random testing of cache size":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/python/test_pyethash.py#L16-L21

    for _ in 0 ..< 100:
      let block_num = rand(12456789).uint
      let out1 = get_cache_size(block_num)
      let out2 = get_cache_size((block_num div EPOCH_LENGTH) * EPOCH_LENGTH)
      check: out1 == out2

suite "Cache initialization":
  # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/python/test_pyethash.py#L31-L36
  test "Mkcache":
    let actual_str = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    var actual_hash: MDigest[256]
    copyMem(addr actual_hash, unsafeAddr actual_str[0], 256 div 8)

    let
      actual = mkcache(1024, actual_hash)
      expected = toUpperASCII "2da2b506f21070e1143d908e867962486d6b0a02e31d468fd5e3a7143aafa76a14201f63374314e2a6aaf84ad2eb57105dea3378378965a1b3873453bb2b78f9a8620b2ebeca41fbc773bb837b5e724d6eb2de570d99858df0d7d97067fb8103b21757873b735097b35d3bea8fd1c359a9e8a63c1540c76c9784cf8d975e995ca8620b2ebeca41fbc773bb837b5e724d6eb2de570d99858df0d7d97067fb8103b21757873b735097b35d3bea8fd1c359a9e8a63c1540c76c9784cf8d975e995ca8620b2ebeca41fbc773bb837b5e724d6eb2de570d99858df0d7d97067fb8103b21757873b735097b35d3bea8fd1c359a9e8a63c1540c76c9784cf8d975e995c259440b89fa3481c2c33171477c305c8e1e421f8d8f6d59585449d0034f3e421808d8da6bbd0b6378f567647cc6c4ba6c434592b198ad444e7284905b7c6adaf70bf43ec2daa7bd5e8951aa609ab472c124cf9eba3d38cff5091dc3f58409edcc386c743c3bd66f92408796ee1e82dd149eaefbf52b00ce33014a6eb3e50625413b072a58bc01da28262f42cbe4f87d4abc2bf287d15618405a1fe4e386fcdafbb171064bd99901d8f81dd6789396ce5e364ac944bbbd75a7827291c70b42d26385910cd53ca535ab29433dd5c5714d26e0dce95514c5ef866329c12e958097e84462197c2b32087849dab33e88b11da61d52f9dbc0b92cc61f742c07dbbf751c49d7678624ee60dfbe62e5e8c47a03d8247643f3d16ad8c8e663953bcda1f59d7e2d4a9bf0768e789432212621967a8f41121ad1df6ae1fa78782530695414c6213942865b2730375019105cae91a4c17a558d4b63059661d9f108362143107babe0b848de412e4da59168cce82bfbff3c99e022dd6ac1e559db991f2e3f7bb910cefd173e65ed00a8d5d416534e2c8416ff23977dbf3eb7180b75c71580d08ce95efeb9b0afe904ea12285a392aff0c8561ff79fca67f694a62b9e52377485c57cc3598d84cac0a9d27960de0cc31ff9bbfe455acaa62c8aa5d2cce96f345da9afe843d258a99c4eaf3650fc62efd81c7b81cd0d534d2d71eeda7a6e315d540b4473c80f8730037dc2ae3e47b986240cfc65ccc565f0d8cde0bc68a57e39a271dda57440b3598bee19f799611d25731a96b5dbbbefdff6f4f656161462633030d62560ea4e9c161cf78fc96a2ca5aaa32453a6c5dea206f766244e8c9d9a8dc61185ce37f1fc804459c5f07434f8ecb34141b8dcae7eae704c950b55556c5f40140c3714b45eddb02637513268778cbf937a33e4e33183685f9deb31ef54e90161e76d969587dd782eaa94e289420e7c2ee908517f5893a26fdb5873d68f92d118d4bcf98d7a4916794d6ab290045e30f9ea00ca547c584b8482b0331ba1539a0f2714fddc3a0b06b0cfbb6a607b8339c39bcfd6640b1f653e9d70ef6c985b"
      actual_hex = actual.foldl(a & $b, "")

    check: actual_hex == expected

suite "Seed hash":
  # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/python/test_pyethash.py#L97-L105
  test "Seed hash of block 0":
    var zeroHex = newString(64)
    zeroHex.fill('0')

    check: $get_seedhash(0) == zeroHex

  test "Seed hash of the next 2048 epochs (2048 * 30000 blocks)":
    var expected: MDigest[256]
    for i in countup(0'u32, 30000 * 2048, 30000):
      check: get_seedhash(i) == expected
      expected = keccak_256.digest(expected.data)

suite "Dagger hashimoto computation":
    # We can't replicate Python's dynamic typing here
    # As Nim expects stack allocated Hash and a string is allocated on the heap

  let
    cache_size = 1024'u
    full_size  = 1024 * 32
    cache_str = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    header_str = "~~~~~X~~~~~~~~~~~~~~~~~~~~~~~~~~"

  var cache_hash: MDigest[256]
  copyMem(addr cache_hash, unsafeAddr cache_str[0], 256 div 8)
  let cache = mkcache(cache_size, cache_hash)

  var header: MDigest[256]
  copyMem(addr header, unsafeAddr header_str[0], 256 div 8)

  let full = calc_dataset(full_size, cache)

  test "calc_data_set_item of item 0":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L350-L374
    let expected = toUpperASCII "b1698f829f90b35455804e5185d78f549fcb1bdce2bee006d4d7e68eb154b596be1427769eb1c3c3e93180c760af75f81d1023da6a0ffbe321c153a7c0103597"

    check: $calc_dataset_item(cache, 0) == expected

  test "Real dataset and recomputation from cache matches":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L360-L374
    for i in 0 ..< full_size div sizeof(MDigest[512]):
      for j in 0 ..< 32:
        let expected = calc_dataset_item(cache, j)
        check: full[j] == expected

  test "Light and full Hashimoto agree":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/python/test_pyethash.py#L44-L58

    let
      light_result = hashimoto_light(full_size, cache, header, 0)
      dataset = calc_dataset(full_size, cache)

    let full_result = hashimoto_full(full_size, dataset, header, 0)

    # Check not null
    var zero_hash : MDigest[256]
    check: light_result.mix_digest != zero_hash
    check: light_result.value      != zero_hash
    check: light_result == full_result

suite "Real blocks test":
  test "Verification of block 22":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L603-L617
    # POC-9 testnet, epoch 0
    let blck = 22'u # block number
    let cache = mkcache(get_cachesize(blck), get_seedhash(blck))
    let header = cast[MDigest[256]](
      hexToByteArrayBE[32]("372eca2454ead349c3df0ab5d00b0b706b23e49d469387db91811cee0358fc6d")
    )

    let light = hashimoto_light(
      get_datasize(blck),
      cache,
      header,
      0x495732e0ed7a801c'u
    )

    check: light.value == cast[MDigest[256]](
      hexToByteArrayBE[32]("00000b184f1fdd88bfd94c86c39e65db0c36144d5e43f745f722196e730cb614")
    )
    check: light.mixDigest == cast[MDigest[256]](
      hexToByteArrayBE[32]("2f74cdeb198af0b9abe65d22d372e22fb2d474371774a9583c1cc427a07939f5")
    )

  test "Verification of block 30001":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/ethash_test.go#L63-L69
    # POC-9 testnet, epoch 1
    let blck = 30001'u # block number
    let cache = mkcache(get_cachesize(blck), get_seedhash(blck))
    let header = cast[MDigest[256]](
      hexToByteArrayBE[32]("7e44356ee3441623bc72a683fd3708fdf75e971bbe294f33e539eedad4b92b34")
    )

    let light = hashimoto_light(
      get_datasize(blck),
      cache,
      header,
      0x318df1c8adef7e5e'u
    )

    check: light.mixDigest == cast[MDigest[256]](
      hexToByteArrayBE[32]("144b180aad09ae3c81fb07be92c8e6351b5646dda80e6844ae1b697e55ddde84")
    )

  test "Verification of block 60000":
    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/ethash_test.go#L70-L78
    # POC-9 testnet, epoch 2
    let blck = 60000'u # block number
    let cache = mkcache(get_cachesize(blck), get_seedhash(blck))
    let header = cast[MDigest[256]](
      hexToByteArrayBE[32]("5fc898f16035bf5ac9c6d9077ae1e3d5fc1ecc3c9fd5bee8bb00e810fdacbaa0")
    )

    let light = hashimoto_light(
      get_datasize(blck),
      cache,
      header,
      0x50377003e5d830ca'u
    )

    check: light.mixDigest == cast[MDigest[256]](
      hexToByteArrayBE[32]("ab546a5b73c452ae86dadd36f0ed83a6745226717d3798832d1b20b489e82063")
    )
