import commonmark/ast
import gleam/list
import gleam/string

pub fn inline_to_html(inline: ast.InlineNode) -> String {
  case inline {
    ast.Text(contents) -> contents
    ast.HardLineBreak -> "<br />\n"
    ast.SoftLineBreak -> "\n"
    _ -> ""
  }
}

pub fn block_to_html(block: ast.BlockNode) -> String {
  case block {
    ast.Paragraph(contents) ->
      "<p>"
      <> { contents |> list.map(inline_to_html) |> string.join("") }
      <> "</p>\n"
    _ -> ""
  }
}
