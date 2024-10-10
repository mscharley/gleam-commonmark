// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark/html as commonmark
import startest/expect

/// Between example 102 and 103, there is a compatibility note about how setext headers can
/// be ambiguous. That document recommends interpreting things in one particular way which
/// I agree with, but the spec makes no official ruling on the matter. This test fills that
/// gap
pub fn setext_header_ambiguity_test() {
  "foo\nbar\n---\nbaz"
  |> commonmark.render_to_html_strict
  |> expect.to_equal(Ok("<h2>foo\nbar</h2>\n<p>baz</p>\n"))
}
