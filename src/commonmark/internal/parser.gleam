import commonmark/ast
import gleam/list
import gleam/regex
import gleam/result
import gleam/string

pub fn parse_text(text: List(String)) -> List(ast.InlineNode) {
  let len = list.length(text) - 1

  text
  |> list.index_map(fn(l, i) {
    case l |> string.ends_with("  ") {
      _ if i == len -> [ast.Text(l |> string.trim)]
      True -> [ast.Text(l |> string.trim), ast.HardLineBreak]
      _ -> [ast.Text(l |> string.trim), ast.SoftLineBreak]
    }
  })
  |> list.concat
}

pub fn parse_paragraph(lines: List(String)) -> ast.BlockNode {
  lines
  |> parse_text
  |> ast.Paragraph
}

type BlockParseState {
  OutsideBlock
  ParagraphBuilder(lines: List(String))
}

fn parse_block_state(state: BlockParseState) -> ast.BlockNode {
  case state {
    OutsideBlock -> ast.EmptyBlock
    ParagraphBuilder(lines) -> parse_paragraph(list.reverse(lines))
  }
}

fn do_parse_blocks(
  state: BlockParseState,
  acc: List(ast.BlockNode),
  lines: List(String),
) -> List(ast.BlockNode) {
  let assert Ok(hr_regex) =
    regex.from_string(
      "^ {0,3}(?:\\*[* \t]*\\*[* \t]*\\*|\\-[- \t]*\\-[- \t]*\\-|\\_[_ \t]*\\_[_ \t]*\\_)[ \t]*$",
    )
  let l = list.first(lines) |> result.unwrap("")

  case state, lines, l |> regex.check(with: hr_regex) {
    s, [], _ -> [parse_block_state(s), ..acc] |> list.reverse
    _, ["", ..ls], _ ->
      do_parse_blocks(OutsideBlock, [parse_block_state(state), ..acc], ls)
    OutsideBlock, [_, ..ls], True ->
      do_parse_blocks(OutsideBlock, [ast.HorizontalBreak, ..acc], ls)
    OutsideBlock, [line, ..ls], _ ->
      do_parse_blocks(ParagraphBuilder([line]), acc, ls)
    ParagraphBuilder(bs), [line, ..ls], _ ->
      do_parse_blocks(ParagraphBuilder([line, ..bs]), acc, ls)
  }
}

pub fn parse_blocks(lines: List(String)) -> List(ast.BlockNode) {
  do_parse_blocks(OutsideBlock, [], lines)
  |> list.filter(fn(x) {
    case x {
      ast.EmptyBlock -> False
      _ -> True
    }
  })
}
