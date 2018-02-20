# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import keccak_tiny,
       ./casting

proc concat_hash*(header: Hash[256], nonce: uint64): Hash[512] {.noSideEffect, inline, noInit.} =

  # Can't take compile-time sizeof of arrays in objects: https://github.com/nim-lang/Nim/issues/5802
  var cat{.noInit.}: array[256 div 8 + nonce.sizeof, byte]
  let nonceBE = nonce.toByteArrayBE # Big endian representation of the number

  # Concatenate header and the big-endian nonce
  for i, b in header.data:
    cat[i] = b

  for i, b in nonceBE:
    cat[i + header.sizeof] = b

  result = keccak512 cat


proc concat_hash*(s: U512, cmix: array[4, uint32]): array[(512 + 4 * 32) div 8, byte] {.noSideEffect, inline, noInit.} =


  # TODO: Do we need to convert cmix to Big Endian??

  # Concatenate header and the big-endian nonce
  for i, b in s.toByteArrayBE:
    result[i] = b

  for i, b in cmix:
    let offset = s.sizeof + i
    result[offset ..< offset + 4] = cast[array[4, byte]](b)
