import commonmark/ast
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn sanitize_href_property(prop: String) -> String {
  // TODO: This needs to be implemented
  prop
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "%22")
}

pub fn sanitize_plain_text(text: String) -> String {
  // TODO: This needs to be implemented
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

pub fn inline_to_html(
  inline: ast.InlineNode,
  refs: Dict(String, ast.Reference),
) -> String {
  case inline {
    ast.Text(contents) -> contents |> sanitize_plain_text
    ast.HardLineBreak -> "<br />\n"
    ast.SoftLineBreak -> "\n"
    ast.UriAutolink(href) ->
      "<a href=\"" <> sanitize_href_property(href) <> "\">" <> href <> "</a>"
    ast.EmailAutolink(email) ->
      "<a href=\"mailto:"
      <> sanitize_href_property(email)
      <> "\">"
      <> email
      <> "</a>"
    ast.CodeSpan(contents) ->
      "<code>" <> { contents |> sanitize_plain_text } <> "</code>"
    ast.Emphasis(contents, _) ->
      "<em>"
      <> { contents |> list.map(inline_to_html(_, refs)) |> string.join("") }
      <> "</em>"
    ast.StrongEmphasis(contents, _) ->
      "<strong>"
      <> { contents |> list.map(inline_to_html(_, refs)) |> string.join("") }
      <> "</strong>"
    ast.StrikeThrough(contents) ->
      "<s>"
      <> { contents |> list.map(inline_to_html(_, refs)) |> string.join("") }
      <> "</s>"
    ast.HtmlInline(html) -> html
    ast.Image(_, _) -> "Image"
    ast.ReferenceLink(_, _) -> "Link"
    ast.Link(_, _, _) -> "Link"
    ast.NamedEntity("amp", _) -> "&amp;"
    ast.NamedEntity(_, cp) -> string.from_utf_codepoints(cp)
    ast.NumericCharacterReference(cp, _) -> string.from_utf_codepoints([cp])
  }
}

fn list_item_to_html(
  item: ast.ListItem,
  refs: Dict(String, ast.Reference),
) -> String {
  case item {
    ast.ListItem(contents) ->
      "<li>\n"
      <> {
        contents |> list.map(block_to_html(_, refs, False)) |> string.join("")
      }
      <> "</li>\n"
    ast.TightListItem(contents) ->
      "<li>"
      <> {
        contents |> list.map(block_to_html(_, refs, True)) |> string.join("")
      }
      <> "</li>\n"
  }
}

pub fn block_to_html(
  block: ast.BlockNode,
  refs: Dict(String, ast.Reference),
  tight: Bool,
) -> String {
  case block {
    ast.CodeBlock(None, _, contents) ->
      "<pre><code>" <> { contents |> sanitize_plain_text } <> "</code></pre>\n"
    ast.CodeBlock(Some(info), _, contents) ->
      "<pre><code class=\"language-"
      <> info
      <> "\">"
      <> { contents |> sanitize_plain_text }
      <> "</code></pre>\n"
    ast.Heading(level, contents) ->
      "<h"
      <> int.to_string(level)
      <> ">"
      <> { contents |> list.map(inline_to_html(_, refs)) |> string.join("") }
      <> "</h"
      <> int.to_string(level)
      <> ">\n"
    ast.HorizontalBreak -> "<hr />\n"
    ast.Paragraph(contents) if tight ->
      contents |> list.map(inline_to_html(_, refs)) |> string.join("")
    ast.Paragraph(contents) ->
      "<p>"
      <> { contents |> list.map(inline_to_html(_, refs)) |> string.join("") }
      <> "</p>\n"
    ast.HtmlBlock(html) -> html <> "\n"
    ast.BlockQuote(contents) ->
      "<blockquote>\n"
      <> {
        contents |> list.map(block_to_html(_, refs, False)) |> string.join("")
      }
      <> "</blockquote>\n"
    ast.OrderedList(items, 1, _) ->
      "<ol>\n"
      <> {
        items
        |> list.map(list_item_to_html(_, refs))
        |> string.join("")
      }
      <> "</ol>\n"
    ast.OrderedList(items, start, _) ->
      "<ol start=\""
      <> int.to_string(start)
      <> "\">\n"
      <> {
        items
        |> list.map(list_item_to_html(_, refs))
        |> string.join("")
      }
      <> "</ol>\n"
    ast.UnorderedList(items, _) ->
      "<ul>\n"
      <> {
        items
        |> list.map(list_item_to_html(_, refs))
        |> string.join("")
      }
      <> "</ul>\n"
  }
}
