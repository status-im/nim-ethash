# ethash

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-ethash/workflows/CI/badge.svg)

# Introduction
A pure-Nim implementation of Ethash, the Ethereum proof of work

Implementation is based on the [spec revision 23 (2017-08-03)](https://github.com/ethereum/wiki/wiki/Ethash).

# Mining
An unoptimized mining CPU backend is available through the compile-time flag ``-d:ethash_mining``.
It requires compilation through the C++ backend.

# Optimizations
For maximum speed, compile Ethash with `-d:release -d:march_native -d:openmp`.
This will compile Ethash in Nim release mode, with all supported CPU extensions (especially AVX2) and with OpenMP multiprocessing. On MacOS, OpenMP requires installing GCC-7 and can be done through Homebrew.

# Original implementation
Original Ethereum implementation is available [here](https://github.com/ethereum/ethash).

**Warning ⚠ - License notice**: the original implementation is under GPLv3 or LGPLv3 and must not be used in this project.

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.
