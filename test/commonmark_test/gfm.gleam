// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark_test/helpers
import gleam/option.{None}
import startest.{describe}

const spec_file = "./test/commonmark_test/spec-0.29-gfm.json"

/// A list of tests involving invalid markdown that won't parse in strict mode
const invalid_tests = []

/// This is a list of expected failures
const blacklist = []

/// Run only this test
const only = None

pub fn gfm_spec_tests() {
  describe(
    "GFM spec",
    helpers.parse_json_spec(spec_file)
      |> helpers.run_spec(blacklist, invalid_tests, [], only),
  )
}
