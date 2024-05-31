import commonmark
import commonmark/ast
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
