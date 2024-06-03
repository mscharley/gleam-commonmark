import commonmark
import commonmark/ast
import commonmark/internal/parser
import gleam/dict
import startest/expect

pub fn hello_world_test() {
  "Hello world!\n"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [ast.Paragraph([ast.Text("Hello world!")])],
    dict.new(),
  ))
}

pub fn paragraphs_test() {
  "Hello world!\n\nGoodbye, world!"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [
      ast.Paragraph([ast.Text("Hello world!")]),
      ast.Paragraph([ast.Text("Goodbye, world!")]),
    ],
    dict.new(),
  ))
}

pub fn windows_test() {
  "Hello Windows!\r\n\r\nHello OS X!\r\rGoodbye folks!\n"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [
      ast.Paragraph([ast.Text("Hello Windows!")]),
      ast.Paragraph([ast.Text("Hello OS X!")]),
      ast.Paragraph([ast.Text("Goodbye folks!")]),
    ],
    dict.new(),
  ))
}

pub fn trim_indent_short_test() {
  "foo" |> parser.trim_indent(4) |> expect.to_equal("foo")
}

pub fn trim_indent_long_test() {
  "      foo" |> parser.trim_indent(4) |> expect.to_equal("  foo")
}

pub fn trim_indent_tab1_test() {
  "   \t foo" |> parser.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_tab2_test() {
  "  \t foo" |> parser.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_tab3_test() {
  " \t foo" |> parser.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_tab4_test() {
  "\t foo" |> parser.trim_indent(4) |> expect.to_equal(" foo")
}
