import commonmark
import commonmark/ast
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn hello_world_test() {
  "Hello world!\n"
  |> commonmark.parse
  |> should.equal(ast.Document([ast.Paragraph("Hello world!")]))
}

pub fn paragraphs_test() {
  "Hello world!\n\nGoodbye, world!"
  |> commonmark.parse
  |> should.equal(
    ast.Document([
      ast.Paragraph("Hello world!"),
      ast.Paragraph("Goodbye, world!"),
    ]),
  )
}
