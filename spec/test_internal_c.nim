
import strutils

import ./internal
# Copy-paste all the libethash files alongside this file


###############################################
proc toHex*[N: static[int]](ba: array[N, byte]): string {.noSideEffect.}=
  ## Convert a big-endian byte array to its hex representation
  ## Output is in lowercase
  ##

  const hexChars = "0123456789abcdef"

  result = newString(2*N)
  for i in 0 ..< N:
    result[2*i] = hexChars[int ba[i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[i] and 0xF]


proc readHexChar(c: char): byte {.noSideEffect.}=
  ## Converts an hex char to a byte
  case c
  of '0'..'9': result = byte(ord(c) - ord('0'))
  of 'a'..'f': result = byte(ord(c) - ord('a') + 10)
  of 'A'..'F': result = byte(ord(c) - ord('A') + 10)
  else:
    raise newException(ValueError, $c & "is not a hexademical character")

proc hexToByteArrayBE*[N: static[int]](hexStr: string): array[N, byte] {.noSideEffect, noInit.}=
  ## Read an hex string and store it in a Byte Array in Big-Endian order
  var i = 0
  if hexStr[i] == '0' and (hexStr[i+1] == 'x' or hexStr[i+1] == 'X'):
    inc(i, 2) # Ignore 0x and 0X prefix

  assert hexStr.len - i == 2*N

  while i < N:
    result[i] = hexStr[2*i].readHexChar shl 4 or hexStr[2*i+1].readHexChar
    inc(i)
###############################################

# Block 22 (POC-9 testnet, epoch 0)
let blkn = 22'u

var hash = hexToByteArrayBE[32]("372eca2454ead349c3df0ab5d00b0b706b23e49d469387db91811cee0358fc6d")
let nonce = 0x495732e0ed7a801c'u

let full_size = ethash_get_datasize(blkn)

let light_cache = ethash_light_new(blkn)

assert blkn == light_cache.block_number

let r = ethash_light_compute_internal(
  light_cache,
  full_size,
  cast[ethash_h256_t](hash),
  nonce
)

###############################################

let expected_mix_hash = "2f74cdeb198af0b9abe65d22d372e22fb2d474371774a9583c1cc427a07939f5"

let expected_boundary = "00000b184f1fdd88bfd94c86c39e65db0c36144d5e43f745f722196e730cb614"



###############################################

echo r.mix_hash.b == hexToByteArrayBE[32](expected_mix_hash)

echo "Result   mixhash: " & $r.mix_hash.b.toHex
echo "Expected mixhash: " & $expected_mix_hash
echo "Result   value: "   & $r.result.b.toHex
echo "Expected value: "   & $expected_boundary
