import commonmark/ast
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex.{Match}
import gleam/result
import gleam/string

const tab_stop = "(?: {0,3}\t|    )"

type BlockState {
  OutsideBlock
  ParagraphBuilder(List(String))
  FencedCodeBlockBuilder(
    String,
    Option(String),
    Option(String),
    List(String),
    Int,
  )
  IndentedCodeBlockBuilder(List(String))
}

type InlineState {
  TextAccumulator(List(String))
  AutolinkAccumulator(List(String))
}

pub opaque type BlockParseState {
  Paragraph(String)
  HorizontalBreak
  Heading(Int, Option(String))
  CodeBlock(Option(String), Option(String), String)
}

fn do_trim_indent(line: String, n: Int, removed: Int) -> String {
  case line {
    _ if removed >= n -> line
    " " <> rest -> do_trim_indent(rest, n, removed + 1)
    "\t" <> rest -> {
      let next_tab_stop = removed + { 4 - { removed % 4 } }
      do_trim_indent(rest, n, removed + next_tab_stop)
    }
    _ -> line
  }
}

/// Trims up to a certain amount of whitespace from the start of a string.
///
/// This respects tabs correctly with a tab width of 4 spaces.
pub fn trim_indent(line: String, n: Int) -> String {
  do_trim_indent(line, n, 0)
}

fn determine_indent(indent: Option(String)) -> Int {
  case indent {
    None -> 0
    Some(s) -> string.length(s)
  }
}

fn parse_autolink(href: String) -> ast.InlineNode {
  // Borrowed direct from the spec
  let assert Ok(email_regex) =
    regex.from_string(
      "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    )
  let assert Ok(uri_regex) = regex.from_string("^[a-zA-Z][-a-zA-Z+.]{1,31}:")

  case regex.check(email_regex, href), regex.check(uri_regex, href) {
    True, _ -> ast.EmailAutolink(href)
    _, True -> ast.UriAutolink(href)
    False, False -> ast.Text("<" <> href <> ">")
  }
}

fn do_parse_text(
  text: List(String),
  state: InlineState,
  acc: List(ast.InlineNode),
) -> List(ast.InlineNode) {
  case state, text {
    AutolinkAccumulator(ts), [] -> [
      ast.Text(["<", ..list.reverse(ts)] |> string.join("")),
      ..acc
    ]
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
    AutolinkAccumulator(ts), [" ", " ", "\n", ..gs]
    | AutolinkAccumulator(ts), ["\\", "\n", ..gs]
    ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.HardLineBreak,
        ast.Text(list.reverse(["<", ..ts]) |> string.join("")),
        ..acc
      ])
    TextAccumulator(ts), ["\n", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.SoftLineBreak,
        ast.Text(ts |> list.reverse |> string.join("") |> string.trim),
        ..acc
      ])
    AutolinkAccumulator(ts), ["\n", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        ast.SoftLineBreak,
        ast.Text(list.reverse(["<", ..ts]) |> string.join("")),
        ..acc
      ])
    TextAccumulator(ts), ["<", ..gs] ->
      do_parse_text(gs, AutolinkAccumulator([]), [
        ast.Text(ts |> list.reverse |> string.join("")),
        ..acc
      ])
    AutolinkAccumulator(ts), ["\t" as space, ..gs]
    | AutolinkAccumulator(ts), [" " as space, ..gs]
    ->
      do_parse_text(gs, TextAccumulator([space, ..list.append(ts, ["<"])]), acc)
    AutolinkAccumulator(ts), [">", ..gs] ->
      do_parse_text(gs, TextAccumulator([]), [
        parse_autolink(ts |> list.reverse |> string.join("")),
        ..acc
      ])
    AutolinkAccumulator(ts), [g, ..gs] ->
      do_parse_text(gs, AutolinkAccumulator([g, ..ts]), acc)
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
    FencedCodeBlockBuilder(break, _, _, _, _) ->
      regex.from_string("^ {0,3}" <> break <> "+[ \t]*$")
    _ -> regex.from_string("^( {0,3})([~`]{3,})[ \t]*(([^\\s]+).*?)?[ \t]*$")
  }
  let assert Ok(valid_indented_code_regex) =
    regex.from_string("^" <> tab_stop <> "|^[ \t]*$")
  let l = list.first(lines)

  let atx_header_results =
    l |> result.map(regex.scan(_, with: atx_header_regex))
  let setext_header_results =
    l |> result.map(regex.scan(_, with: setext_header_regex))
  let fenced_code_results =
    l |> result.map(regex.scan(_, with: fenced_code_regex))

  let is_hr =
    l |> result.map(regex.check(_, with: hr_regex)) |> result.unwrap(False)
  let is_indented_code_block =
    l
    |> result.map(regex.check(_, with: valid_indented_code_regex))
    |> result.unwrap(False)
  let is_atx_header =
    atx_header_results
    |> result.map(fn(x) { list.length(x) > 0 })
    |> result.unwrap(False)
  let is_setext_header =
    setext_header_results
    |> result.map(fn(x) { list.length(x) > 0 })
    |> result.unwrap(False)
  let is_fenced_code_block =
    fenced_code_results
    |> result.map(fn(x) { list.length(x) > 0 })
    |> result.unwrap(False)

  case state, lines {
    // Run out of lines...
    ParagraphBuilder(lines), [] ->
      [Paragraph(lines |> string.join("\n")), ..acc] |> list.reverse
    IndentedCodeBlockBuilder(lines), [] ->
      [
        CodeBlock(
          None,
          None,
          [
            "",
            ..lines
            |> list.map(trim_indent(_, 4))
            |> list.drop_while(fn(n) { n == "" })
          ]
            |> list.reverse
            |> list.drop_while(fn(n) { n == "" })
            |> string.join("\n"),
        ),
        ..acc
      ]
      |> list.reverse
    FencedCodeBlockBuilder(_, info, full_info, contents, indent), [""]
    | FencedCodeBlockBuilder(_, info, full_info, contents, indent), []
    ->
      [
        CodeBlock(
          info,
          full_info,
          ["", ..contents]
            |> list.map(trim_indent(_, indent))
            |> list.reverse
            |> string.join("\n"),
        ),
        ..acc
      ]
      |> list.reverse
    OutsideBlock, [] -> acc |> list.reverse
    // Blank line ending a paragraph
    ParagraphBuilder(bs), ["  ", ..ls]
    | ParagraphBuilder(bs), ["\\", ..ls]
    | ParagraphBuilder(bs), ["", ..ls]
    ->
      do_parse_blocks(
        OutsideBlock,
        [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
        ls,
      )
    OutsideBlock, ["  ", ..ls]
    | OutsideBlock, ["\\", ..ls]
    | OutsideBlock, ["", ..ls]
    -> do_parse_blocks(OutsideBlock, acc, ls)
    // Indented code blocks
    OutsideBlock, [l, ..ls] if is_indented_code_block ->
      do_parse_blocks(IndentedCodeBlockBuilder([l]), acc, ls)
    IndentedCodeBlockBuilder(bs), [l] if is_indented_code_block ->
      do_parse_blocks(IndentedCodeBlockBuilder([l, ..bs]), acc, [])
    IndentedCodeBlockBuilder(bs), [l, ..ls] if is_indented_code_block ->
      do_parse_blocks(IndentedCodeBlockBuilder([l, ..bs]), acc, ls)
    IndentedCodeBlockBuilder(bs), ls ->
      do_parse_blocks(
        OutsideBlock,
        [
          CodeBlock(
            None,
            None,
            [
              "",
              ..bs
              |> list.map(trim_indent(_, 4))
              |> list.drop_while(fn(n) { n == "" })
            ]
              |> list.reverse
              |> list.drop_while(fn(n) { n == "" })
              |> string.join("\n"),
          ),
          ..acc
        ],
        ls,
      )
    // Fenced code blocks
    ParagraphBuilder(bs), [_, ..ls] if is_fenced_code_block ->
      case fenced_code_results {
        Ok([Match(_, [indent, Some(exit)])]) ->
          do_parse_blocks(
            FencedCodeBlockBuilder(
              exit,
              None,
              None,
              [],
              determine_indent(indent),
            ),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
          )
        Ok([Match(_, [indent, Some(exit), full_info, info])]) ->
          do_parse_blocks(
            FencedCodeBlockBuilder(
              exit,
              info,
              full_info,
              [],
              determine_indent(indent),
            ),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
          )
        _ ->
          panic as {
            "Invalid fenced code block parser state: "
            <> string.inspect(fenced_code_results)
          }
      }
    OutsideBlock, [_, ..ls] if is_fenced_code_block ->
      case fenced_code_results {
        Ok([Match(_, [indent, Some(exit)])]) ->
          do_parse_blocks(
            FencedCodeBlockBuilder(
              exit,
              None,
              None,
              [],
              determine_indent(indent),
            ),
            acc,
            ls,
          )
        Ok([Match(_, [indent, Some(exit), full_info, info])]) ->
          do_parse_blocks(
            FencedCodeBlockBuilder(
              exit,
              info,
              full_info,
              [],
              determine_indent(indent),
            ),
            acc,
            ls,
          )
        _ ->
          panic as {
            "Invalid fenced code block parser state: "
            <> string.inspect(fenced_code_results)
          }
      }
    FencedCodeBlockBuilder(_, info, full_info, bs, indent), [_, ..ls]
      if is_fenced_code_block
    ->
      case fenced_code_results {
        Ok([Match(_, _)]) ->
          do_parse_blocks(
            OutsideBlock,
            [
              CodeBlock(
                info,
                full_info,
                list.reverse(["", ..bs |> list.map(trim_indent(_, indent))])
                  |> string.join("\n"),
              ),
              ..acc
            ],
            ls,
          )
        _ ->
          panic as {
            "Invalid fenced code block parser state: "
            <> string.inspect(fenced_code_results)
          }
      }
    FencedCodeBlockBuilder(break, info, full_info, bs, indent), [l, ..ls] ->
      do_parse_blocks(
        FencedCodeBlockBuilder(break, info, full_info, [l, ..bs], indent),
        acc,
        ls,
      )
    // Setext headers
    ParagraphBuilder(bs), [_, ..ls] if is_setext_header ->
      case setext_header_results {
        Ok([Match(_, [Some("=")])]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(1, Some(list.reverse(bs) |> string.join("\n"))), ..acc],
            ls,
          )
        Ok([Match(_, [Some("-")])]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(2, Some(list.reverse(bs) |> string.join("\n"))), ..acc],
            ls,
          )
        _ ->
          panic as {
            "Invalid Setext header parser state: "
            <> string.inspect(setext_header_results)
          }
      }
    // Horizontal breaks
    ParagraphBuilder(bs), [_, ..ls] if is_hr ->
      do_parse_blocks(
        OutsideBlock,
        [
          HorizontalBreak,
          Paragraph(list.reverse(bs) |> string.join("\n")),
          ..acc
        ],
        ls,
      )
    OutsideBlock, [_, ..ls] if is_hr ->
      do_parse_blocks(OutsideBlock, [HorizontalBreak, ..acc], ls)
    // ATX headers
    OutsideBlock, [_, ..ls] if is_atx_header ->
      case atx_header_results {
        Ok([Match(_, [Some(heading)])]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(string.length(heading), None), ..acc],
            ls,
          )
        Ok([Match(_, [Some(heading), Some(contents)])]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(string.length(heading), Some(contents)), ..acc],
            ls,
          )
        _ ->
          panic as {
            "Invalid ATX header parser state: "
            <> string.inspect(atx_header_results)
          }
      }
    ParagraphBuilder(bs), [_, ..ls] if is_atx_header ->
      case atx_header_results {
        Ok([Match(_, [Some(heading)])]) ->
          do_parse_blocks(
            OutsideBlock,
            [
              Heading(string.length(heading), None),
              Paragraph(list.reverse(bs) |> string.join("\n")),
              ..acc
            ],
            ls,
          )
        Ok([Match(_, [Some(heading), Some(contents)])]) ->
          do_parse_blocks(
            OutsideBlock,
            [
              Heading(string.length(heading), Some(contents)),
              Paragraph(list.reverse(bs) |> string.join("\n")),
              ..acc
            ],
            ls,
          )
        _ ->
          panic as {
            "Invalid ATX header parser state: "
            <> string.inspect(atx_header_results)
          }
      }
    // Paragraphs
    OutsideBlock, [line, ..ls] ->
      do_parse_blocks(ParagraphBuilder([line]), acc, ls)
    ParagraphBuilder(bs), [line, ..ls] ->
      do_parse_blocks(ParagraphBuilder([line, ..bs]), acc, ls)
  }
}

pub fn parse_blocks(lines: List(String)) -> List(BlockParseState) {
  do_parse_blocks(OutsideBlock, [], lines)
}
