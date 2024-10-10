// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark/ast
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

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
    i if i >= 4 -> "(?: {0,3}\t|    )" <> indent_pattern(i - 4)
    i -> "(?: {" <> int.to_string(i) <> "}|\t)"
  }
}

fn do_trim_indent(line: String, n: Int, removed: Int) -> String {
  let remaining = n - removed
  let next_tab_stop = 4 - { removed % 4 }
  case line {
    _ if remaining <= 0 -> line
    "\t" <> rest if remaining < next_tab_stop ->
      string.repeat(" ", next_tab_stop - remaining) <> rest
    " " <> rest -> do_trim_indent(rest, n, removed + 1)
    "\t" <> rest -> do_trim_indent(rest, n, removed + next_tab_stop)
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
