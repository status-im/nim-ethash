# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import ../src/ethash, unittest, keccak_tiny, times

suite "Test mining":

  test "Mining block 22":

    # https://github.com/ethereum/ethash/blob/f5f0a8b1962544d2b6f40df8e4b0d9a32faf8f8e/test/c/test.cpp#L603-L617
    # POC-9 testnet, epoch 0
    let
      blck = 22'u # block number
      cache = mkcache(get_cachesize(blck), get_seedhash(blck))
      header = cast[Hash[256]](
        hexToByteArrayBE[32]("372eca2454ead349c3df0ab5d00b0b706b23e49d469387db91811cee0358fc6d")
      )
      difficulty = 132416'u64
      full_size = get_datasize(blck)

    echo "\nGenerating dataset"
    var start = cpuTime()
    let dag = calc_dataset(full_size, cache)
    echo "    Done, time taken: ", $(cpuTime() - start), " seconds"

    echo "\nStarting mining"
    start = cpuTime()
    let mined_nonce = mine(full_size, dag, header, difficulty)
    echo "    Done, time taken: ", $(cpuTime() - start), " seconds"

    check: mined_nonce == 0x495732e0ed7a801c'u64
