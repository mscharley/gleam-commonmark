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
