import commonmark/ast
import commonmark/internal/parser/entity
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/regex.{Match}
import gleam/result
import gleam/string

type InlineLexer {
  Entity(name: String, replacement: String)
  Escaped(String)
  Text(String)
  LessThan
  GreaterThan
  Backtick
  Tilde
  Asterisk
  Underscore
  SoftLineBreak
  HardLineBreak(String)
}

type InlineWrapper {
  LexedElement(InlineLexer)
  EmailAutolink(List(InlineWrapper))
  UriAutolink(List(InlineWrapper))
  BacktickString(Int)
  TildeString(Int)
  SingleAsterisk
  DoubleAsterisk
  TripleAsterisk
  SingleUnderscore
  DoubleUnderscore
  TripleUnderscore
  Emphasis(List(InlineWrapper), ast.EmphasisMarker)
  StrongEmphasis(List(InlineWrapper), ast.EmphasisMarker)
  CodeSpan(Int, List(InlineWrapper))
  Strikethrough(Int, List(InlineWrapper))
}

pub const replacement_char = 0xfffd

pub const insecure_codepoints = [0]

const ascii_punctuation = [
  "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/",
  ":", ";", "<", "=", ">", "?", "@", "[", "]", "\\", "^", "_", "`", "{", "|",
  "}", "~",
]

fn replace_null_byte(n: Int) {
  case list.contains(insecure_codepoints, n) {
    True -> 0xfffd
    False -> n
  }
}

/// "Unlex" an element back to it's raw form
fn to_string(el: InlineWrapper) {
  case el {
    LexedElement(HardLineBreak(s)) | LexedElement(Text(s)) -> s
    LexedElement(Escaped(s)) -> "\\" <> s
    LexedElement(LessThan) -> "<"
    LexedElement(GreaterThan) -> ">"
    LexedElement(Backtick) -> "`"
    LexedElement(Tilde) -> "~"
    LexedElement(Asterisk) -> "*"
    LexedElement(Underscore) -> "_"
    LexedElement(SoftLineBreak) -> "\n"
    LexedElement(Entity(name: e, ..)) -> "&" <> e
    SingleAsterisk -> "*"
    DoubleAsterisk -> "**"
    TripleAsterisk -> "***"
    SingleUnderscore -> "_"
    DoubleUnderscore -> "__"
    TripleUnderscore -> "___"
    Emphasis(contents, marker) ->
      case marker {
        ast.AsteriskEmphasisMarker -> "*" <> list_to_string(contents) <> "*"
        ast.UnderscoreEmphasisMarker -> "_" <> list_to_string(contents) <> "_"
      }
    StrongEmphasis(contents, marker) ->
      case marker {
        ast.AsteriskEmphasisMarker -> "**" <> list_to_string(contents) <> "**"
        ast.UnderscoreEmphasisMarker -> "__" <> list_to_string(contents) <> "__"
      }
    BacktickString(count) -> string.repeat("`", count)
    CodeSpan(count, content) ->
      string.repeat("`", count)
      <> list_to_string(content)
      <> string.repeat("`", count)
    TildeString(count) -> string.repeat("~", count)
    Strikethrough(count, content) ->
      string.repeat("~", count)
      <> list_to_string(content)
      <> string.repeat("~", count)
    EmailAutolink(ls) -> "<" <> list_to_string(ls) <> ">"
    UriAutolink(ls) -> "<" <> list_to_string(ls) <> ">"
  }
}

fn list_to_string(els: List(InlineWrapper)) {
  list.map(els, to_string) |> string.join("")
}

fn translate_numerical_entity(
  codepoint: Result(Int, Nil),
  rest: List(String),
) -> Result(#(List(String), String), Nil) {
  codepoint
  |> result.map(replace_null_byte)
  |> result.try(string.utf_codepoint)
  |> result.map(fn(cp) { #(rest, string.from_utf_codepoints([cp])) })
}

fn match_entity(
  input: List(String),
) -> Result(#(List(String), String, String), Nil) {
  entity.match_html_entity(input)
  |> result.try_recover(fn(_) {
    let assert Ok(dec_entity) = regex.from_string("^#([0-9]{1,7});")
    let assert Ok(hex_entity) = regex.from_string("^#([xX]([0-9a-fA-F]{1,6}));")
    let potential = list.take(input, 9) |> string.join("")

    case regex.scan(dec_entity, potential), regex.scan(hex_entity, potential) {
      [regex.Match(full, [Some(n)])], _ ->
        n
        |> int.parse
        |> translate_numerical_entity(list.drop(input, string.length(full)))
        |> result.map(fn(r) { #(r.0, n, r.1) })
      _, [regex.Match(full, [Some(m), Some(n)])] ->
        n
        |> int.base_parse(16)
        |> translate_numerical_entity(list.drop(input, string.length(full)))
        |> result.map(fn(r) { #(r.0, m, r.1) })
      _, _ -> Error(Nil)
    }
  })
}

fn do_lex_inline_text(
  input: List(String),
  text: List(String),
  acc: List(InlineLexer),
) -> List(InlineLexer) {
  case input {
    [] ->
      [Text(text |> list.reverse |> string.join("")), ..acc]
      |> list.filter(fn(x) { x != Text("") })
      |> list.reverse
    ["<", ..xs] ->
      do_lex_inline_text(xs, [], [
        LessThan,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    [">", ..xs] ->
      do_lex_inline_text(xs, [], [
        GreaterThan,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["`", ..xs] ->
      do_lex_inline_text(xs, [], [
        Backtick,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["~", ..xs] ->
      do_lex_inline_text(xs, [], [
        Tilde,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["_", ..xs] ->
      do_lex_inline_text(xs, [], [
        Underscore,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["*", ..xs] ->
      do_lex_inline_text(xs, [], [
        Asterisk,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["\\", "\n", ..xs] ->
      do_lex_inline_text(xs, [], [
        HardLineBreak("\\\n"),
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    [" ", " ", "\n", ..xs] ->
      do_lex_inline_text(xs, [], [
        HardLineBreak("  \n"),
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["\n", ..xs] ->
      do_lex_inline_text(xs, [], [
        SoftLineBreak,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["&", ..xs] ->
      case match_entity(xs) {
        Ok(#(rest, e, replacement)) ->
          do_lex_inline_text(rest, [], [
            Entity(e, replacement),
            Text(text |> list.reverse |> string.join("")),
            ..acc
          ])
        Error(_) -> do_lex_inline_text(xs, ["&", ..text], acc)
      }
    ["\\", g, ..xs] ->
      case list.contains(ascii_punctuation, g) {
        True ->
          do_lex_inline_text(xs, [], [
            Escaped(g),
            Text(text |> list.reverse |> string.join("")),
            ..acc
          ])
        False -> do_lex_inline_text(xs, [g, "\\", ..text], acc)
      }
    [x, ..xs] -> do_lex_inline_text(xs, [x, ..text], acc)
  }
}

fn parse_code_span(
  size: Int,
  previous: List(InlineWrapper),
) -> List(InlineWrapper) {
  case list.split_while(previous, fn(n) { n != BacktickString(size) }) {
    #(_, []) -> [BacktickString(size), ..previous]
    #(wrapped, [_, ..rest]) -> [CodeSpan(size, list.reverse(wrapped)), ..rest]
  }
}

fn parse_autolink(href: List(InlineWrapper)) -> Result(InlineWrapper, Nil) {
  // Borrowed direct from the spec
  let assert Ok(email_regex) =
    regex.from_string(
      "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    )
  let assert Ok(uri_regex) =
    regex.from_string("^[a-zA-Z][-a-zA-Z+.]{1,31}:[^ \t]+$")
  let href_str = list_to_string(href)

  case regex.check(email_regex, href_str), regex.check(uri_regex, href_str) {
    True, _ -> Ok(EmailAutolink(href))
    _, True -> Ok(UriAutolink(href))
    False, False -> Error(Nil)
  }
}

fn is_not_less_than(v: InlineWrapper) -> Bool {
  case v {
    LexedElement(LessThan) -> False
    _ -> True
  }
}

fn do_parse_inline_wrappers(
  lexed: List(InlineLexer),
  acc: List(InlineWrapper),
) -> List(InlineWrapper) {
  case lexed {
    [] -> acc |> list.reverse
    [GreaterThan, ..ls] ->
      case list.split_while(acc, is_not_less_than) {
        #(_, []) ->
          do_parse_inline_wrappers(ls, [LexedElement(GreaterThan), ..acc])
        #(to_wrap, [_, ..rest]) ->
          case parse_autolink(to_wrap |> list.reverse) {
            Ok(wrapped) -> do_parse_inline_wrappers(ls, [wrapped, ..rest])
            Error(_) ->
              do_parse_inline_wrappers(ls, [LexedElement(GreaterThan), ..acc])
          }
      }
    [Backtick, Backtick, ..ls] ->
      case list.first(acc) {
        Ok(BacktickString(count)) ->
          do_parse_inline_wrappers([Backtick, ..ls], [
            BacktickString(count + 1),
            ..list.drop(acc, 1)
          ])
        _ ->
          do_parse_inline_wrappers([Backtick, ..ls], [BacktickString(1), ..acc])
      }
    [Backtick, ..ls] -> {
      let acc = case list.first(acc) {
        Ok(BacktickString(count)) ->
          parse_code_span(count + 1, list.drop(acc, 1))
        _ -> parse_code_span(1, acc)
      }

      do_parse_inline_wrappers(ls, acc)
    }
    [Asterisk, Asterisk, Asterisk, ..ls] ->
      do_parse_inline_wrappers(ls, [TripleAsterisk, ..acc])
    [Asterisk, Asterisk, ..ls] ->
      do_parse_inline_wrappers(ls, [DoubleAsterisk, ..acc])
    [Asterisk, ..ls] -> do_parse_inline_wrappers(ls, [SingleAsterisk, ..acc])
    [Underscore, Underscore, Underscore, ..ls] ->
      do_parse_inline_wrappers(ls, [TripleUnderscore, ..acc])
    [Underscore, Underscore, ..ls] ->
      do_parse_inline_wrappers(ls, [DoubleUnderscore, ..acc])
    [Underscore, ..ls] ->
      do_parse_inline_wrappers(ls, [SingleUnderscore, ..acc])
    [Tilde, Tilde, ..ls] ->
      case list.first(acc) {
        Ok(TildeString(count)) ->
          do_parse_inline_wrappers([Tilde, ..ls], [
            TildeString(count + 1),
            ..list.drop(acc, 1)
          ])
        _ -> do_parse_inline_wrappers([Tilde, ..ls], [TildeString(1), ..acc])
      }
    [Tilde, ..ls] -> {
      let #(count, acc) = case list.first(acc) {
        Ok(TildeString(count)) -> #(count + 1, list.drop(acc, 1))
        _ -> #(1, acc)
      }

      do_parse_inline_wrappers(ls, [TildeString(count), ..acc])
    }
    [Entity(_, _) as v, ..ls]
    | [Escaped(_) as v, ..ls]
    | [LessThan as v, ..ls]
    | [HardLineBreak(_) as v, ..ls]
    | [SoftLineBreak as v, ..ls]
    | [Text(_) as v, ..ls] ->
      do_parse_inline_wrappers(ls, [LexedElement(v), ..acc])
  }
}

fn parse_strikethrough(
  size: Int,
  previous: List(InlineWrapper),
) -> List(InlineWrapper) {
  case list.split_while(previous, fn(n) { n != TildeString(size) }) {
    #(_, []) -> [TildeString(size), ..previous]
    #(wrapped, [_, ..rest]) -> [
      Strikethrough(size, list.reverse(wrapped)),
      ..rest
    ]
  }
}

fn parse_triple_emphasis(
  delimiter: InlineWrapper,
  marker: ast.EmphasisMarker,
  previous: List(InlineWrapper),
) {
  case list.split_while(previous, fn(n) { n != delimiter }) {
    #(_, []) -> [delimiter, ..previous]
    #(wrapped, [_, ..rest]) -> [
      Emphasis([StrongEmphasis(list.reverse(wrapped), marker)], marker),
      ..rest
    ]
  }
}

fn parse_double_emphasis(
  delimiter: InlineWrapper,
  marker: ast.EmphasisMarker,
  previous: List(InlineWrapper),
) {
  case list.split_while(previous, fn(n) { n != delimiter }) {
    #(_, []) -> [delimiter, ..previous]
    #(wrapped, [_, ..rest]) -> [
      StrongEmphasis(list.reverse(wrapped), marker),
      ..rest
    ]
  }
}

import gleam/io

fn parse_single_emphasis(
  delimiter: InlineWrapper,
  marker: ast.EmphasisMarker,
  previous: List(InlineWrapper),
) {
  case io.debug(list.split_while(previous, fn(n) { n != delimiter })) {
    #(_, []) -> [delimiter, ..previous]
    #(wrapped, [_, ..rest]) ->
      io.debug([Emphasis(list.reverse(wrapped), marker), ..rest])
  }
}

fn do_parse_emphasis(wrapped: List(InlineWrapper), acc: List(InlineWrapper)) {
  case wrapped {
    [] -> acc |> list.reverse
    [TildeString(count), ..xs] -> {
      case count <= 2 {
        True -> do_parse_emphasis(xs, parse_strikethrough(count, acc))
        False -> do_parse_emphasis(xs, [TildeString(count), ..acc])
      }
    }
    [TripleAsterisk, ..xs] ->
      do_parse_emphasis(
        xs,
        parse_triple_emphasis(TripleAsterisk, ast.AsteriskEmphasisMarker, acc),
      )
    [DoubleAsterisk, ..xs] ->
      do_parse_emphasis(
        xs,
        parse_double_emphasis(DoubleAsterisk, ast.AsteriskEmphasisMarker, acc),
      )
    [SingleAsterisk, ..xs] ->
      do_parse_emphasis(
        xs,
        parse_single_emphasis(SingleAsterisk, ast.AsteriskEmphasisMarker, acc),
      )
    [TripleUnderscore, ..xs] ->
      do_parse_emphasis(
        xs,
        parse_triple_emphasis(
          TripleUnderscore,
          ast.UnderscoreEmphasisMarker,
          acc,
        ),
      )
    [DoubleUnderscore, ..xs] ->
      do_parse_emphasis(
        xs,
        parse_double_emphasis(
          DoubleUnderscore,
          ast.UnderscoreEmphasisMarker,
          acc,
        ),
      )
    [SingleUnderscore, ..xs] ->
      do_parse_emphasis(
        xs,
        parse_single_emphasis(
          SingleUnderscore,
          ast.UnderscoreEmphasisMarker,
          acc,
        ),
      )
    [x, ..xs] -> do_parse_emphasis(xs, [x, ..acc])
  }
}

fn do_parse_inline_ast(
  wrapped: List(InlineWrapper),
  acc: List(ast.InlineNode),
) -> List(ast.InlineNode) {
  case wrapped {
    [] -> acc |> list.reverse
    [EmailAutolink(l), ..ws] ->
      do_parse_inline_ast(ws, [ast.EmailAutolink(list_to_string(l)), ..acc])
    [UriAutolink(l), ..ws] ->
      do_parse_inline_ast(ws, [ast.UriAutolink(list_to_string(l)), ..acc])
    [BacktickString(count), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(string.repeat("`", count)), ..acc])
    [CodeSpan(_, contents), ..ws] -> {
      let assert Ok(r) = regex.from_string("^ (.*) $")
      let c = contents |> list_to_string |> string.replace("\n", " ")

      case regex.scan(r, c) {
        [Match(_, [Some(span)])] ->
          do_parse_inline_ast(ws, [ast.CodeSpan(span), ..acc])
        _ -> do_parse_inline_ast(ws, [ast.CodeSpan(c), ..acc])
      }
    }
    [TildeString(count), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(string.repeat("~", count)), ..acc])
    [Strikethrough(_, contents), ..ws] ->
      do_parse_inline_ast(ws, [
        ast.StrikeThrough(do_parse_inline_ast(contents, [])),
        ..acc
      ])
    [Emphasis(contents, marker), ..ws] ->
      do_parse_inline_ast(ws, [
        ast.Emphasis(do_parse_inline_ast(contents, []), marker),
        ..acc
      ])
    [StrongEmphasis(contents, marker), ..ws] ->
      do_parse_inline_ast(ws, [
        ast.StrongEmphasis(do_parse_inline_ast(contents, []), marker),
        ..acc
      ])
    [SingleAsterisk, ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("*"), ..acc])
    [DoubleAsterisk, ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("**"), ..acc])
    [TripleAsterisk, ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("***"), ..acc])
    [SingleUnderscore, ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("_"), ..acc])
    [DoubleUnderscore, ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("__"), ..acc])
    [TripleUnderscore, ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("___"), ..acc])
    [LexedElement(Escaped(s)), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(s), ..acc])
    [LexedElement(Entity(replacement: r, ..)), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(r), ..acc])
    [LexedElement(SoftLineBreak), ..ws] ->
      do_parse_inline_ast(ws, [ast.SoftLineBreak, ..acc])
    [LexedElement(HardLineBreak(_)), ..ws] ->
      do_parse_inline_ast(ws, [ast.HardLineBreak, ..acc])
    [LexedElement(Asterisk), ..ws] ->
      do_parse_inline_ast([LexedElement(Text("*")), ..ws], acc)
    [LexedElement(Underscore), ..ws] ->
      do_parse_inline_ast([LexedElement(Text("_")), ..ws], acc)
    [LexedElement(Backtick), ..ws] ->
      do_parse_inline_ast([LexedElement(Text("`")), ..ws], acc)
    [LexedElement(Tilde), ..ws] ->
      do_parse_inline_ast([LexedElement(Text("~")), ..ws], acc)
    [LexedElement(GreaterThan), ..ws] ->
      do_parse_inline_ast([LexedElement(Text(">")), ..ws], acc)
    [LexedElement(LessThan), ..ws] ->
      do_parse_inline_ast([LexedElement(Text("<")), ..ws], acc)
    [LexedElement(Text(t)), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(t), ..acc])
  }
}

fn trim_left(x: String) -> String {
  case x {
    " " <> x -> trim_left(x)
    "\t" <> x -> trim_left(x)
    _ -> x
  }
}

fn trim_right(x: String) -> String {
  x |> string.reverse |> trim_left |> string.reverse
}

fn do_finalise_plain_text(ast: List(ast.InlineNode), acc: List(ast.InlineNode)) {
  case ast, acc {
    [], [ast.PlainText(y), ..ys] ->
      [ast.PlainText(trim_right(y)), ..ys] |> list.reverse
    [], _ -> acc |> list.reverse
    [ast.PlainText(x), ..xs], [ast.PlainText(y), ..ys] ->
      do_finalise_plain_text(xs, [ast.PlainText(y <> x), ..ys])
    [ast.PlainText(x), ..xs], []
    | [ast.PlainText(x), ..xs], [ast.HardLineBreak, ..]
    | [ast.PlainText(x), ..xs], [ast.SoftLineBreak, ..]
    -> do_finalise_plain_text(xs, [ast.PlainText(trim_left(x)), ..acc])
    [ast.HardLineBreak as x, ..xs], [ast.PlainText(y), ..ys]
    | [ast.SoftLineBreak as x, ..xs], [ast.PlainText(y), ..ys]
    -> do_finalise_plain_text(xs, [x, ast.PlainText(trim_right(y)), ..ys])
    [x, ..xs], _ -> do_finalise_plain_text(xs, [x, ..acc])
  }
}

pub fn parse_text(text: String) -> List(ast.InlineNode) {
  text
  |> string.to_graphemes
  |> do_lex_inline_text([], [])
  |> do_parse_inline_wrappers([])
  |> do_parse_emphasis([])
  |> do_parse_inline_ast([])
  |> do_finalise_plain_text([])
}
