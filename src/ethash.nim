# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

when defined(openmp):
  {.passC: "-fopenmp".}
  {.passL: "-fopenmp".}

when defined(march_native):
  {.passC: "-march=native".}

import ./proof_of_work
export proof_of_work

when defined(ethash_mining):
  # without mining, we can use the C compilation target
  import ./mining
  export mining
