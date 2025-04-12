// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark/ast
import commonmark/internal/definitions.{type ParserRegexes, ParserRegexes}
import commonmark/internal/parser/helpers.{
  determine_indent, indent_pattern, ol_marker, trim_indent, ul_marker,
}
import commonmark/internal/parser/inline.{parse_text}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/regexp.{Match}
import gleam/result
import gleam/string

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
  AlertBuilder(ast.AlertLevel, List(String))
  BlockQuoteBuilder(List(String))
  UnorderedListBuilder(
    List(String),
    List(List(BlockParseState)),
    Bool,
    String,
    Int,
  )
  OrderedListBuilder(
    List(String),
    List(List(BlockParseState)),
    Bool,
    String,
    Int,
    Int,
  )
}

type BlockParseState {
  Paragraph(String)
  HorizontalBreak
  Heading(Int, Option(String))
  CodeBlock(Option(String), Option(String), String)
  BlockQuote(List(BlockParseState))
  Alert(ast.AlertLevel, List(BlockParseState))
  UnorderedList(List(List(BlockParseState)), Bool, ast.UnorderedListMarker)
  OrderedList(List(List(BlockParseState)), Int, Bool, ast.OrderedListMarker)
}

fn merge_references(refs: List(ast.ReferenceList)) -> ast.ReferenceList {
  refs |> list.reduce(dict.merge) |> result.unwrap(dict.new())
}

fn parse_block_state(
  state: BlockParseState,
) -> #(ast.BlockNode, ast.ReferenceList) {
  case state {
    Paragraph(lines) -> #(lines |> parse_text |> ast.Paragraph, dict.new())
    CodeBlock(info, full_info, lines) -> #(
      ast.CodeBlock(info, full_info, lines),
      dict.new(),
    )
    HorizontalBreak -> #(ast.HorizontalBreak, dict.new())
    Heading(level, Some(contents)) -> #(
      ast.Heading(level, parse_text(contents)),
      dict.new(),
    )
    Heading(level, None) -> #(ast.Heading(level, []), dict.new())
    Alert(level, blocks) -> {
      blocks
      |> list.map(parse_block_state)
      |> list.unzip
      |> pair.map_first(fn(bs) { ast.AlertBlock(level, bs) })
      |> pair.map_second(merge_references)
    }
    BlockQuote(blocks) -> {
      blocks
      |> list.map(parse_block_state)
      |> list.unzip
      |> pair.map_first(ast.BlockQuote)
      |> pair.map_second(merge_references)
    }
    UnorderedList(items, tight, marker) -> {
      let xs =
        items
        |> list.map(list.map(_, parse_block_state(_)))
        |> list.map(list.unzip)

      #(
        ast.UnorderedList(
          list.map(xs, fn(l) {
            case tight {
              True -> ast.TightListItem(l.0)
              False -> ast.ListItem(l.0)
            }
          }),
          marker,
        ),
        xs |> list.flat_map(pair.second) |> merge_references,
      )
    }
    OrderedList(items, start, tight, marker) -> {
      let xs =
        items
        |> list.map(list.map(_, parse_block_state(_)))
        |> list.map(list.unzip)

      #(
        ast.OrderedList(
          list.map(xs, fn(l) {
            case tight {
              True -> ast.TightListItem(l.0)
              False -> ast.ListItem(l.0)
            }
          }),
          start,
          marker,
        ),
        xs |> list.flat_map(pair.second) |> merge_references,
      )
    }
  }
}

/// Apply a regex that should match the full line and hence should only ever have a single match.
///
/// Returns the list of submatches only.
fn apply_regex(
  line: String,
  with regex: regexp.Regexp,
) -> Result(List(Option(String)), Nil) {
  case regexp.scan(line, with: regex) {
    [Match(_, submatches)] -> Ok(submatches)
    _ -> Error(Nil)
  }
}

fn is_empty_line(l: String) -> Bool {
  { l |> trim_indent(4) } == ""
}

fn do_parse_blocks(
  state: BlockState,
  acc: List(BlockParseState),
  lines: List(String),
  pr: ParserRegexes,
) -> List(BlockParseState) {
  let ParserRegexes(
    atx_header: atx_header_regex,
    hr: hr_regex,
    setext_header: setext_header_regex,
    fenced_code_start: fenced_code_start_regex,
    indented_code: valid_indented_code_regex,
    block_quote: block_quote_regex,
    ul: ul_regex,
    ol: ol_regex,
    ..,
  ) = pr
  let assert Ok(fenced_code_regex) = case state {
    FencedCodeBlockBuilder(break, _, _, _, _) ->
      regexp.from_string("^ {0,3}" <> break <> "+[ \t]*$")
    _ -> Ok(fenced_code_start_regex)
  }
  let l = list.first(lines)

  let atx_header_results =
    l |> result.try(apply_regex(_, with: atx_header_regex))
  let is_atx_header = result.is_ok(atx_header_results)

  let block_quote_results =
    l |> result.try(apply_regex(_, with: block_quote_regex))
  let is_block_quote = result.is_ok(block_quote_results)

  let fenced_code_results =
    l |> result.try(apply_regex(_, with: fenced_code_regex))
  let is_fenced_code_block = result.is_ok(fenced_code_results)

  let ol_results = l |> result.try(apply_regex(_, with: ol_regex))
  let is_ol = result.is_ok(ol_results)

  let setext_header_results =
    l |> result.try(apply_regex(_, with: setext_header_regex))
  let is_setext_header = result.is_ok(setext_header_results)

  let ul_results = l |> result.try(apply_regex(_, with: ul_regex))
  let is_ul = result.is_ok(ul_results)

  let is_hr =
    l |> result.map(regexp.check(_, with: hr_regex)) |> result.unwrap(False)
  let is_indented_code_block =
    l
    |> result.map(regexp.check(_, with: valid_indented_code_regex))
    |> result.unwrap(False)
  let is_list_continuation = case state {
    UnorderedListBuilder(_, _, _, _, indent)
    | OrderedListBuilder(_, _, _, _, _, indent) -> {
      let assert Ok(indent_pattern) =
        regexp.from_string("^" <> indent_pattern(indent) <> "|^[ \t]*$")

      l |> result.try(apply_regex(_, with: indent_pattern)) |> result.is_ok
    }
    _ -> False
  }

  let is_paragraph =
    !is_hr
    && !is_atx_header
    && !is_setext_header
    && !is_fenced_code_block
    && !is_block_quote
    && !is_ul
    && !is_ol
  let is_blank_line = l |> result.map(is_empty_line) |> result.unwrap(False)

  case state, lines {
    // Run out of lines...
    ParagraphBuilder(lines), [] ->
      [Paragraph(lines |> list.reverse |> string.join("\n")), ..acc]
      |> list.reverse
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
    AlertBuilder(level, bs), [] ->
      [Alert(level, bs |> list.reverse |> parse_blocks(pr)), ..acc]
      |> list.reverse
    BlockQuoteBuilder(bs), [] ->
      [BlockQuote(bs |> list.reverse |> parse_blocks(pr)), ..acc]
      |> list.reverse
    UnorderedListBuilder(item, items, tight, marker, _), [] ->
      [
        UnorderedList(
          [item |> list.reverse |> parse_blocks(pr), ..items] |> list.reverse,
          tight && !list.any(list.drop(item, 1), is_empty_line),
          ul_marker(marker),
        ),
        ..acc
      ]
      |> list.reverse
    OrderedListBuilder(item, items, tight, marker, start, _), [] ->
      [
        OrderedList(
          [item |> list.reverse |> parse_blocks(pr), ..items] |> list.reverse,
          start,
          tight && !list.any(list.drop(item, 1), is_empty_line),
          ol_marker(marker),
        ),
        ..acc
      ]
      |> list.reverse
    OutsideBlock, [] -> acc |> list.reverse
    // Blank line ending a paragraph
    ParagraphBuilder(bs), ["  ", ..ls]
    | ParagraphBuilder(bs), ["\\", ..ls]
    | ParagraphBuilder(bs), ["", ..ls]
    | ParagraphBuilder(bs), [_, ..ls]
      if is_blank_line
    ->
      do_parse_blocks(
        OutsideBlock,
        [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
        ls,
        pr,
      )
    OutsideBlock, ["  ", ..ls]
    | OutsideBlock, ["\\", ..ls]
    | OutsideBlock, ["", ..ls]
    -> do_parse_blocks(OutsideBlock, acc, ls, pr)
    // Setext headers
    ParagraphBuilder(bs), [_, ..ls] if is_setext_header ->
      case setext_header_results {
        Ok([Some("=")]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(1, Some(list.reverse(bs) |> string.join("\n"))), ..acc],
            ls,
            pr,
          )
        Ok([Some("-")]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(2, Some(list.reverse(bs) |> string.join("\n"))), ..acc],
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid Setext header parser state: "
            <> string.inspect(setext_header_results)
          }
      }
    // Horizontal breaks
    UnorderedListBuilder(item, items, tight, marker, _), [_, ..ls] if is_hr ->
      do_parse_blocks(
        OutsideBlock,
        [
          HorizontalBreak,
          UnorderedList(
            [item |> list.reverse |> parse_blocks(pr), ..items] |> list.reverse,
            tight && !list.any(list.drop(item, 1), is_empty_line),
            ul_marker(marker),
          ),
          ..acc
        ],
        ls,
        pr,
      )
    OrderedListBuilder(item, items, tight, marker, start, _), [_, ..ls]
      if is_hr
    ->
      do_parse_blocks(
        OutsideBlock,
        [
          HorizontalBreak,
          OrderedList(
            [item |> list.reverse |> parse_blocks(pr), ..items] |> list.reverse,
            start,
            tight && !list.any(list.drop(item, 1), is_empty_line),
            ol_marker(marker),
          ),
          ..acc
        ],
        ls,
        pr,
      )
    ParagraphBuilder(bs), [_, ..ls] if is_hr ->
      do_parse_blocks(
        OutsideBlock,
        [
          HorizontalBreak,
          Paragraph(list.reverse(bs) |> string.join("\n")),
          ..acc
        ],
        ls,
        pr,
      )
    OutsideBlock, [_, ..ls] if is_hr ->
      do_parse_blocks(OutsideBlock, [HorizontalBreak, ..acc], ls, pr)
    // Unordered lists
    UnorderedListBuilder(item, items, tight, marker, indent), [l, ..ls]
      if is_list_continuation
    ->
      do_parse_blocks(
        UnorderedListBuilder(
          [trim_indent(l, indent), ..item],
          items,
          tight,
          marker,
          indent,
        ),
        acc,
        ls,
        pr,
      )
    UnorderedListBuilder(item, items, tight, marker, _), [_, ..ls] if is_ul ->
      case ul_results {
        Ok([leading, Some(new_marker)]) if marker == new_marker ->
          do_parse_blocks(
            UnorderedListBuilder(
              [],
              [item |> list.reverse |> parse_blocks(pr), ..items],
              tight && !list.any(item, is_empty_line),
              marker,
              { option.unwrap(leading, "") |> string.length } + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(new_marker), Some(new_indent), rest])
          if marker == new_marker
        ->
          do_parse_blocks(
            UnorderedListBuilder(
              [rest |> option.unwrap("")],
              [item |> list.reverse |> parse_blocks(pr), ..items],
              tight && !list.any(item, is_empty_line),
              marker,
              string.length(new_indent)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(new_marker)]) ->
          do_parse_blocks(
            UnorderedListBuilder(
              [],
              [],
              True,
              new_marker,
              { option.unwrap(leading, "") |> string.length } + 1,
            ),
            [
              UnorderedList(
                [item |> list.reverse |> parse_blocks(pr), ..items]
                  |> list.reverse,
                tight && !list.any(list.drop(item, 1), is_empty_line),
                ul_marker(marker),
              ),
              ..acc
            ],
            ls,
            pr,
          )
        Ok([leading, Some(new_marker), Some(new_indent)]) ->
          do_parse_blocks(
            UnorderedListBuilder(
              [],
              [],
              True,
              new_marker,
              string.length(new_indent)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            [
              UnorderedList(
                [item |> list.reverse |> parse_blocks(pr), ..items]
                  |> list.reverse,
                tight && !list.any(list.drop(item, 1), is_empty_line),
                ul_marker(marker),
              ),
              ..acc
            ],
            ls,
            pr,
          )
        Ok([leading, Some(new_marker), Some(new_indent), rest]) ->
          do_parse_blocks(
            UnorderedListBuilder(
              rest |> option.map(list.wrap) |> option.unwrap([]),
              [],
              True,
              new_marker,
              string.length(new_indent)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            [
              UnorderedList(
                [item |> list.reverse |> parse_blocks(pr), ..items]
                  |> list.reverse,
                tight && !list.any(list.drop(item, 1), is_empty_line),
                ul_marker(marker),
              ),
              ..acc
            ],
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid unordered list parser state: "
            <> string.inspect(ul_results)
          }
      }
    UnorderedListBuilder(item, items, tight, marker, _), ls ->
      do_parse_blocks(
        OutsideBlock,
        [
          UnorderedList(
            [item |> list.reverse |> parse_blocks(pr), ..items] |> list.reverse,
            tight && !list.any(list.drop(item, 1), is_empty_line),
            ul_marker(marker),
          ),
          ..acc
        ],
        ls,
        pr,
      )
    OutsideBlock, [_, ..ls] if is_ul ->
      case ul_results {
        Ok([leading, Some(marker)]) ->
          do_parse_blocks(
            UnorderedListBuilder(
              [],
              [],
              True,
              marker,
              { option.unwrap(leading, "") |> string.length } + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(marker), Some(indent)]) ->
          do_parse_blocks(
            UnorderedListBuilder(
              [],
              [],
              True,
              marker,
              string.length(indent)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(marker), Some(indent), rest]) ->
          do_parse_blocks(
            UnorderedListBuilder(
              rest |> option.map(list.wrap) |> option.unwrap([]),
              [],
              True,
              marker,
              string.length(indent)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            acc,
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid unordered list parser state: "
            <> string.inspect(ul_results)
          }
      }
    // Ordered lists
    OrderedListBuilder(item, items, tight, marker, start, indent), [l, ..ls]
      if is_list_continuation
    ->
      do_parse_blocks(
        OrderedListBuilder(
          [trim_indent(l, indent), ..item],
          items,
          tight,
          marker,
          start,
          indent,
        ),
        acc,
        ls,
        pr,
      )
    OrderedListBuilder(item, items, tight, marker, start, _), [_, ..ls]
      if is_ol
    ->
      case ol_results {
        Ok([leading, _, Some(new_marker)]) if marker == new_marker ->
          do_parse_blocks(
            OrderedListBuilder(
              [],
              [item |> list.reverse |> parse_blocks(pr), ..items],
              tight && !list.any(item, is_empty_line),
              marker,
              start,
              { option.unwrap(leading, "") |> string.length } + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(new_start), Some(new_marker), Some(new_indent), rest])
          if marker == new_marker
        ->
          do_parse_blocks(
            OrderedListBuilder(
              [rest |> option.unwrap("")],
              [item |> list.reverse |> parse_blocks(pr), ..items],
              tight && !list.any(item, is_empty_line),
              marker,
              start,
              string.length(new_indent)
                + string.length(new_start)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(new_start), Some(new_marker)]) ->
          do_parse_blocks(
            OrderedListBuilder(
              [],
              [],
              True,
              new_marker,
              new_start |> int.parse |> result.unwrap(1),
              string.length(new_start)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            [
              OrderedList(
                [item |> list.reverse |> parse_blocks(pr), ..items]
                  |> list.reverse,
                start,
                tight && !list.any(list.drop(item, 1), is_empty_line),
                ol_marker(marker),
              ),
              ..acc
            ],
            ls,
            pr,
          )
        Ok([leading, Some(new_start), Some(new_marker), Some(new_indent), rest]) ->
          do_parse_blocks(
            OrderedListBuilder(
              [rest |> option.unwrap("")],
              [],
              True,
              new_marker,
              new_start |> int.parse |> result.unwrap(1),
              string.length(new_indent)
                + string.length(new_start)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            [
              OrderedList(
                [item |> list.reverse |> parse_blocks(pr), ..items]
                  |> list.reverse,
                start,
                tight && !list.any(list.drop(item, 1), is_empty_line),
                ol_marker(marker),
              ),
              ..acc
            ],
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid ordered list parser state: " <> string.inspect(ol_results)
          }
      }
    OrderedListBuilder(item, items, tight, marker, start, _), ls ->
      do_parse_blocks(
        OutsideBlock,
        [
          OrderedList(
            [item |> list.reverse |> parse_blocks(pr), ..items] |> list.reverse,
            start,
            tight && !list.any(list.drop(item, 1), is_empty_line),
            ol_marker(marker),
          ),
          ..acc
        ],
        ls,
        pr,
      )
    OutsideBlock, [_, ..ls] if is_ol ->
      case ol_results {
        Ok([leading, Some(start), Some(marker)]) ->
          do_parse_blocks(
            OrderedListBuilder(
              [],
              [],
              True,
              marker,
              start |> int.parse |> result.unwrap(1),
              string.length(start)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            acc,
            ls,
            pr,
          )
        Ok([leading, Some(start), Some(marker), Some(indent), rest]) ->
          do_parse_blocks(
            OrderedListBuilder(
              [rest |> option.unwrap("")],
              [],
              rest |> option.is_some,
              marker,
              start |> int.parse |> result.unwrap(1),
              string.length(indent)
                + string.length(start)
                + { option.unwrap(leading, "") |> string.length }
                + 1,
            ),
            acc,
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid ordered list parser state: " <> string.inspect(ol_results)
          }
      }
    // Indented code blocks
    OutsideBlock, [l, ..ls] if is_indented_code_block ->
      case is_blank_line {
        True -> do_parse_blocks(OutsideBlock, acc, ls, pr)
        False -> do_parse_blocks(IndentedCodeBlockBuilder([l]), acc, ls, pr)
      }
    IndentedCodeBlockBuilder(bs), [l] if is_indented_code_block ->
      do_parse_blocks(IndentedCodeBlockBuilder([l, ..bs]), acc, [], pr)
    IndentedCodeBlockBuilder(bs), [l, ..ls] if is_indented_code_block ->
      do_parse_blocks(IndentedCodeBlockBuilder([l, ..bs]), acc, ls, pr)
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
        pr,
      )
    // Fenced code blocks
    ParagraphBuilder(bs), [_, ..ls] if is_fenced_code_block ->
      case fenced_code_results {
        Ok([indent, Some(exit), _]) ->
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
            pr,
          )
        Ok([indent, Some(exit), _, full_info, info]) ->
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
            pr,
          )
        _ ->
          panic as {
            "Invalid fenced code block parser state: "
            <> string.inspect(fenced_code_results)
          }
      }
    OutsideBlock, [_, ..ls] if is_fenced_code_block ->
      case fenced_code_results {
        Ok([indent, Some(exit), _]) ->
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
            pr,
          )
        Ok([indent, Some(exit), _, full_info, info]) ->
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
            pr,
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
        pr,
      )
    FencedCodeBlockBuilder(break, info, full_info, bs, indent), [l, ..ls] ->
      do_parse_blocks(
        FencedCodeBlockBuilder(break, info, full_info, [l, ..bs], indent),
        acc,
        ls,
        pr,
      )
    // Block quotes and alerts
    AlertBuilder(level, bs), [_, ..ls] if is_block_quote ->
      case block_quote_results {
        Ok([None]) | Ok([]) ->
          do_parse_blocks(AlertBuilder(level, ["", ..bs]), acc, ls, pr)
        Ok([Some(l)]) ->
          do_parse_blocks(AlertBuilder(level, [l, ..bs]), acc, ls, pr)
        _ ->
          panic as {
            "Invalid block quote parser state: "
            <> string.inspect(block_quote_results)
          }
      }
    AlertBuilder(level, bs), [l, ..ls] ->
      case
        bs
        |> list.reverse
        |> parse_blocks(pr)
        |> list.last
      {
        Ok(Paragraph(_)) | Ok(BlockQuote(_)) if is_paragraph && !is_blank_line ->
          do_parse_blocks(AlertBuilder(level, [l, ..bs]), acc, ls, pr)
        _ ->
          do_parse_blocks(
            OutsideBlock,
            [Alert(level, bs |> list.reverse |> parse_blocks(pr)), ..acc],
            [l, ..ls],
            pr,
          )
      }
    BlockQuoteBuilder(bs), [_, ..ls] if is_block_quote ->
      case block_quote_results {
        Ok([None]) | Ok([]) ->
          do_parse_blocks(BlockQuoteBuilder(["", ..bs]), acc, ls, pr)
        Ok([Some(l)]) ->
          do_parse_blocks(BlockQuoteBuilder([l, ..bs]), acc, ls, pr)
        _ ->
          panic as {
            "Invalid block quote parser state: "
            <> string.inspect(block_quote_results)
          }
      }
    BlockQuoteBuilder(bs), [l, ..ls] ->
      case
        bs
        |> list.reverse
        |> parse_blocks(pr)
        |> list.last
      {
        Ok(Paragraph(_)) | Ok(BlockQuote(_)) if is_paragraph && !is_blank_line ->
          do_parse_blocks(BlockQuoteBuilder([l, ..bs]), acc, ls, pr)
        _ ->
          do_parse_blocks(
            OutsideBlock,
            [BlockQuote(bs |> list.reverse |> parse_blocks(pr)), ..acc],
            [l, ..ls],
            pr,
          )
      }
    ParagraphBuilder(bs), [_, ..ls] if is_block_quote ->
      case block_quote_results {
        Ok([Some("[!NOTE]")]) ->
          do_parse_blocks(
            AlertBuilder(ast.NoteAlert, []),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        Ok([Some("[!TIP]")]) ->
          do_parse_blocks(
            AlertBuilder(ast.TipAlert, []),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        Ok([Some("[!IMPORTANT]")]) ->
          do_parse_blocks(
            AlertBuilder(ast.ImportantAlert, []),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        Ok([Some("[!WARNING]")]) ->
          do_parse_blocks(
            AlertBuilder(ast.WarningAlert, []),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        Ok([Some("[!CAUTION]")]) ->
          do_parse_blocks(
            AlertBuilder(ast.CautionAlert, []),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        Ok([None]) | Ok([]) ->
          do_parse_blocks(
            BlockQuoteBuilder([""]),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        Ok([Some(l)]) ->
          do_parse_blocks(
            BlockQuoteBuilder([l]),
            [Paragraph(list.reverse(bs) |> string.join("\n")), ..acc],
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid block quote parser state: "
            <> string.inspect(block_quote_results)
          }
      }
    OutsideBlock, [_, ..ls] if is_block_quote ->
      case block_quote_results {
        Ok([Some("[!NOTE]")]) ->
          do_parse_blocks(AlertBuilder(ast.NoteAlert, []), acc, ls, pr)
        Ok([Some("[!TIP]")]) ->
          do_parse_blocks(AlertBuilder(ast.TipAlert, []), acc, ls, pr)
        Ok([Some("[!IMPORTANT]")]) ->
          do_parse_blocks(AlertBuilder(ast.ImportantAlert, []), acc, ls, pr)
        Ok([Some("[!WARNING]")]) ->
          do_parse_blocks(AlertBuilder(ast.WarningAlert, []), acc, ls, pr)
        Ok([Some("[!CAUTION]")]) ->
          do_parse_blocks(AlertBuilder(ast.CautionAlert, []), acc, ls, pr)
        Ok([None]) | Ok([]) ->
          do_parse_blocks(BlockQuoteBuilder([""]), acc, ls, pr)
        Ok([Some(l)]) -> do_parse_blocks(BlockQuoteBuilder([l]), acc, ls, pr)
        _ ->
          panic as {
            "Invalid block quote parser state: "
            <> string.inspect(block_quote_results)
          }
      }
    // ATX headers
    OutsideBlock, [_, ..ls] if is_atx_header ->
      case atx_header_results {
        Ok([Some(heading)]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(string.length(heading), None), ..acc],
            ls,
            pr,
          )
        Ok([Some(heading), Some(contents)]) ->
          do_parse_blocks(
            OutsideBlock,
            [Heading(string.length(heading), Some(contents)), ..acc],
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid ATX header parser state: "
            <> string.inspect(atx_header_results)
          }
      }
    ParagraphBuilder(bs), [_, ..ls] if is_atx_header ->
      case atx_header_results {
        Ok([Some(heading)]) ->
          do_parse_blocks(
            OutsideBlock,
            [
              Heading(string.length(heading), None),
              Paragraph(list.reverse(bs) |> string.join("\n")),
              ..acc
            ],
            ls,
            pr,
          )
        Ok([Some(heading), Some(contents)]) ->
          do_parse_blocks(
            OutsideBlock,
            [
              Heading(string.length(heading), Some(contents)),
              Paragraph(list.reverse(bs) |> string.join("\n")),
              ..acc
            ],
            ls,
            pr,
          )
        _ ->
          panic as {
            "Invalid ATX header parser state: "
            <> string.inspect(atx_header_results)
          }
      }
    // Paragraphs
    OutsideBlock, [line, ..ls] ->
      do_parse_blocks(ParagraphBuilder([line]), acc, ls, pr)
    ParagraphBuilder(bs), [line, ..ls] ->
      do_parse_blocks(ParagraphBuilder([line, ..bs]), acc, ls, pr)
  }
}

fn parse_blocks(lines: List(String), pr: ParserRegexes) -> List(BlockParseState) {
  do_parse_blocks(OutsideBlock, [], lines, pr)
}

pub fn parse_document(lines: List(String)) -> ast.Document {
  let parser_regexes = definitions.get_parser_regexes()

  let #(blocks, refs) =
    parse_blocks(lines, parser_regexes)
    |> list.map(parse_block_state)
    |> list.unzip
    |> pair.map_second(merge_references)

  ast.Document(blocks, refs)
}
