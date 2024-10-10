//// CommonMark renderer for CommonMark.
////
//// This renderer will generate a CommonMark document from an AST. This is useful
//// if you're generating an AST and want to render it out to a file.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark.{parse}
import commonmark/ast
import commonmark/internal/definitions
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

fn do_prefix_lines(content: List(String), prefix: String, acc: String) {
  case content {
    [] | [""] -> acc
    [x, ..xs] -> do_prefix_lines(xs, prefix, acc <> prefix <> x <> "\n")
  }
}

fn prefix_lines(content: String, prefix: String) {
  content
  |> string.split("\n")
  |> do_prefix_lines(prefix, "")
}

fn prefix_lines_initial(content: String, prefix: String, first_prefix: String) {
  case string.split(content, "\n") {
    [first] -> first_prefix <> first
    [first, ..rest] ->
      do_prefix_lines(rest, prefix, first_prefix <> first <> "\n")
    [] -> ""
  }
}

fn link_title(title: Option(String)) -> String {
  title |> option.map(fn(t) { " \"" <> t <> "\"" }) |> option.unwrap("")
}

fn render_inline(inline: ast.InlineNode) -> String {
  case inline {
    ast.UriAutolink(link) | ast.EmailAutolink(link) -> "<" <> link <> ">"
    ast.CodeSpan(contents) -> "`" <> contents <> "`"
    ast.Emphasis(contents, ast.AsteriskEmphasisMarker) ->
      "*" <> render_inline_list(contents) <> "*"
    ast.Emphasis(contents, ast.UnderscoreEmphasisMarker) ->
      "_" <> render_inline_list(contents) <> "_"
    ast.HardLineBreak -> "\\\n"
    ast.HtmlInline(contents) -> contents
    ast.Image(alt, title, href) ->
      "![" <> alt <> "](" <> href <> link_title(title) <> ")"
    ast.Link(alt, title, href) ->
      "[" <> render_inline_list(alt) <> "](" <> href <> link_title(title) <> ")"
    ast.PlainText(contents) ->
      contents
      |> list.fold(over: definitions.ascii_punctuation, with: fn(text, p) {
        string.replace(text, p, "\\" <> p)
      })
    ast.ReferenceImage(alt, ref) -> "![" <> alt <> "][" <> ref <> "]"
    ast.ReferenceLink(alt, ref) ->
      "[" <> render_inline_list(alt) <> "][" <> ref <> "]"
    ast.SoftLineBreak -> "\n"
    ast.StrikeThrough(contents) -> "~~" <> render_inline_list(contents) <> "~~"
    ast.StrongEmphasis(contents, ast.AsteriskEmphasisMarker) ->
      "**" <> render_inline_list(contents) <> "**"
    ast.StrongEmphasis(contents, ast.UnderscoreEmphasisMarker) ->
      "__" <> render_inline_list(contents) <> "__"
  }
}

fn render_inline_list(inlines: List(ast.InlineNode)) -> String {
  inlines |> list.map(render_inline) |> string.join("")
}

fn render_block(block: ast.BlockNode) -> String {
  case block {
    ast.AlertBlock(level, contents) -> {
      let level_str = case level {
        ast.NoteAlert -> "> [!NOTE]\n"
        ast.TipAlert -> "> [!TIP]\n"
        ast.ImportantAlert -> "> [!IMPORTANT]\n"
        ast.WarningAlert -> "> [!WARNING]\n"
        ast.CautionAlert -> "> [!CAUTION]\n"
      }

      level_str <> render_block(ast.BlockQuote(contents))
    }
    ast.BlockQuote([]) -> "> \n"
    ast.BlockQuote(contents) ->
      {
        contents
        |> list.map(render_block)
        |> string.join("")
        |> prefix_lines("> ")
      }
      <> "\n"
    ast.CodeBlock(_, info, contents) ->
      "```"
      <> {
        info
        |> option.map(fn(i) { " " <> i })
        |> option.unwrap("")
      }
      <> "\n"
      <> contents
      <> "```\n"
    ast.Heading(level, content) ->
      string.repeat("#", level) <> " " <> render_inline_list(content)
    ast.HorizontalBreak -> "_____\n"
    ast.HtmlBlock(contents) -> contents
    ast.OrderedList(items, start, marker) -> {
      let marker_str = case marker {
        ast.PeriodListMarker -> int.to_string(start) <> "."
        ast.BracketListMarker -> int.to_string(start) <> ")"
      }

      items
      |> list.map(fn(i) {
        case i {
          ast.TightListItem(contents) ->
            render_block_list(contents)
            |> prefix_lines_initial(
              string.repeat(" ", string.length(marker_str)) <> "  ",
              marker_str <> "  ",
            )
          ast.ListItem(contents) ->
            {
              render_block_list(contents)
              |> prefix_lines_initial(
                string.repeat(" ", string.length(marker_str)) <> "  ",
                marker_str <> "  ",
              )
            }
            <> "\n"
        }
      })
      |> string.join("")
    }
    ast.Paragraph(contents) -> render_inline_list(contents) <> "\n"
    ast.UnorderedList(items, marker) -> {
      let marker_str = case marker {
        ast.AsteriskListMarker -> "*"
        ast.DashListMarker -> "-"
        ast.PlusListMarker -> "+"
      }

      items
      |> list.map(fn(i) {
        case i {
          ast.TightListItem(contents) ->
            render_block_list(contents)
            |> prefix_lines_initial("    ", marker_str <> "   ")
          ast.ListItem(contents) ->
            {
              render_block_list(contents)
              |> prefix_lines_initial("    ", marker_str <> "   ")
            }
            <> "\n"
        }
      })
      |> string.join("")
    }
  }
}

fn render_block_list(blocks: List(ast.BlockNode)) -> String {
  blocks |> list.map(render_block) |> string.join("\n")
}

/// Render a CommonMark AST into a CommonMark document.
pub fn to_commonmark(document: ast.Document) -> String {
  let main_segment = render_block_list(document.blocks)
  let references =
    document.references
    |> dict.to_list
    |> list.map(fn(ref) {
      let #(name, ast.Reference(href, title)) = ref

      "[" <> name <> "]: " <> href <> link_title(title)
    })
    |> string.join("\n")

  case string.length(references) {
    0 -> main_segment
    _ -> main_segment <> "\n" <> references <> "\n"
  }
}

/// Re-renders a CommonMark document to canonicalise it.
///
/// The CommonMark specification is extremely permissive. This renderer is deterministic,
/// however the parser doesn't include enough information to perfectly recreate a document
/// as written so this function will likely introduce some changes to hand-written documents.
/// This allows you to canonicalise a given document into a reproducible format.
pub fn canonicalise(document: String) -> String {
  document |> parse |> to_commonmark
}
