# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import keccak_tiny

proc asByteArray*[T: not (ref|ptr|string)](data: T): array[sizeof(T), byte] =
  ## Cast stack allocated types to an array of byte
  cast[type result](data)

proc asByteArray*(data: Hash[512]): array[64, byte] =
  ## Workaround: Nim cannot evaluate size of arrays
  ## https://github.com/nim-lang/Nim/issues/5802
  cast[type result](data)