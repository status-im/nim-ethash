# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import ../src/ethash, times, keccak_tiny


let
  seed = hexToSeqBytesBE("9410b944535a83d9adf6bbdcc80e051f30676173c16ca0d32d6f1263fc246466")
  previous_hash = hexToSeqBytesBE("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")


var start = cpuTime() # Note for a multithreaded program, it adds the time taken on each Cpu


# params.full_size = 262147 * 4096;	// 1GBish;
# params.full_size = 32771 * 4096;	// 128MBish;
# params.full_size = 8209 * 4096;	// 8MBish;
# params.cache_size = 8209*4096;
# params.cache_size = 2053*4096;

# Default:
# Dataset 2^30
# Cache   2^24

let cache = mkcache(8209*4096, seed)
echo "mkcache: ", cpuTime() - start, "s"

let cache_hash = sha3_512 cache
echo "sha3: ", $cache_hash