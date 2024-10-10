// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import gleam/regex.{type Regex}
import worm

pub const replacement_char = 0xfffd

pub const insecure_codepoints = [0]

pub const ascii_punctuation = [
  "\\", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".",
  "/", ":", ";", "<", "=", ">", "?", "@", "[", "]", "^", "_", "`", "{", "|", "}",
  "~",
]

pub type ParserRegexes {
  ParserRegexes(
    atx_header: Regex,
    block_quote: Regex,
    code_span_unwrap: Regex,
    dec_entity: Regex,
    email: Regex,
    fenced_code_start: Regex,
    hex_entity: Regex,
    hr: Regex,
    indented_code: Regex,
    line_splitter: Regex,
    ol: Regex,
    setext_header: Regex,
    ul: Regex,
    uri: Regex,
  )
}

@external(erlang, "commonmark_ffi", "get_target_regexes")
@external(javascript, "../../commonmark_ffi.mjs", "get_target_regexes")
fn get_target_regexes() -> #(String, String)

pub fn get_parser_regexes() -> ParserRegexes {
  use <- worm.persist()

  let #(fenced_code_start_regex_str, hr_regex_str) = get_target_regexes()

  let assert Ok(atx_header) =
    regex.from_string("^ {0,3}(#{1,6})([ \t]+.*?)?(?:(?<=[ \t])#*)?[ \t]*$")
  let assert Ok(block_quote) = regex.from_string("^ {0,3}> ?(.*)$")
  let assert Ok(code_span_unwrap) = regex.from_string("^ (.*) $")
  let assert Ok(dec_entity) = regex.from_string("^#([0-9]{1,7});")
  // Borrowed direct from the spec
  let assert Ok(email) =
    regex.from_string(
      "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    )
  let assert Ok(fenced_code_start) =
    regex.from_string(fenced_code_start_regex_str)
  let assert Ok(hex_entity) = regex.from_string("^#([xX]([0-9a-fA-F]{1,6}));")
  let assert Ok(hr) = regex.from_string(hr_regex_str)
  let assert Ok(indented_code) =
    regex.from_string("^(?: {0,3}\t|    )|^[ \t]*$")
  let assert Ok(line_splitter) = regex.from_string("\r?\n|\r\n?")
  let assert Ok(ol) =
    regex.from_string("^( {0,3})([0-9]{1,9})([.)])(?:( {1,4})(.*))?$")
  let assert Ok(setext_header) = regex.from_string("^ {0,3}([-=])+[ \t]*$")
  let assert Ok(ul) = regex.from_string("^( {0,3})([-*+])(?:( {1,4})(.*))?$")
  let assert Ok(uri) = regex.from_string("^[a-zA-Z][-a-zA-Z+.]{1,31}:[^ \t]+$")

  ParserRegexes(
    atx_header,
    block_quote,
    code_span_unwrap,
    dec_entity,
    email,
    fenced_code_start,
    hex_entity,
    hr,
    indented_code,
    line_splitter,
    ol,
    setext_header,
    ul,
    uri,
  )
}
