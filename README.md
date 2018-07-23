**Nim Ethash**

[![Build Status (Travis)](https://img.shields.io/travis/status-im/nim-ethash/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/status-im/nim-ethash)[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) ![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)

# Introduction
A pure-Nim implementation of Ethash, the Ethereum proof of work

Implementation is based on the [spec revision 23 (2017-08-03)](https://github.com/ethereum/wiki/wiki/Ethash) and is under the Apache License v2.

# Mining
An unoptimized mining CPU backend is available through the compile-time flag ``-d:ethash_mining``.
It requires compilation through the C++ backend.

# Optimizations
For maximum speed, compile Ethash with `-d:release -d:march_native -d:openmp`.
This will compile Ethash in Nim release mode, with all supported CPU extensions (especially AVX2) and with OpenMP multiprocessing. On MacOS, OpenMP requires installing GCC-7 and can be done through Homebrew.

# Original implementation
Original Ethereum implementation is available [here](https://github.com/ethereum/ethash).

**Warning ⚠ - License notice**: the original implementation is under GPLv3 or LGPLv3 and must not be used in this project.
