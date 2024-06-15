import commonmark/ast
import gleam/dict.{type Dict}
import gleam/function.{identity}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
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
    // Shared items
    ast.CodeSpan(contents) ->
      "<code>" <> sanitize_plain_text(contents) <> "</code>"
    ast.EmailAutolink(email) ->
      "<a href=\"mailto:"
      <> sanitize_href_property(email)
      <> "\">"
      <> sanitize_plain_text(email)
      <> "</a>"
    ast.HardLineBreak -> "<br />\n"
    ast.HtmlInline(html) -> html
    ast.PlainText(contents) -> sanitize_plain_text(contents)
    ast.SoftLineBreak -> "\n"
    ast.UriAutolink(href) ->
      "<a href=\"" <> sanitize_href_property(href) <> "\">" <> href <> "</a>"

    // Unique items
    ast.Emphasis(contents, _) ->
      "<em>" <> inline_list_to_html_safe(contents, refs) <> "</em>"
    ast.StrongEmphasis(contents, _) ->
      "<strong>" <> inline_list_to_html_safe(contents, refs) <> "</strong>"
    ast.StrikeThrough(contents) ->
      "<del>" <> inline_list_to_html_safe(contents, refs) <> "</del>"
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

fn loose_list_item(content: List(String)) -> String {
  "<li>\n" <> string.join(content, "") <> "</li>\n"
}

fn tight_list_item(
  contents: List(ast.BlockNode),
  refs: ast.ReferenceList,
  f: fn(ast.BlockNode, ast.ReferenceList, Bool) -> a,
  all: fn(List(a)) -> b,
  try: fn(b, fn(List(String)) -> a) -> a,
  map: fn(a, fn(String) -> String) -> a,
  unit: fn(String) -> a,
) -> a {
  let r = contents |> list.reverse
  use rest <- try(
    r
    |> list.drop(1)
    |> list.map(fn(b) {
      case b {
        ast.Paragraph(c) ->
          f(ast.Paragraph(list.concat([c, [ast.SoftLineBreak]])), refs, True)
        _ -> f(b, refs, True)
      }
    })
    |> list.reverse
    |> all,
  )
  use last <- map(case list.first(r) {
    Ok(block) -> f(block, refs, True)
    Error(_) -> unit("")
  })

  "<li>" <> string.join(rest, "") <> last <> "</li>\n"
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
      |> result.map(loose_list_item)
    ast.TightListItem(contents) -> {
      tight_list_item(
        contents,
        refs,
        block_to_html,
        result.all,
        result.try,
        result.map,
        Ok,
      )
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
      loose_list_item(contents |> list.map(block_to_html_safe(_, refs, False)))
    ast.TightListItem(contents) -> {
      let passthrough = fn(x: a, f: fn(a) -> b) -> b { f(x) }
      tight_list_item(
        contents,
        refs,
        block_to_html_safe,
        identity,
        passthrough,
        passthrough,
        identity,
      )
    }
  }
}

fn blockquote(contents: List(String)) -> String {
  "<blockquote>\n" <> string.join(contents, "") <> "</blockquote>\n"
}

fn code(contents: String, language: Option(String)) -> String {
  let class =
    language
    |> option.map(fn(s) { " class=\"language-" <> s <> "\"" })
    |> option.unwrap("")

  "<pre><code" <> class <> ">" <> contents <> "</code></pre>\n"
}

fn header(contents: List(String), level: Int) -> String {
  let tag = "h" <> int.to_string(level)

  "<" <> tag <> ">" <> string.join(contents, "") <> "</" <> tag <> ">\n"
}

fn ol(content: List(String), start: Option(Int)) -> String {
  let start_attr =
    start
    |> option.map(fn(s) { " start=\"" <> int.to_string(s) <> "\"" })
    |> option.unwrap("")

  "<ol" <> start_attr <> ">\n" <> string.join(content, "") <> "</ol>\n"
}

fn p(content: List(String)) -> String {
  "<p>" <> string.join(content, "") <> "</p>\n"
}

fn ul(content: List(String)) -> String {
  "<ul>\n" <> string.join(content, "") <> "</ul>\n"
}

pub fn block_to_html(
  block: ast.BlockNode,
  refs: Dict(String, ast.Reference),
  tight: Bool,
) -> Result(String, ast.RenderError) {
  case block {
    ast.BlockQuote(contents) ->
      contents
      |> list.map(block_to_html(_, refs, False))
      |> result.all
      |> result.map(blockquote)
    ast.CodeBlock(language, _, contents) ->
      Ok(code(contents |> sanitize_plain_text, language))
    ast.Heading(level, contents) ->
      contents
      |> list.map(inline_to_html(_, refs))
      |> result.all
      |> result.map(header(_, level))
    ast.HorizontalBreak -> Ok("<hr />\n")
    ast.HtmlBlock(html) -> Ok(html <> "\n")
    ast.OrderedList(items, 1, _) ->
      items
      |> list.map(list_item_to_html(_, refs))
      |> result.all
      |> result.map(ol(_, None))
    ast.OrderedList(items, start, _) ->
      items
      |> list.map(list_item_to_html(_, refs))
      |> result.all
      |> result.map(ol(_, Some(start)))
    ast.Paragraph(contents) if tight ->
      contents
      |> list.map(inline_to_html(_, refs))
      |> result.all
      |> result.map(string.join(_, ""))
    ast.Paragraph(contents) ->
      contents
      |> list.map(inline_to_html(_, refs))
      |> result.all
      |> result.map(p)
    ast.UnorderedList(items, _) ->
      items
      |> list.map(list_item_to_html(_, refs))
      |> result.all
      |> result.map(ul)
  }
}

pub fn block_to_html_safe(
  block: ast.BlockNode,
  refs: Dict(String, ast.Reference),
  tight: Bool,
) -> String {
  case block {
    ast.BlockQuote(contents) ->
      blockquote(contents |> list.map(block_to_html_safe(_, refs, False)))
    ast.CodeBlock(language, _, contents) ->
      code(contents |> sanitize_plain_text, language)
    ast.Heading(level, contents) ->
      header(contents |> list.map(inline_to_html_safe(_, refs)), level)
    ast.HorizontalBreak -> "<hr />\n"
    ast.HtmlBlock(html) -> html <> "\n"
    ast.OrderedList(items, 1, _) ->
      ol(items |> list.map(list_item_to_html_safe(_, refs)), None)
    ast.OrderedList(items, start, _) ->
      ol(items |> list.map(list_item_to_html_safe(_, refs)), Some(start))
    ast.Paragraph(contents) if tight ->
      contents |> list.map(inline_to_html_safe(_, refs)) |> string.join("")
    ast.Paragraph(contents) ->
      p(contents |> list.map(inline_to_html_safe(_, refs)))
    ast.UnorderedList(items, _) ->
      ul(items |> list.map(list_item_to_html_safe(_, refs)))
  }
}
