import commonmark
import commonmark/ast
import commonmark/internal/parser/helpers
import gleam/dict
import startest.{describe, it}
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

pub fn trim_indent_tests() {
  describe("trim_indent", [
    it("overtrims", fn() {
      "foo" |> helpers.trim_indent(4) |> expect.to_equal("foo")
    }),
    it("undertrims", fn() {
      "      foo" |> helpers.trim_indent(4) |> expect.to_equal("  foo")
    }),
    it("tabstop 1", fn() {
      "   \t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
    }),
    it("tabstop 2", fn() {
      "  \t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
    }),
    it("tabstop 3", fn() {
      " \t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
    }),
    it("tabstop 4", fn() {
      "\t foo" |> helpers.trim_indent(4) |> expect.to_equal(" foo")
    }),
    it("trims partial tabs", fn() {
      "\t\t\tfoo" |> helpers.trim_indent(6) |> expect.to_equal("  \tfoo")
    }),
  ])
}
