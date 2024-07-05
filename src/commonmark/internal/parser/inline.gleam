import commonmark/ast
import commonmark/internal/definitions
import commonmark/internal/parser/entity
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex.{Match}
import gleam/result
import gleam/string

type InlineLexer {
  Entity(name: String, replacement: String)
  Escaped(String)
  Word(String)
  WhiteSpace(String)
  LessThan
  GreaterThan
  Backtick
  Tilde
  Asterisk
  Underscore
  OpenBracket
  CloseBracket
  ImageStart
  OpenSquareBracket
  CloseSquareBracket
  SingleQuote
  DoubleQuote
  Exclamation
  SoftLineBreak
  HardLineBreak(String)
}

type InlineWrapper {
  LexedElement(InlineLexer)
  EmailAutolink(List(InlineWrapper))
  UriAutolink(List(InlineWrapper))
  BacktickString(Int)
  TildeString(Int)
  AsteriskString(Int)
  UnderscoreString(Int)
  UriImage(alt: String, href: String, title: Option(String))
  UriLink(List(InlineWrapper), href: String, title: Option(String))
  Emphasis(List(InlineWrapper), ast.EmphasisMarker)
  StrongEmphasis(List(InlineWrapper), ast.EmphasisMarker)
  CodeSpan(Int, List(InlineWrapper))
  Strikethrough(Int, List(InlineWrapper))
}

fn replace_insecure_byte(n: Int) {
  case list.contains(definitions.insecure_codepoints, n) {
    True -> 0xfffd
    False -> n
  }
}

/// "Unlex" an element back to it's original text
fn to_string(el: InlineWrapper) {
  case el {
    LexedElement(HardLineBreak(s))
    | LexedElement(Word(s))
    | LexedElement(WhiteSpace(s)) -> s
    LexedElement(Escaped(s)) -> "\\" <> s
    LexedElement(LessThan) -> "<"
    LexedElement(GreaterThan) -> ">"
    LexedElement(Backtick) -> "`"
    LexedElement(Tilde) -> "~"
    LexedElement(Asterisk) -> "*"
    LexedElement(Underscore) -> "_"
    LexedElement(SoftLineBreak) -> "\n"
    LexedElement(Entity(name: e, ..)) -> "&" <> e
    LexedElement(OpenBracket) -> "("
    LexedElement(CloseBracket) -> ")"
    LexedElement(ImageStart) -> "!["
    LexedElement(OpenSquareBracket) -> "["
    LexedElement(CloseSquareBracket) -> "]"
    LexedElement(SingleQuote) -> "'"
    LexedElement(DoubleQuote) -> "\""
    LexedElement(Exclamation) -> "!"
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
    AsteriskString(count) -> string.repeat("*", count)
    UnderscoreString(count) -> string.repeat("_", count)
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
    // The remaining ones here are approximate and potentially not even valid, but should never actually run in practice.
    UriImage(alt, href, title) -> {
      let title =
        title |> option.map(fn(t) { " '" <> t <> "'" }) |> option.unwrap("")
      "![" <> alt <> "](<" <> href <> ">" <> title <> ")"
    }
    UriLink(content, href, title) -> {
      let title =
        title |> option.map(fn(t) { " '" <> t <> "'" }) |> option.unwrap("")
      "[" <> list_to_string(content) <> "](<" <> href <> ">" <> title <> ")"
    }
  }
}

fn list_to_string(els: List(InlineWrapper)) {
  list.map(els, to_string) |> string.join("")
}

fn to_text(el: InlineWrapper) {
  case el {
    LexedElement(Word(s)) | LexedElement(WhiteSpace(s)) -> s
    LexedElement(Escaped(s)) -> s
    LexedElement(LessThan) -> "<"
    LexedElement(GreaterThan) -> ">"
    LexedElement(Backtick) -> "`"
    LexedElement(Tilde) -> "~"
    LexedElement(Asterisk) -> "*"
    LexedElement(Underscore) -> "_"
    LexedElement(HardLineBreak(_)) | LexedElement(SoftLineBreak) -> "\n"
    LexedElement(Entity(replacement: e, ..)) -> e
    LexedElement(OpenBracket) -> "("
    LexedElement(CloseBracket) -> ")"
    LexedElement(ImageStart) -> "!["
    LexedElement(OpenSquareBracket) -> "["
    LexedElement(CloseSquareBracket) -> "]"
    LexedElement(SingleQuote) -> "'"
    LexedElement(DoubleQuote) -> "\""
    LexedElement(Exclamation) -> "!"
    CodeSpan(_, contents) | Emphasis(contents, _) | StrongEmphasis(contents, _) ->
      list_to_text(contents)
    BacktickString(count) -> string.repeat("`", count)
    AsteriskString(count) -> string.repeat("*", count)
    UnderscoreString(count) -> string.repeat("_", count)
    TildeString(count) -> string.repeat("~", count)
    Strikethrough(_, content) -> list_to_text(content)
    EmailAutolink(ls) | UriAutolink(ls) -> list_to_text(ls)
    UriImage(alt, _, _) -> alt
    UriLink(content, _, _) -> list_to_text(content)
  }
}

fn list_to_text(els: List(InlineWrapper)) {
  list.map(els, to_text) |> string.join("")
}

fn translate_numerical_entity(
  codepoint: Result(Int, Nil),
  rest: List(String),
) -> Result(#(List(String), String), Nil) {
  codepoint
  |> result.map(replace_insecure_byte)
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
  acc: List(InlineLexer),
) -> List(InlineLexer) {
  case input {
    [] -> acc |> list.reverse
    ["<", ..xs] -> do_lex_inline_text(xs, [LessThan, ..acc])
    [">", ..xs] -> do_lex_inline_text(xs, [GreaterThan, ..acc])
    ["!", "[", ..xs] -> do_lex_inline_text(xs, [ImageStart, ..acc])
    ["[", ..xs] -> do_lex_inline_text(xs, [OpenSquareBracket, ..acc])
    ["]", ..xs] -> do_lex_inline_text(xs, [CloseSquareBracket, ..acc])
    ["(", ..xs] -> do_lex_inline_text(xs, [OpenBracket, ..acc])
    [")", ..xs] -> do_lex_inline_text(xs, [CloseBracket, ..acc])
    ["'", ..xs] -> do_lex_inline_text(xs, [SingleQuote, ..acc])
    ["\"", ..xs] -> do_lex_inline_text(xs, [DoubleQuote, ..acc])
    ["!", ..xs] -> do_lex_inline_text(xs, [Exclamation, ..acc])
    ["`", ..xs] -> do_lex_inline_text(xs, [Backtick, ..acc])
    ["~", ..xs] -> do_lex_inline_text(xs, [Tilde, ..acc])
    ["_", ..xs] -> do_lex_inline_text(xs, [Underscore, ..acc])
    ["*", ..xs] -> do_lex_inline_text(xs, [Asterisk, ..acc])
    ["\\", "\n", ..xs] -> do_lex_inline_text(xs, [HardLineBreak("\\\n"), ..acc])
    [" ", " ", "\n", ..xs] ->
      do_lex_inline_text(xs, [HardLineBreak("  \n"), ..acc])
    ["\n", ..xs] -> do_lex_inline_text(xs, [SoftLineBreak, ..acc])
    ["&", ..xs] ->
      case match_entity(xs) {
        Ok(#(rest, e, replacement)) ->
          do_lex_inline_text(rest, [Entity(e, replacement), ..acc])
        Error(_) ->
          case acc {
            [Word(t), ..rest] ->
              do_lex_inline_text(xs, [Word(t <> "&"), ..rest])
            _ -> do_lex_inline_text(xs, [Word("&"), ..acc])
          }
      }
    ["\\", g, ..xs] ->
      case list.contains(definitions.ascii_punctuation, g) {
        True -> do_lex_inline_text(xs, [Escaped(g), ..acc])
        False ->
          case acc {
            [Word(t), ..rest] ->
              do_lex_inline_text(xs, [Word(t <> "\\" <> g), ..rest])
            _ -> do_lex_inline_text(xs, [Word("\\" <> g), ..acc])
          }
      }
    [" " as w, ..xs] | ["\t" as w, ..xs] ->
      case acc {
        [WhiteSpace(ww), ..rest] ->
          do_lex_inline_text(xs, [WhiteSpace(ww <> w), ..rest])
        _ -> do_lex_inline_text(xs, [WhiteSpace(w), ..acc])
      }
    [x, ..xs] ->
      case acc {
        [Word(t), ..rest] -> do_lex_inline_text(xs, [Word(t <> x), ..rest])
        _ -> do_lex_inline_text(xs, [Word(x), ..acc])
      }
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
      case acc {
        [BacktickString(count), ..rest] ->
          do_parse_inline_wrappers([Backtick, ..ls], [
            BacktickString(count + 1),
            ..rest
          ])
        _ ->
          do_parse_inline_wrappers([Backtick, ..ls], [BacktickString(1), ..acc])
      }
    [Backtick, ..ls] -> {
      let acc = case acc {
        [BacktickString(count), ..rest] -> parse_code_span(count + 1, rest)
        _ -> parse_code_span(1, acc)
      }

      do_parse_inline_wrappers(ls, acc)
    }
    [Asterisk, Asterisk, ..ls] ->
      case acc {
        [AsteriskString(count), ..rest] ->
          do_parse_inline_wrappers([Asterisk, ..ls], [
            AsteriskString(count + 1),
            ..rest
          ])
        _ ->
          do_parse_inline_wrappers([Asterisk, ..ls], [AsteriskString(1), ..acc])
      }
    [Asterisk, ..ls] ->
      case acc {
        [AsteriskString(count), ..rest] ->
          do_parse_inline_wrappers(ls, [AsteriskString(count + 1), ..rest])
        _ -> do_parse_inline_wrappers(ls, [AsteriskString(1), ..acc])
      }
    [Underscore, Underscore, ..ls] ->
      case acc {
        [UnderscoreString(count), ..rest] ->
          do_parse_inline_wrappers([Underscore, ..ls], [
            UnderscoreString(count + 1),
            ..rest
          ])
        _ ->
          do_parse_inline_wrappers([Underscore, ..ls], [
            UnderscoreString(1),
            ..acc
          ])
      }
    [Underscore, ..ls] ->
      case acc {
        [UnderscoreString(count), ..rest] ->
          do_parse_inline_wrappers(ls, [UnderscoreString(count + 1), ..rest])
        _ -> do_parse_inline_wrappers(ls, [UnderscoreString(1), ..acc])
      }
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
    [ImageStart as v, ..ls]
    | [Exclamation as v, ..ls]
    | [SingleQuote as v, ..ls]
    | [DoubleQuote as v, ..ls]
    | [OpenBracket as v, ..ls]
    | [CloseBracket as v, ..ls]
    | [OpenSquareBracket as v, ..ls]
    | [CloseSquareBracket as v, ..ls]
    | [Entity(_, _) as v, ..ls]
    | [Escaped(_) as v, ..ls]
    | [LessThan as v, ..ls]
    | [HardLineBreak(_) as v, ..ls]
    | [SoftLineBreak as v, ..ls]
    | [WhiteSpace(_) as v, ..ls]
    | [Word(_) as v, ..ls] ->
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

fn parse_emphasis(final: InlineWrapper, previous: List(InlineWrapper)) {
  let #(wrapped, rest) =
    list.split_while(previous, fn(n) {
      case n, final {
        AsteriskString(l), AsteriskString(r)
        | UnderscoreString(l), UnderscoreString(r)
        ->
          !{
            l > 0
            && r > 0
            && { { l + r } % 3 != 0 || { l % 3 == 0 && r % 3 == 0 } }
          }
        _, _ -> True
      }
    })

  case final, rest {
    AsteriskString(r), [AsteriskString(l), ..rest] if l >= 2 && r >= 2 -> #(
      [AsteriskString(r - 2)],
      [
        StrongEmphasis(list.reverse(wrapped), ast.AsteriskEmphasisMarker),
        AsteriskString(l - 2),
        ..rest
      ],
    )
    AsteriskString(r), [AsteriskString(l), ..rest] -> #(
      [AsteriskString(r - 1)],
      [
        Emphasis(list.reverse(wrapped), ast.AsteriskEmphasisMarker),
        AsteriskString(l - 1),
        ..rest
      ],
    )
    UnderscoreString(r), [UnderscoreString(l), ..rest] if l >= 2 && r >= 2 -> #(
      [UnderscoreString(r - 2)],
      [
        StrongEmphasis(list.reverse(wrapped), ast.UnderscoreEmphasisMarker),
        UnderscoreString(l - 2),
        ..rest
      ],
    )
    UnderscoreString(r), [UnderscoreString(l), ..rest] -> #(
      [UnderscoreString(r - 1)],
      [
        Emphasis(list.reverse(wrapped), ast.UnderscoreEmphasisMarker),
        UnderscoreString(l - 1),
        ..rest
      ],
    )
    _, _ -> #([], [final, ..previous])
  }
}

fn parse_link_title(
  contents: List(InlineWrapper),
  href: String,
  ls: List(InlineWrapper),
) -> Result(#(InlineWrapper, List(InlineWrapper)), Nil) {
  let is_not = fn(x) { fn(y) { x != y } }
  case ls {
    [LexedElement(SingleQuote), ..ls] ->
      case list.split_while(ls, is_not(LexedElement(SingleQuote))) {
        #(
          title,
          [_, LexedElement(WhiteSpace(_)), LexedElement(CloseBracket), ..ls],
        )
        | #(title, [_, LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriLink(contents, href, Some(list_to_string(title))), ls))
        _ -> Error(Nil)
      }
    [LexedElement(DoubleQuote), ..ls] ->
      case list.split_while(ls, is_not(LexedElement(DoubleQuote))) {
        #(
          title,
          [_, LexedElement(WhiteSpace(_)), LexedElement(CloseBracket), ..ls],
        )
        | #(title, [_, LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriLink(contents, href, Some(list_to_string(title))), ls))
        _ -> Error(Nil)
      }
    [LexedElement(OpenBracket), ..ls] ->
      case list.split_while(ls, is_not(LexedElement(CloseBracket))) {
        #(
          title,
          [_, LexedElement(WhiteSpace(_)), LexedElement(CloseBracket), ..ls],
        )
        | #(title, [_, LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriLink(contents, href, Some(list_to_string(title))), ls))
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn is_not_end_of_href(v: InlineWrapper) -> Bool {
  case v {
    LexedElement(GreaterThan)
    | LexedElement(SoftLineBreak)
    | LexedElement(HardLineBreak(_)) -> False
    _ -> True
  }
}

fn parse_link(
  contents: List(InlineWrapper),
  ls: List(InlineWrapper),
) -> Result(#(InlineWrapper, List(InlineWrapper)), Nil) {
  case ls {
    [
      LexedElement(OpenBracket),
      LexedElement(LessThan),
      LexedElement(GreaterThan),
      LexedElement(CloseBracket),
      ..ls
    ]
    | [LexedElement(OpenBracket), LexedElement(CloseBracket), ..ls] ->
      Ok(#(UriLink(contents, "", None), ls))
    [
      LexedElement(OpenBracket),
      LexedElement(Word(href)),
      LexedElement(CloseBracket),
      ..ls
    ] -> Ok(#(UriLink(contents, href, None), ls))
    [
      LexedElement(OpenBracket),
      LexedElement(Word(href)),
      LexedElement(WhiteSpace(_)),
      ..ls
    ] -> parse_link_title(contents, href, ls)
    [LexedElement(OpenBracket), LexedElement(LessThan), ..ls] ->
      case list.split_while(ls, is_not_end_of_href) {
        #(href, [LexedElement(GreaterThan), LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriLink(contents, list_to_string(href), None), ls))
        #(href, [LexedElement(GreaterThan), LexedElement(WhiteSpace(_)), ..ls]) ->
          parse_link_title(contents, list_to_string(href), ls)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn parse_image_title(
  alt: String,
  href: String,
  ls: List(InlineWrapper),
) -> Result(#(InlineWrapper, List(InlineWrapper)), Nil) {
  let is_not = fn(x) { fn(y) { x != y } }
  case ls {
    [LexedElement(SingleQuote), ..ls] ->
      case list.split_while(ls, is_not(LexedElement(SingleQuote))) {
        #(
          title,
          [_, LexedElement(WhiteSpace(_)), LexedElement(CloseBracket), ..ls],
        )
        | #(title, [_, LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriImage(alt, href, Some(list_to_string(title))), ls))
        _ -> Error(Nil)
      }
    [LexedElement(DoubleQuote), ..ls] ->
      case list.split_while(ls, is_not(LexedElement(DoubleQuote))) {
        #(
          title,
          [_, LexedElement(WhiteSpace(_)), LexedElement(CloseBracket), ..ls],
        )
        | #(title, [_, LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriImage(alt, href, Some(list_to_string(title))), ls))
        _ -> Error(Nil)
      }
    [LexedElement(OpenBracket), ..ls] ->
      case list.split_while(ls, is_not(LexedElement(CloseBracket))) {
        #(
          title,
          [_, LexedElement(WhiteSpace(_)), LexedElement(CloseBracket), ..ls],
        )
        | #(title, [_, LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriImage(alt, href, Some(list_to_string(title))), ls))
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn parse_image(
  alt: String,
  ls: List(InlineWrapper),
) -> Result(#(InlineWrapper, List(InlineWrapper)), Nil) {
  case ls {
    [
      LexedElement(OpenBracket),
      LexedElement(LessThan),
      LexedElement(GreaterThan),
      LexedElement(CloseBracket),
      ..ls
    ]
    | [LexedElement(OpenBracket), LexedElement(CloseBracket), ..ls] ->
      Ok(#(UriImage(alt, "", None), ls))
    [
      LexedElement(OpenBracket),
      LexedElement(Word(href)),
      LexedElement(CloseBracket),
      ..ls
    ] -> Ok(#(UriImage(alt, href, None), ls))
    [
      LexedElement(OpenBracket),
      LexedElement(Word(href)),
      LexedElement(WhiteSpace(_)),
      ..ls
    ] -> parse_image_title(alt, href, ls)
    [LexedElement(OpenBracket), LexedElement(LessThan), ..ls] ->
      case list.split_while(ls, is_not_end_of_href) {
        #(href, [LexedElement(GreaterThan), LexedElement(CloseBracket), ..ls]) ->
          Ok(#(UriImage(alt, list_to_string(href), None), ls))
        #(href, [LexedElement(GreaterThan), LexedElement(WhiteSpace(_)), ..ls]) ->
          parse_image_title(alt, list_to_string(href), ls)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn is_not_link_or_image_start(v: InlineWrapper) -> Bool {
  case v {
    LexedElement(ImageStart) -> False
    LexedElement(OpenSquareBracket) -> False
    LexedElement(CloseSquareBracket) -> False
    _ -> True
  }
}

fn do_late_binding(wrapped: List(InlineWrapper), acc: List(InlineWrapper)) {
  case wrapped {
    [] -> acc |> list.reverse
    [LexedElement(CloseSquareBracket), ..ls] -> {
      case list.split_while(acc, is_not_link_or_image_start) {
        #(to_wrap, [LexedElement(OpenSquareBracket), ..rest]) -> {
          case parse_link(to_wrap |> list.reverse, ls) {
            Ok(#(wrapped, ls)) -> do_late_binding(ls, [wrapped, ..rest])
            Error(_) ->
              do_late_binding(ls, [LexedElement(CloseSquareBracket), ..acc])
          }
        }
        #(to_wrap, [LexedElement(ImageStart), ..rest]) -> {
          case parse_image(to_wrap |> list.reverse |> list_to_text, ls) {
            Ok(#(wrapped, ls)) -> do_late_binding(ls, [wrapped, ..rest])
            Error(_) ->
              do_late_binding(ls, [LexedElement(CloseSquareBracket), ..acc])
          }
        }
        _ -> do_late_binding(ls, [LexedElement(CloseSquareBracket), ..acc])
      }
    }
    [TildeString(count), ..xs] -> {
      case count <= 2 {
        True -> do_late_binding(xs, parse_strikethrough(count, acc))
        False -> do_late_binding(xs, [TildeString(count), ..acc])
      }
    }
    [AsteriskString(n) as str, ..xs] | [UnderscoreString(n) as str, ..xs]
      if n > 0
    -> {
      let #(prefix, acc) = parse_emphasis(str, acc)
      do_late_binding(list.concat([prefix, xs]), acc)
    }
    [x, ..xs] -> do_late_binding(xs, [x, ..acc])
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
    [UriImage(contents, href, title), ..ws] ->
      do_parse_inline_ast(ws, [ast.Image(contents, title, href), ..acc])
    [UriLink(contents, href, title), ..ws] ->
      do_parse_inline_ast(ws, [
        ast.Link(do_parse_inline_ast(contents, []), title, href),
        ..acc
      ])
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
    [AsteriskString(count), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(string.repeat("*", count)), ..acc])
    [UnderscoreString(count), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(string.repeat("_", count)), ..acc])
    [LexedElement(Escaped(s)), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(s), ..acc])
    [LexedElement(Entity(replacement: r, ..)), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(r), ..acc])
    [LexedElement(SoftLineBreak), ..ws] ->
      do_parse_inline_ast(ws, [ast.SoftLineBreak, ..acc])
    [LexedElement(HardLineBreak(_)), ..ws] ->
      do_parse_inline_ast(ws, [ast.HardLineBreak, ..acc])
    [LexedElement(OpenBracket), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("("), ..acc])
    [LexedElement(CloseBracket), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(")"), ..acc])
    [LexedElement(ImageStart), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("!["), ..acc])
    [LexedElement(OpenSquareBracket), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("["), ..acc])
    [LexedElement(CloseSquareBracket), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("]"), ..acc])
    [LexedElement(SingleQuote), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("'"), ..acc])
    [LexedElement(DoubleQuote), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("\""), ..acc])
    [LexedElement(Exclamation), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("!"), ..acc])
    [LexedElement(Asterisk), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("*"), ..acc])
    [LexedElement(Underscore), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("_"), ..acc])
    [LexedElement(Backtick), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("`"), ..acc])
    [LexedElement(Tilde), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("~"), ..acc])
    [LexedElement(GreaterThan), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(">"), ..acc])
    [LexedElement(LessThan), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText("<"), ..acc])
    [LexedElement(WhiteSpace(t)), ..ws] ->
      do_parse_inline_ast(ws, [ast.PlainText(t), ..acc])
    [LexedElement(Word(t)), ..ws] ->
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

fn do_finalise_plain_text(
  ast: List(ast.InlineNode),
  acc: List(ast.InlineNode),
  trim_ends: Bool,
) {
  case ast, acc {
    [], [ast.PlainText(y), ..ys] if trim_ends ->
      case trim_right(y) {
        "" -> list.reverse(ys)
        t -> [ast.PlainText(t), ..ys] |> list.reverse
      }
    [], _ -> acc |> list.reverse
    [ast.PlainText(""), ..xs], _ -> do_finalise_plain_text(xs, acc, trim_ends)
    [ast.StrongEmphasis(content, marker), ..xs], _ ->
      do_finalise_plain_text(
        xs,
        [
          ast.StrongEmphasis(do_finalise_plain_text(content, [], False), marker),
          ..acc
        ],
        trim_ends,
      )
    [ast.Emphasis(content, marker), ..xs], _ ->
      do_finalise_plain_text(
        xs,
        [
          ast.Emphasis(do_finalise_plain_text(content, [], trim_ends), marker),
          ..acc
        ],
        trim_ends,
      )
    [ast.StrikeThrough(content), ..xs], _ ->
      do_finalise_plain_text(
        xs,
        [
          ast.StrikeThrough(do_finalise_plain_text(content, [], trim_ends)),
          ..acc
        ],
        trim_ends,
      )
    [ast.PlainText(x), ..xs], [ast.PlainText(y), ..ys] ->
      do_finalise_plain_text(xs, [ast.PlainText(y <> x), ..ys], trim_ends)
    [ast.PlainText(x), ..xs], []
    | [ast.PlainText(x), ..xs], [ast.HardLineBreak, ..]
    | [ast.PlainText(x), ..xs], [ast.SoftLineBreak, ..]
      if trim_ends
    ->
      case trim_left(x) {
        "" -> do_finalise_plain_text(xs, acc, trim_ends)
        t -> do_finalise_plain_text(xs, [ast.PlainText(t), ..acc], trim_ends)
      }
    [ast.HardLineBreak as x, ..xs], [ast.PlainText(y), ..ys]
    | [ast.SoftLineBreak as x, ..xs], [ast.PlainText(y), ..ys]
      if trim_ends
    ->
      case trim_right(y) {
        "" -> do_finalise_plain_text(xs, [x, ..ys], trim_ends)
        t -> do_finalise_plain_text(xs, [x, ast.PlainText(t), ..ys], trim_ends)
      }
    [x, ..xs], _ -> do_finalise_plain_text(xs, [x, ..acc], trim_ends)
  }
}

pub fn parse_text(text: String) -> List(ast.InlineNode) {
  text
  |> string.to_graphemes
  |> do_lex_inline_text([])
  |> do_parse_inline_wrappers([])
  |> do_late_binding([])
  |> do_parse_inline_ast([])
  |> do_finalise_plain_text([], True)
}
