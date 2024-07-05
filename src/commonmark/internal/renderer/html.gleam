import commonmark/ast
import gleam/dict.{type Dict}
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
  |> string.replace(" ", "%20")
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
    ast.Image(alt, title, href) -> {
      let title =
        title
        |> option.map(fn(t) { " title=\"" <> sanitize_plain_text(t) <> "\"" })
        |> option.unwrap("")

      "<img src=\""
      <> sanitize_href_property(href)
      <> "\" alt=\""
      <> alt
      <> "\""
      <> title
      <> " />"
    }
    ast.ReferenceLink(_, _) -> "Link"
    ast.Link(contents, title, href) -> {
      let title =
        title
        |> option.map(fn(t) { " title=\"" <> sanitize_plain_text(t) <> "\"" })
        |> option.unwrap("")

      "<a href=\""
      <> sanitize_href_property(href)
      <> "\""
      <> title
      <> ">"
      <> inline_list_to_html_safe(contents, refs)
      <> "</a>"
    }
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
    ast.Image(alt, title, href) -> {
      let title =
        title
        |> option.map(fn(t) { " title=\"" <> sanitize_plain_text(t) <> "\"" })
        |> option.unwrap("")

      Ok(
        "<img src=\""
        <> sanitize_href_property(href)
        <> "\" alt=\""
        <> alt
        <> "\""
        <> title
        <> " />",
      )
    }
    ast.ReferenceLink(_, _) -> Ok("Link")
    ast.Link(contents, title, href) -> {
      let title =
        title
        |> option.map(fn(t) { " title=\"" <> sanitize_plain_text(t) <> "\"" })
        |> option.unwrap("")

      inline_list_to_html(contents, refs)
      |> result.map(fn(c) {
        "<a href=\""
        <> sanitize_href_property(href)
        <> "\""
        <> title
        <> ">"
        <> c
        <> "</a>"
      })
    }
    _ -> Ok(inline_to_html_safe(inline, refs))
  }
}

fn loose_list_item(content: List(String)) -> String {
  "<li>\n" <> string.join(content, "") <> "</li>\n"
}

fn map_pair(
  x: #(Result(String, ast.RenderError), Result(String, ast.RenderError)),
  f: fn(#(String, String)) -> String,
) -> Result(String, ast.RenderError) {
  use first <- result.try(x.0)
  use last <- result.try(x.1)
  Ok(f(#(first, last)))
}

fn tight_list_item(
  contents: List(ast.BlockNode),
  refs: ast.ReferenceList,
) -> Result(String, ast.RenderError) {
  let count = list.length(contents)

  let r = contents |> list.reverse
  use rest <- result.try(
    r
    |> list.drop(1)
    |> list.reverse
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
    |> result.all,
  )
  use #(first, last) <- map_pair(case
    count,
    list.first(contents),
    list.first(r)
  {
    0, _, _ | _, Error(_), _ | _, _, Error(_) -> #(Ok(""), Ok(""))
    1, Ok(ast.Paragraph(_) as p), _ -> #(block_to_html(p, refs, True), Ok(""))
    1, Ok(block), _ -> #(
      block_to_html(block, refs, True) |> result.map(fn(x) { "\n" <> x }),
      Ok(""),
    )
    _, Ok(ast.Paragraph(_) as p), Ok(last) -> #(
      block_to_html(p, refs, True) |> result.map(fn(x) { x <> "\n" }),
      block_to_html(last, refs, True),
    )
    _, Ok(first), Ok(last) -> #(
      block_to_html(first, refs, True) |> result.map(fn(x) { "\n" <> x }),
      block_to_html(last, refs, True),
    )
  })

  "<li>" <> first <> string.join(rest, "") <> last <> "</li>\n"
}

fn tight_list_item_safe(
  contents: List(ast.BlockNode),
  refs: ast.ReferenceList,
) -> String {
  let count = list.length(contents)
  let r = contents |> list.reverse
  let rest =
    r
    |> list.drop(1)
    |> list.reverse
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
  let #(first, last) = case count, list.first(contents), list.first(r) {
    0, _, _ | _, Error(_), _ | _, _, Error(_) -> #("", "")
    1, Ok(ast.Paragraph(_) as p), _ -> #(block_to_html_safe(p, refs, True), "")
    1, Ok(block), _ -> #("\n" <> block_to_html_safe(block, refs, True), "")
    _, Ok(ast.Paragraph(_) as p), Ok(last) -> #(
      block_to_html_safe(p, refs, True) <> "\n",
      block_to_html_safe(last, refs, True),
    )
    _, Ok(first), Ok(last) -> #(
      "\n" <> block_to_html_safe(first, refs, True),
      block_to_html_safe(last, refs, True),
    )
  }

  "<li>" <> first <> string.join(rest, "") <> last <> "</li>\n"
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
      tight_list_item(contents, refs)
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
      tight_list_item_safe(contents, refs)
    }
  }
}

fn blockquote(contents: List(String)) -> String {
  "<blockquote>\n" <> string.join(contents, "") <> "</blockquote>\n"
}

fn alert(level: String, contents: List(String)) -> String {
  "<blockquote class=\"alert alert-"
  <> level
  <> "\">\n"
  <> string.join(contents, "")
  <> "</blockquote>\n"
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

fn alert_level_string(level: ast.AlertLevel) {
  case level {
    ast.CautionAlert -> "caution"
    ast.ImportantAlert -> "important"
    ast.NoteAlert -> "note"
    ast.TipAlert -> "tip"
    ast.WarningAlert -> "warning"
  }
}

pub fn block_to_html(
  block: ast.BlockNode,
  refs: Dict(String, ast.Reference),
  tight: Bool,
) -> Result(String, ast.RenderError) {
  case block {
    ast.AlertBlock(level, contents) ->
      contents
      |> list.map(block_to_html(_, refs, False))
      |> result.all
      |> result.map(alert(alert_level_string(level), _))
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
    ast.AlertBlock(level, contents) ->
      alert(
        alert_level_string(level),
        contents |> list.map(block_to_html_safe(_, refs, False)),
      )
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
