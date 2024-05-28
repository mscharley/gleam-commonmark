import commonmark
import commonmark/ast
import commonmark_spec
import gleam/io
import gleeunit
import gleeunit/should

pub fn main() {
  commonmark_spec.main()

  io.println("GleeUnit tests")
  io.println("--------------")
  gleeunit.main()
}

pub fn hello_world_test() {
  "Hello world!\n"
  |> commonmark.parse
  |> should.equal(ast.Document([ast.Paragraph([ast.Text("Hello world!")])]))
}

pub fn paragraphs_test() {
  "Hello world!\n\nGoodbye, world!"
  |> commonmark.parse
  |> should.equal(
    ast.Document([
      ast.Paragraph([ast.Text("Hello world!")]),
      ast.Paragraph([ast.Text("Goodbye, world!")]),
    ]),
  )
}

pub fn windows_test() {
  "Hello Windows!\r\n\r\nHello OS X!\r\rGoodbye folks!\n"
  |> commonmark.parse
  |> should.equal(
    ast.Document([
      ast.Paragraph([ast.Text("Hello Windows!")]),
      ast.Paragraph([ast.Text("Hello OS X!")]),
      ast.Paragraph([ast.Text("Goodbye folks!")]),
    ]),
  )
}
