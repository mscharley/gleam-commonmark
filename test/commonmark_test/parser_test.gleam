import commonmark
import commonmark/ast
import commonmark/internal/parser/helpers
import gleam/dict
import startest/expect

pub fn null_byte_test() {
  "Hello\u{00}&#x0;&#0; world!\n"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [ast.Paragraph([ast.PlainText("Hello\u{fffd}\u{fffd}\u{fffd} world!")])],
    dict.new(),
  ))
}

pub fn hello_world_test() {
  "Hello world!\n"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [ast.Paragraph([ast.PlainText("Hello world!")])],
    dict.new(),
  ))
}

pub fn paragraphs_test() {
  "Hello world!\n\nGoodbye, world!"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [
      ast.Paragraph([ast.PlainText("Hello world!")]),
      ast.Paragraph([ast.PlainText("Goodbye, world!")]),
    ],
    dict.new(),
  ))
}

pub fn windows_test() {
  "Hello Windows!\r\n\r\nHello OS X!\r\rGoodbye folks!\n"
  |> commonmark.parse
  |> expect.to_equal(ast.Document(
    [
      ast.Paragraph([ast.PlainText("Hello Windows!")]),
      ast.Paragraph([ast.PlainText("Hello OS X!")]),
      ast.Paragraph([ast.PlainText("Goodbye folks!")]),
    ],
    dict.new(),
  ))
}

pub fn trim_indent_short_test() {
  "foo" |> helpers.trim_indent(4) |> expect.to_equal("foo")
}

pub fn trim_indent_long_test() {
  "      foo" |> helpers.trim_indent(4) |> expect.to_equal("  foo")
}

pub fn trim_indent_tab1_test() {
  "   \t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_tab2_test() {
  "  \t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_tab3_test() {
  " \t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_tab4_test() {
  "\t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
}

pub fn trim_indent_midtab_test() {
  "\t\t\tfoo" |> helpers.trim_indent(6) |> expect.to_equal("  \tfoo")
}
