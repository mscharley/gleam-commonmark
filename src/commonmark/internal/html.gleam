import commonmark/ast
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn inline_to_html(inline: ast.InlineNode) -> String {
  case inline {
    ast.Text(contents) -> contents
    ast.HardLineBreak -> "<br />\n"
    ast.SoftLineBreak -> "\n"
    ast.Autolink(_) -> "Autolink"
    ast.CodeSpan(_) -> "CodeSpan"
    ast.Emphasis(_) -> "Emphasis"
    ast.StrongEmphasis(_) -> "StrongEmphasis"
    ast.HtmlInline(html) -> html
    ast.Image(_, _) -> "Image"
    ast.Link(_, _) -> "Link"
  }
}

pub fn block_to_html(block: ast.BlockNode) -> String {
  case block {
    ast.LinkReference(_, _) -> ""
    ast.CodeBlock(None, _, contents) ->
      "<pre><code>" <> contents <> "</code></pre>\n"
    ast.CodeBlock(Some(info), _, contents) ->
      "<pre><code class=\"language-"
      <> info
      <> "\">"
      <> contents
      <> "</code></pre>\n"
    ast.Heading(level, contents) ->
      "<h"
      <> int.to_string(level)
      <> ">"
      <> { contents |> list.map(inline_to_html) |> string.join("") }
      <> "</h"
      <> int.to_string(level)
      <> ">\n"
    ast.HorizontalBreak -> "<hr />\n"
    ast.Paragraph(contents) ->
      "<p>"
      <> { contents |> list.map(inline_to_html) |> string.join("") }
      <> "</p>\n"
    ast.HtmlBlock(html) -> html <> "\n"
    ast.BlockQuote(_) -> "BlockQuote"
    ast.OrderedList(_) -> "Lists unsupported\n"
    ast.UnorderedList(_) -> "Lists unsupported\n"
  }
}
