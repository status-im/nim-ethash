# Copyright (c) 2018-2024 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import nimcrypto

func as_u32_words*[bits: static[int]](x: MDigest[bits]): array[bits div 32, uint32] {.inline, noinit.}=
  # Convert an hash to its uint32 representation
  cast[type result](x)

func readHexChar(c: char): byte =
  ## Converts an hex char to a byte
  case c
  of '0'..'9': result = byte(ord(c) - ord('0'))
  of 'a'..'f': result = byte(ord(c) - ord('a') + 10)
  of 'A'..'F': result = byte(ord(c) - ord('A') + 10)
  else:
    raise newException(ValueError, $c & "is not a hexademical character")

func hexToByteArrayBE*[N: static[int]](hexStr: string): array[N, byte] {.noinit.}=
  ## Read an hex string and store it in a Byte Array in Big-Endian order
  var i = 0
  if hexStr[i] == '0' and (hexStr[i+1] == 'x' or hexStr[i+1] == 'X'):
    inc(i, 2) # Ignore 0x and 0X prefix

  assert hexStr.len - i == 2*N

  while i < N:
    result[i] = hexStr[2*i].readHexChar shl 4 or hexStr[2*i+1].readHexChar
    inc(i)

func hexToSeqBytesBE*(hexStr: string): seq[byte] =
  ## Read an hex string and store it in a sequence of bytes in Big-Endian order
  var i = 0
  if hexStr[i] == '0' and (hexStr[i+1] == 'x' or hexStr[i+1] == 'X'):
    inc(i, 2) # Ignore 0x and 0X prefix

  let N = (hexStr.len - i) div 2

  result = newSeq[byte](N)
  while i < N:
    result[i] = hexStr[2*i].readHexChar shl 4 or hexStr[2*i+1].readHexChar
    inc(i)

func toHex*[N: static[int]](ba: array[N, byte]): string =
  ## Convert a big-endian byte array to its hex representation
  ## Output is in lowercase

  const hexChars = "0123456789abcdef"

  result = newString(2*N)
  for i in 0 ..< N:
    result[2*i] = hexChars[int ba[i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[i] and 0xF]

func toHex*(ba: seq[byte]): string {.noinit.}=
  ## Convert a big-endian byte sequence to its hex representation
  ## Output is in lowercase

  let N = ba.len
  const hexChars = "0123456789abcdef"

  result = newString(2*N)
  for i in 0 ..< N:
    # you can index an array with byte/uint8 but not a seq :/
    result[2*i] = hexChars[int ba[i] shr 4 and 0xF]
    result[2*i+1] = hexChars[int ba[i] and 0xF]

func toByteArrayBE*[T: SomeInteger](num: T): array[T.sizeof, byte] {.noinit, inline.}=
  ## Convert an int (in native host endianness) to a big-endian byte array
  # Note: only works on devel

  when system.cpuEndian == bigEndian:
    cast[type result](num)
  else:
    # Theoretically this works for both big or little endian
    # but in case of bigEndian, casting is much faster.
    const N = T.sizeof
    for i in 0 ..< N:
      result[i] = byte(num shr T((N-1-i) * 8))

func toByteArrayBE*[bits: static[int]](x: MDigest[bits]): array[bits div 8, byte] {.inline, noinit.}=
  cast[type result](x.data)
