import commonmark/ast
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

pub fn sanitize_href_property(prop: String) -> String {
  prop
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "%22")
  |> string.replace("\\", "%5C")
}

pub fn sanitize_plain_text(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "&quot;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

fn inline_list_to_html_safe(
  nodes: List(ast.InlineNode),
  refs: ast.ReferenceList,
) -> String {
  nodes
  |> list.map(inline_to_html_safe(_, refs))
  |> string.join("")
}

fn inline_list_to_html(
  nodes: List(ast.InlineNode),
  refs: ast.ReferenceList,
) -> Result(String, ast.RenderError) {
  nodes
  |> list.map(inline_to_html(_, refs))
  |> result.all
  |> result.map(string.join(_, ""))
}

fn inline_to_html_safe(
  inline: ast.InlineNode,
  refs: ast.ReferenceList,
) -> String {
  case inline {
    ast.PlainText(contents) -> contents |> sanitize_plain_text
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
      "<em>" <> inline_list_to_html_safe(contents, refs) <> "</em>"
    ast.StrongEmphasis(contents, _) ->
      "<strong>" <> inline_list_to_html_safe(contents, refs) <> "</strong>"
    ast.StrikeThrough(contents) ->
      "<del>" <> inline_list_to_html_safe(contents, refs) <> "</del>"
    ast.HtmlInline(html) -> html
    ast.ReferenceImage(_, _) -> "Image"
    ast.Image(_, _, _) -> "Image"
    ast.ReferenceLink(_, _) -> "Link"
    ast.Link(_, _, _) -> "Link"
  }
}

fn inline_to_html(
  inline: ast.InlineNode,
  refs: ast.ReferenceList,
) -> Result(String, ast.RenderError) {
  case inline {
    ast.Emphasis(contents, _) ->
      inline_list_to_html(contents, refs)
      |> result.map(fn(c) { "<em>" <> c <> "</em>" })
    ast.StrongEmphasis(contents, _) ->
      inline_list_to_html(contents, refs)
      |> result.map(fn(c) { "<strong>" <> c <> "</strong>" })
    ast.StrikeThrough(contents) ->
      inline_list_to_html(contents, refs)
      |> result.map(fn(c) { "<del>" <> c <> "</del>" })
    ast.HtmlInline(html) -> Ok(html)
    ast.ReferenceImage(_, _) -> Ok("Image")
    ast.Image(_, _, _) -> Ok("Image")
    ast.ReferenceLink(_, _) -> Ok("Link")
    ast.Link(_, _, _) -> Ok("Link")
    _ -> Ok(inline_to_html_safe(inline, refs))
  }
}

fn list_item_to_html(
  item: ast.ListItem,
  refs: Dict(String, ast.Reference),
) -> Result(String, ast.RenderError) {
  case item {
    ast.ListItem([]) | ast.TightListItem([]) -> Ok("<li></li>\n")
    ast.ListItem(contents) ->
      contents
      |> list.map(block_to_html(_, refs, False))
      |> result.all
      |> result.map(fn(c) { "<li>\n" <> { string.join(c, "") } <> "</li>\n" })
    ast.TightListItem(contents) -> {
      let r = contents |> list.reverse

      use rest <- result.try(
        r
        |> list.drop(1)
        |> list.map(fn(b) {
          case b {
            ast.Paragraph(c) ->
              block_to_html(
                ast.Paragraph(list.concat([c, [ast.SoftLineBreak]])),
                refs,
                True,
              )
            _ -> block_to_html(b, refs, True)
          }
        })
        |> list.reverse
        |> result.all,
      )
      use last <- result.map(case list.first(r) {
        Ok(block) -> block_to_html(block, refs, True)
        Error(_) -> Ok("")
      })

      "<li>" <> string.join(rest, "") <> last <> "</li>\n"
    }
  }
}

fn list_item_to_html_safe(
  item: ast.ListItem,
  refs: Dict(String, ast.Reference),
) -> String {
  case item {
    ast.ListItem([]) | ast.TightListItem([]) -> "<li></li>\n"
    ast.ListItem(contents) ->
      "<li>\n"
      <> {
        contents
        |> list.map(block_to_html_safe(_, refs, False))
        |> string.join("")
      }
      <> "</li>\n"
    ast.TightListItem(contents) -> {
      let r = contents |> list.reverse
      let rest =
        r
        |> list.drop(1)
        |> list.map(fn(b) {
          case b {
            ast.Paragraph(c) ->
              block_to_html_safe(
                ast.Paragraph(list.concat([c, [ast.SoftLineBreak]])),
                refs,
                True,
              )
            _ -> block_to_html_safe(b, refs, True)
          }
        })
        |> list.reverse
        |> string.join("")
      let last = case list.first(r) {
        Ok(block) -> block_to_html_safe(block, refs, True)
        Error(_) -> ""
      }

      "<li>" <> rest <> last <> "</li>\n"
    }
  }
}

pub fn block_to_html(
  block: ast.BlockNode,
  refs: Dict(String, ast.Reference),
  tight: Bool,
) -> Result(String, ast.RenderError) {
  case block {
    ast.CodeBlock(None, _, contents) ->
      Ok("<pre><code>" <> sanitize_plain_text(contents) <> "</code></pre>\n")
    ast.CodeBlock(Some(info), _, contents) ->
      Ok(
        "<pre><code class=\"language-"
        <> info
        <> "\">"
        <> { contents |> sanitize_plain_text }
        <> "</code></pre>\n",
      )
    ast.Heading(level, contents) ->
      contents
      |> list.map(inline_to_html(_, refs))
      |> result.all
      |> result.map(fn(c) {
        "<h"
        <> int.to_string(level)
        <> ">"
        <> { c |> string.join("") }
        <> "</h"
        <> int.to_string(level)
        <> ">\n"
      })
    ast.HorizontalBreak -> Ok("<hr />\n")
    ast.Paragraph(contents) if tight ->
      contents
      |> list.map(inline_to_html(_, refs))
      |> result.all
      |> result.map(string.join(_, ""))
    ast.Paragraph(contents) ->
      contents
      |> list.map(inline_to_html(_, refs))
      |> result.all
      |> result.map(fn(c) { "<p>" <> string.join(c, "") <> "</p>\n" })
    ast.HtmlBlock(html) -> Ok(html <> "\n")
    ast.BlockQuote(contents) ->
      contents
      |> list.map(block_to_html(_, refs, False))
      |> result.all
      |> result.map(fn(c) {
        "<blockquote>\n" <> string.join(c, "") <> "</blockquote>\n"
      })
    ast.OrderedList(items, 1, _) ->
      items
      |> list.map(list_item_to_html(_, refs))
      |> result.all
      |> result.map(fn(c) { "<ol>\n" <> string.join(c, "") <> "</ol>\n" })
    ast.OrderedList(items, start, _) ->
      items
      |> list.map(list_item_to_html(_, refs))
      |> result.all
      |> result.map(fn(c) {
        "<ol start=\""
        <> int.to_string(start)
        <> "\">\n"
        <> string.join(c, "")
        <> "</ol>\n"
      })
    ast.UnorderedList(items, _) ->
      items
      |> list.map(list_item_to_html(_, refs))
      |> result.all
      |> result.map(fn(c) { "<ul>\n" <> string.join(c, "") <> "</ul>\n" })
  }
}

pub fn block_to_html_safe(
  block: ast.BlockNode,
  refs: Dict(String, ast.Reference),
  tight: Bool,
) -> String {
  case block {
    ast.CodeBlock(None, _, contents) ->
      "<pre><code>" <> sanitize_plain_text(contents) <> "</code></pre>\n"
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
      <> {
        contents |> list.map(inline_to_html_safe(_, refs)) |> string.join("")
      }
      <> "</h"
      <> int.to_string(level)
      <> ">\n"
    ast.HorizontalBreak -> "<hr />\n"
    ast.Paragraph(contents) if tight ->
      contents |> list.map(inline_to_html_safe(_, refs)) |> string.join("")
    ast.Paragraph(contents) ->
      "<p>"
      <> {
        contents |> list.map(inline_to_html_safe(_, refs)) |> string.join("")
      }
      <> "</p>\n"
    ast.HtmlBlock(html) -> html <> "\n"
    ast.BlockQuote(contents) ->
      "<blockquote>\n"
      <> {
        contents
        |> list.map(block_to_html_safe(_, refs, False))
        |> string.join("")
      }
      <> "</blockquote>\n"
    ast.OrderedList(items, 1, _) ->
      "<ol>\n"
      <> {
        items
        |> list.map(list_item_to_html_safe(_, refs))
        |> string.join("")
      }
      <> "</ol>\n"
    ast.OrderedList(items, start, _) ->
      "<ol start=\""
      <> int.to_string(start)
      <> "\">\n"
      <> {
        items
        |> list.map(list_item_to_html_safe(_, refs))
        |> string.join("")
      }
      <> "</ol>\n"
    ast.UnorderedList(items, _) ->
      "<ul>\n"
      <> {
        items
        |> list.map(list_item_to_html_safe(_, refs))
        |> string.join("")
      }
      <> "</ul>\n"
  }
}
