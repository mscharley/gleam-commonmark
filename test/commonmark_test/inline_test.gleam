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
