packageName   = "eth_keys"
version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "A reimplementation in pure Nim of ethash, the ethereum proof-of-work algorithm"
license       = "Apachev2"
srcDir        = "src"

### Dependencies

requires "nim >= 0.17.2", "number_theory", "keccak_tiny >= 0.1.0"

proc test(name: string, lang: string = "cpp") =
  if not dirExists "build":
    mkDir "build"
  if not dirExists "nimcache":
    mkDir "nimcache"
  --run
  --nimcache: "nimcache"
  switch("out", ("./build/" & name))
  setCommand lang, "tests/" & name & ".nim"

task test, "Run all tests":
  test "all_tests"