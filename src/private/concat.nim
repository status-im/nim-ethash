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


proc concat_hash*(s: U512, cmix: array[8, uint32]): array[(512 + 8 * 32) div 8, byte] {.noSideEffect, inline, noInit.} =


  # Concatenate header and the big-endian nonce
  let sb = s.toByteArrayBE
  for i, b in sb:
    result[i] = b

  # TODO: Do we need to convert cmix to Big Endian??
  let cmixb = cast[ByteArrayBE[32]](cmix)
  for i, b in cmixb:
    let offset = sb.len + i
    result[offset] = b
