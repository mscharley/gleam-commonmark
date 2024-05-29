import commonmark/ast
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex.{Match}
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

type ParserState {
  OutsideBlock
  ParagraphBuilder(List(String))
}

pub opaque type BlockParseState {
  Paragraph(List(String))
  HorizontalBreak
  Heading(Int, Option(String))
}

pub fn parse_block_state(state: BlockParseState) -> List(ast.BlockNode) {
  case state {
    Paragraph(lines) -> [parse_paragraph(list.reverse(lines))]
    HorizontalBreak -> [ast.HorizontalBreak]
    Heading(level, Some(contents)) -> [
      ast.Heading(level, parse_text([contents])),
    ]
    Heading(level, None) -> [ast.Heading(level, parse_text([]))]
  }
}

fn do_parse_blocks(
  state: ParserState,
  acc: List(BlockParseState),
  lines: List(String),
) -> List(BlockParseState) {
  let assert Ok(hr_regex) =
    regex.from_string(
      "^ {0,3}(?:\\*[* \t]*\\*[* \t]*\\*|\\-[- \t]*\\-[- \t]*\\-|\\_[_ \t]*\\_[_ \t]*\\_)[ \t]*$",
    )
  let assert Ok(atx_header_regex) =
    regex.from_string("^ {0,3}(#{1,6})([ \t]+.*?)?(?:(?<=[ \t])#*)?[ \t]*$")
  let l = list.first(lines) |> result.unwrap("")

  case
    state,
    lines,
    l
    |> regex.check(with: hr_regex),
    l
    |> regex.scan(with: atx_header_regex)
  {
    ParagraphBuilder(lines), [], _, _ ->
      [Paragraph(lines), ..acc] |> list.reverse
    _, [], _, _ -> acc |> list.reverse
    ParagraphBuilder(bs), ["", ..ls], _, _ ->
      do_parse_blocks(OutsideBlock, [Paragraph(bs), ..acc], ls)
    _, ["", ..ls], _, _ -> do_parse_blocks(OutsideBlock, acc, ls)
    OutsideBlock, [_, ..ls], True, _ ->
      do_parse_blocks(OutsideBlock, [HorizontalBreak, ..acc], ls)
    OutsideBlock, [_, ..ls], _, [Match(_, [Some(heading)])] ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(string.length(heading), None), ..acc],
        ls,
      )
    OutsideBlock, [_, ..ls], _, [Match(_, [Some(heading), Some(contents)])] ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(string.length(heading), Some(contents)), ..acc],
        ls,
      )
    ParagraphBuilder(bs),
      [_, ..ls],
      _,
      [Match(_, [Some(heading), Some(contents)])]
    ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(string.length(heading), Some(contents)), Paragraph(bs), ..acc],
        ls,
      )
    OutsideBlock, [line, ..ls], _, _ ->
      do_parse_blocks(ParagraphBuilder([line]), acc, ls)
    ParagraphBuilder(bs), [line, ..ls], _, _ ->
      do_parse_blocks(ParagraphBuilder([line, ..bs]), acc, ls)
  }
}

pub fn parse_blocks(lines: List(String)) -> List(BlockParseState) {
  do_parse_blocks(OutsideBlock, [], lines)
}
