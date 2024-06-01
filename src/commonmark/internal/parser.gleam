import commonmark/ast
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex.{Match}
import gleam/result
import gleam/string

type BlockState {
  OutsideBlock
  ParagraphBuilder(List(String))
  CodeBlockBuilder(String, Option(String), Option(String), List(String))
}

type InlineState {
  TextAccumulator(List(String))
}

pub opaque type BlockParseState {
  Paragraph(String)
  HorizontalBreak
  Heading(Int, Option(String))
  CodeBlock(Option(String), Option(String), String)
}

fn do_parse_text(
  text: List(String),
  state: InlineState,
  acc: List(ast.InlineNode),
) -> List(ast.InlineNode) {
  case state, text {
    TextAccumulator(ts), [] ->
      [ast.Text(ts |> list.reverse |> string.join("") |> string.trim), ..acc]
      |> list.reverse
    TextAccumulator(ts), [" ", " ", "\n", ..gs]
    | TextAccumulator(ts), ["\\", "\n", ..gs]
    ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.HardLineBreak,
        ast.Text(ts |> list.reverse |> string.join("") |> string.trim),
        ..acc
      ])
    TextAccumulator(ts), ["\n", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.SoftLineBreak,
        ast.Text(ts |> list.reverse |> string.join("") |> string.trim),
        ..acc
      ])
    TextAccumulator(ts), [g, ..gs] ->
      do_parse_text(gs, TextAccumulator([g, ..ts]), acc)
  }
}

pub fn parse_text(text: String) -> List(ast.InlineNode) {
  text |> string.to_graphemes |> do_parse_text(TextAccumulator([]), [])
}

pub fn parse_block_state(state: BlockParseState) -> List(ast.BlockNode) {
  case state {
    Paragraph(lines) -> [lines |> parse_text |> ast.Paragraph]
    CodeBlock(info, full_info, lines) -> [ast.CodeBlock(info, full_info, lines)]
    HorizontalBreak -> [ast.HorizontalBreak]
    Heading(level, Some(contents)) -> [ast.Heading(level, parse_text(contents))]
    Heading(level, None) -> [ast.Heading(level, [])]
  }
}

fn do_parse_blocks(
  state: BlockState,
  acc: List(BlockParseState),
  lines: List(String),
) -> List(BlockParseState) {
  let assert Ok(hr_regex) =
    regex.from_string(
      "^ {0,3}(?:\\*[* \t]*\\*[* \t]*\\*|-[- \t]*-[- \t]*-|_[_ \t]*_[_ \t]*_)[ \t]*$",
    )
  let assert Ok(atx_header_regex) =
    regex.from_string("^ {0,3}(#{1,6})([ \t]+.*?)?(?:(?<=[ \t])#*)?[ \t]*$")
  let assert Ok(setext_header_regex) =
    regex.from_string("^ {0,3}([-=])+[ \t]*$")
  let assert Ok(fenced_code_regex) = case state {
    CodeBlockBuilder(break, _, _, _) ->
      regex.from_string("^ {0,3}" <> break <> "+[ \t]*$")
    _ -> regex.from_string("^ {0,3}([~`]{3,})[ \t]*(([^\\s]+).*?)?[ \t]*$")
  }
  let l = list.first(lines) |> result.unwrap("")

  case
    state,
    lines,
    regex.check(l, with: hr_regex),
    regex.scan(l, with: atx_header_regex),
    regex.scan(l, with: setext_header_regex),
    regex.scan(l, with: fenced_code_regex)
  {
    // Run out of lines...
    ParagraphBuilder(lines), [], _, _, _, _ ->
      [Paragraph(lines |> string.join("\n")), ..acc] |> list.reverse
    CodeBlockBuilder(_, info, full_info, contents), [""], _, _, _, _
    | CodeBlockBuilder(_, info, full_info, contents), [], _, _, _, _
    ->
      [
        CodeBlock(
          info,
          full_info,
          ["", ..contents] |> list.reverse |> string.join("\n"),
        ),
        ..acc
      ]
      |> list.reverse
    OutsideBlock, [], _, _, _, _ -> acc |> list.reverse
    // Blank line ending a paragraph
    ParagraphBuilder(bs), ["  ", ..ls], _, _, _, _
    | ParagraphBuilder(bs), ["\\", ..ls], _, _, _, _
    | ParagraphBuilder(bs), ["", ..ls], _, _, _, _
    ->
      do_parse_blocks(
        OutsideBlock,
        [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
        ls,
      )
    OutsideBlock, ["  ", ..ls], _, _, _, _
    | OutsideBlock, ["\\", ..ls], _, _, _, _
    | OutsideBlock, ["", ..ls], _, _, _, _
    -> do_parse_blocks(OutsideBlock, acc, ls)
    // Fenced code blocks
    ParagraphBuilder(bs), [_, ..ls], _, _, _, [Match(_, [Some(exit)])] ->
      do_parse_blocks(
        CodeBlockBuilder(exit, None, None, []),
        [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
        ls,
      )
    ParagraphBuilder(bs),
      [_, ..ls],
      _,
      _,
      _,
      [Match(_, [Some(exit), full_info, info])]
    ->
      do_parse_blocks(
        CodeBlockBuilder(exit, info, full_info, []),
        [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
        ls,
      )
    OutsideBlock, [_, ..ls], _, _, _, [Match(_, [Some(exit)])] ->
      do_parse_blocks(CodeBlockBuilder(exit, None, None, []), acc, ls)
    OutsideBlock, [_, ..ls], _, _, _, [Match(_, [Some(exit), full_info, info])] ->
      do_parse_blocks(CodeBlockBuilder(exit, info, full_info, []), acc, ls)
    CodeBlockBuilder(_, info, full_info, bs), [_, ..ls], _, _, _, [Match(_, _)] ->
      do_parse_blocks(
        OutsideBlock,
        [
          CodeBlock(
            info,
            full_info,
            list.reverse(["", ..bs]) |> string.join("\n"),
          ),
          ..acc
        ],
        ls,
      )
    CodeBlockBuilder(break, info, full_info, bs), [l, ..ls], _, _, _, _ ->
      do_parse_blocks(
        CodeBlockBuilder(break, info, full_info, [l, ..bs]),
        acc,
        ls,
      )
    // Setext headers
    ParagraphBuilder(bs), [_, ..ls], _, _, [Match(_, [Some("=")])], _ ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(1, Some(list.reverse(bs) |> string.join("\n"))), ..acc],
        ls,
      )
    ParagraphBuilder(bs), [_, ..ls], _, _, [Match(_, [Some("-")])], _ ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(2, Some(list.reverse(bs) |> string.join("\n"))), ..acc],
        ls,
      )
    // Horizontal breaks
    ParagraphBuilder(bs), [_, ..ls], True, _, _, _ ->
      do_parse_blocks(
        OutsideBlock,
        [
          HorizontalBreak,
          Paragraph(list.reverse(bs) |> string.join("\n")),
          ..acc
        ],
        ls,
      )
    OutsideBlock, [_, ..ls], True, _, _, _ ->
      do_parse_blocks(OutsideBlock, [HorizontalBreak, ..acc], ls)
    // ATX headers
    OutsideBlock, [_, ..ls], _, [Match(_, [Some(heading)])], _, _ ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(string.length(heading), None), ..acc],
        ls,
      )
    OutsideBlock,
      [_, ..ls],
      _,
      [Match(_, [Some(heading), Some(contents)])],
      _,
      _
    ->
      do_parse_blocks(
        OutsideBlock,
        [Heading(string.length(heading), Some(contents)), ..acc],
        ls,
      )
    ParagraphBuilder(bs), [_, ..ls], _, [Match(_, [Some(heading)])], _, _ ->
      do_parse_blocks(
        OutsideBlock,
        [
          Heading(string.length(heading), None),
          Paragraph(list.reverse(bs) |> string.join("\n")),
          ..acc
        ],
        ls,
      )
    ParagraphBuilder(bs),
      [_, ..ls],
      _,
      [Match(_, [Some(heading), Some(contents)])],
      _,
      _
    ->
      do_parse_blocks(
        OutsideBlock,
        [
          Heading(string.length(heading), Some(contents)),
          Paragraph(list.reverse(bs) |> string.join("\n")),
          ..acc
        ],
        ls,
      )
    // Paragraphs
    OutsideBlock, [line, ..ls], _, _, _, _ ->
      do_parse_blocks(ParagraphBuilder([line]), acc, ls)
    ParagraphBuilder(bs), [line, ..ls], _, _, _, _ ->
      do_parse_blocks(ParagraphBuilder([line, ..bs]), acc, ls)
  }
}

pub fn parse_blocks(lines: List(String)) -> List(BlockParseState) {
  do_parse_blocks(OutsideBlock, [], lines)
}
