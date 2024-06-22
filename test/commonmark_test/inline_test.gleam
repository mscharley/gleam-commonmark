import commonmark/ast
import commonmark/internal/parser/inline
import startest/expect

pub fn basic_emphasis_test() {
  "a *b* c"
  |> inline.parse_text
  |> expect.to_equal([
    ast.PlainText("a "),
    ast.Emphasis([ast.PlainText("b")], ast.AsteriskEmphasisMarker),
    ast.PlainText(" c"),
  ])
}

pub fn handle_partial_emphasis_test() {
  "*input to*** test**"
  |> inline.parse_text
  |> expect.to_equal([
    ast.Emphasis([ast.PlainText("input to")], ast.AsteriskEmphasisMarker),
    ast.StrongEmphasis([ast.PlainText(" test")], ast.AsteriskEmphasisMarker),
  ])
}
