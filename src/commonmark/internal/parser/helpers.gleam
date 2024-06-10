import commonmark/ast
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/string

pub const tab_stop = "(?: {0,3}\t|    )"

pub fn ol_marker(marker: String) -> ast.OrderedListMarker {
  case marker {
    "." -> ast.PeriodListMarker
    ")" -> ast.BracketListMarker
    _ -> panic as { "Invalid ordered list marker: " <> marker }
  }
}

pub fn ul_marker(marker: String) -> ast.UnorderedListMarker {
  case marker {
    "*" -> ast.AsteriskListMarker
    "-" -> ast.DashListMarker
    "+" -> ast.PlusListMarker
    _ -> panic as { "Invalid unordered list marker: " <> marker }
  }
}

pub fn indent_pattern(indent: Int) -> String {
  case indent {
    0 -> ""
    i if i >= 4 -> tab_stop <> indent_pattern(i - 4)
    i -> " {" <> int.to_string(i) <> "}"
  }
}

fn do_trim_indent(line: String, n: Int, removed: Int) -> String {
  case line {
    _ if removed >= n -> line
    " " <> rest -> do_trim_indent(rest, n, removed + 1)
    "\t" <> rest -> {
      let next_tab_stop = removed + { 4 - { removed % 4 } }
      do_trim_indent(rest, n, removed + next_tab_stop)
    }
    _ -> line
  }
}

/// Trims up to a certain amount of whitespace from the start of a string.
///
/// This respects tabs correctly with a tab width of 4 spaces.
pub fn trim_indent(line: String, n: Int) -> String {
  do_trim_indent(line, n, 0)
}

pub fn determine_indent(indent: Option(String)) -> Int {
  case indent {
    None -> 0
    Some(s) -> string.length(s)
  }
}

pub fn parse_autolink(href: String) -> ast.InlineNode {
  // Borrowed direct from the spec
  let assert Ok(email_regex) =
    regex.from_string(
      "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    )
  let assert Ok(uri_regex) = regex.from_string("^[a-zA-Z][-a-zA-Z+.]{1,31}:")

  case regex.check(email_regex, href), regex.check(uri_regex, href) {
    True, _ -> ast.EmailAutolink(href)
    _, True -> ast.UriAutolink(href)
    False, False -> ast.Text("<" <> href <> ">")
  }
}
