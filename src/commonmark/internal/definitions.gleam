import gleam/regex.{type Regex}

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
    fenced_code_start: Regex,
    hr: Regex,
    indented_code: Regex,
    ol: Regex,
    setext_header: Regex,
    ul: Regex,
  )
}

@external(erlang, "commonmark_ffi", "get_static_regexes")
@external(javascript, "../../commonmark_ffi.mjs", "get_static_regexes")
pub fn get_parser_regexes() -> ParserRegexes
