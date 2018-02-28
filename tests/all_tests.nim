# Copyright (c) 2018 Status Research & Development GmbH
# Distributed under the Apache v2 License (license terms are at http://www.apache.org/licenses/LICENSE-2.0).

import  ./test_internal_multiprecision_arithmetic,
        ./test_proof_of_work

when defined(ethash_mining):
  import ./test_mining
