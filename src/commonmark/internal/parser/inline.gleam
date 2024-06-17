import commonmark/ast
import commonmark/internal/parser/entity
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/regex.{Match}
import gleam/result
import gleam/string

type InlineLexer {
  Escaped(String)
  Text(String)
  LessThan
  GreaterThan
  Backtick
  Tilde
  SoftLineBreak
  HardLineBreak(String)
}

type InlineWrapper {
  LexedElement(InlineLexer)
  EmailAutolink(List(InlineWrapper))
  UriAutolink(List(InlineWrapper))
  BacktickString(Int)
  CodeSpan(Int, List(InlineWrapper))
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

fn to_string(el: InlineWrapper) {
  case el {
    LexedElement(HardLineBreak(s)) | LexedElement(Text(s)) -> s
    LexedElement(Escaped(s)) -> "\\" <> s
    LexedElement(LessThan) -> "<"
    LexedElement(GreaterThan) -> ">"
    LexedElement(Backtick) -> "`"
    LexedElement(Tilde) -> "~"
    LexedElement(SoftLineBreak) -> "\n"
    BacktickString(count) -> string.repeat("`", count)
    CodeSpan(count, content) ->
      string.repeat("`", count)
      <> list_to_string(content)
      <> string.repeat("`", count)
    EmailAutolink(ls) -> "<" <> list_to_string(ls) <> ">"
    UriAutolink(ls) -> "<" <> list_to_string(ls) <> ">"
  }
}

fn list_to_string(els: List(InlineWrapper)) {
  list.map(els, to_string) |> string.join("")
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

fn finalise_plain_text(ast: List(ast.InlineNode), acc: List(ast.InlineNode)) {
  case ast, acc {
    [], [ast.PlainText(y), ..ys] ->
      [ast.PlainText(trim_right(y)), ..ys] |> list.reverse
    [], _ -> acc |> list.reverse
    [ast.PlainText(x), ..xs], [ast.PlainText(y), ..ys] ->
      finalise_plain_text(xs, [ast.PlainText(y <> x), ..ys])
    [ast.PlainText(x), ..xs], _ ->
      finalise_plain_text(xs, [ast.PlainText(trim_left(x)), ..acc])
    [ast.HardLineBreak as x, ..xs], [ast.PlainText(y), ..ys]
    | [ast.SoftLineBreak as x, ..xs], [ast.PlainText(y), ..ys]
    -> finalise_plain_text(xs, [x, ast.PlainText(trim_right(y)), ..ys])
    [x, ..xs], _ -> finalise_plain_text(xs, [x, ..acc])
  }
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

fn match_entity(input: List(String)) -> Result(#(List(String), String), Nil) {
  entity.match_html_entity(input)
  |> result.try_recover(fn(_) {
    let assert Ok(dec_entity) = regex.from_string("^#([0-9]{1,7});")
    let assert Ok(hex_entity) = regex.from_string("^#[xX]([0-9a-fA-F]{1,6});")
    let potential = list.take(input, 9) |> string.join("")

    case regex.scan(dec_entity, potential), regex.scan(hex_entity, potential) {
      [regex.Match(full, [Some(n)])], _ ->
        n
        |> int.parse
        |> translate_numerical_entity(list.drop(input, string.length(full)))
      _, [regex.Match(full, [Some(n)])] ->
        n
        |> int.base_parse(16)
        |> translate_numerical_entity(list.drop(input, string.length(full)))
      _, _ -> Error(Nil)
    }
  })
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

fn parse_code_span(
  size: Int,
  previous: List(InlineWrapper),
) -> List(InlineWrapper) {
  case list.split_while(previous, fn(n) { n != BacktickString(size) }) {
    #(_, []) -> [BacktickString(size), ..previous]
    #(wrapped, [_, ..rest]) -> [CodeSpan(size, list.reverse(wrapped)), ..rest]
  }
}

fn lex_inline_text(
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
      lex_inline_text(xs, [], [
        LessThan,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    [">", ..xs] ->
      lex_inline_text(xs, [], [
        GreaterThan,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["`", ..xs] ->
      lex_inline_text(xs, [], [
        Backtick,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["~", ..xs] ->
      lex_inline_text(xs, [], [
        Tilde,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["\\", "\n", ..xs] ->
      lex_inline_text(xs, [], [
        HardLineBreak("\\\n"),
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    [" ", " ", "\n", ..xs] ->
      lex_inline_text(xs, [], [
        HardLineBreak("  \n"),
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["\n", ..xs] ->
      lex_inline_text(xs, [], [
        SoftLineBreak,
        Text(text |> list.reverse |> string.join("")),
        ..acc
      ])
    ["&", ..xs] ->
      case match_entity(xs) {
        Ok(#(rest, replacement)) ->
          lex_inline_text(rest, [replacement, ..text], acc)
        Error(_) -> lex_inline_text(xs, ["&", ..text], acc)
      }
    ["\\", g, ..xs] ->
      case list.contains(ascii_punctuation, g) {
        True ->
          lex_inline_text(xs, [], [
            Escaped(g),
            Text(text |> list.reverse |> string.join("")),
            ..acc
          ])
        False -> lex_inline_text(xs, [g, "\\", ..text], acc)
      }
    [x, ..xs] -> lex_inline_text(xs, [x, ..text], acc)
  }
}

fn is_not_less_than(v: InlineWrapper) -> Bool {
  case v {
    LexedElement(LessThan) -> False
    _ -> True
  }
}

fn parse_inline_wrappers(
  lexed: List(InlineLexer),
  acc: List(InlineWrapper),
) -> List(InlineWrapper) {
  case lexed {
    // Intentionally not reversed, we will reverse it in the parse_inline_ast phase which is order independent
    [] -> acc
    [GreaterThan, ..ls] ->
      case list.split_while(acc, is_not_less_than) {
        #(_, []) ->
          parse_inline_wrappers(ls, [LexedElement(GreaterThan), ..acc])
        #(to_wrap, [_, ..rest]) ->
          case parse_autolink(to_wrap |> list.reverse) {
            Ok(wrapped) -> parse_inline_wrappers(ls, [wrapped, ..rest])
            Error(_) ->
              parse_inline_wrappers(ls, [LexedElement(GreaterThan), ..acc])
          }
      }
    [Backtick, Backtick, ..ls] ->
      case list.first(acc) {
        Ok(BacktickString(count)) ->
          parse_inline_wrappers([Backtick, ..ls], [
            BacktickString(count + 1),
            ..acc
          ])
        _ -> parse_inline_wrappers([Backtick, ..ls], [BacktickString(1), ..acc])
      }
    [Backtick, ..ls] -> {
      let acc = case list.first(acc) {
        Ok(BacktickString(count)) ->
          parse_code_span(count + 1, list.drop(acc, 1))
        _ -> parse_code_span(1, acc)
      }

      parse_inline_wrappers(ls, acc)
    }
    [Tilde as v, ..ls]
    | [Escaped(_) as v, ..ls]
    | [LessThan as v, ..ls]
    | [HardLineBreak(_) as v, ..ls]
    | [SoftLineBreak as v, ..ls]
    | [Text(_) as v, ..ls] ->
      parse_inline_wrappers(ls, [LexedElement(v), ..acc])
  }
}

fn parse_inline_ast(
  wrapped: List(InlineWrapper),
  acc: List(ast.InlineNode),
) -> List(ast.InlineNode) {
  case wrapped {
    // Intentionally not reversed as our input is reversed coming from the parse_inline_wrappers step
    [] -> acc
    [EmailAutolink(l), ..ws] ->
      parse_inline_ast(ws, [ast.EmailAutolink(list_to_string(l)), ..acc])
    [UriAutolink(l), ..ws] ->
      parse_inline_ast(ws, [ast.UriAutolink(list_to_string(l)), ..acc])
    [BacktickString(count), ..ws] ->
      parse_inline_ast(ws, [ast.PlainText(string.repeat("`", count)), ..acc])
    [CodeSpan(_, contents), ..ws] -> {
      let assert Ok(r) = regex.from_string("^ (.*) $")
      let c = contents |> list_to_string |> string.replace("\n", " ")

      case regex.scan(r, c) {
        [Match(_, [Some(span)])] ->
          parse_inline_ast(ws, [ast.CodeSpan(span), ..acc])
        _ -> parse_inline_ast(ws, [ast.CodeSpan(c), ..acc])
      }
    }
    [LexedElement(Escaped(s)), ..ws] ->
      parse_inline_ast(ws, [ast.PlainText(s), ..acc])
    [LexedElement(SoftLineBreak), ..ws] ->
      parse_inline_ast(ws, [ast.SoftLineBreak, ..acc])
    [LexedElement(HardLineBreak(_)), ..ws] ->
      parse_inline_ast(ws, [ast.HardLineBreak, ..acc])
    [LexedElement(Backtick), ..ws] ->
      parse_inline_ast([LexedElement(Text("`")), ..ws], acc)
    [LexedElement(Tilde), ..ws] ->
      parse_inline_ast([LexedElement(Text("~")), ..ws], acc)
    [LexedElement(GreaterThan), ..ws] ->
      parse_inline_ast([LexedElement(Text(">")), ..ws], acc)
    [LexedElement(LessThan), ..ws] ->
      parse_inline_ast([LexedElement(Text("<")), ..ws], acc)
    [LexedElement(Text(t)), ..ws] ->
      parse_inline_ast(ws, [ast.PlainText(t), ..acc])
  }
}

pub fn parse_text(text: String) -> List(ast.InlineNode) {
  text
  |> string.to_graphemes
  |> lex_inline_text([], [])
  |> parse_inline_wrappers([])
  |> parse_inline_ast([])
  |> finalise_plain_text([])
}
