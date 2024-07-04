import commonmark
import commonmark/ast
import gleam/dict
import startest.{describe, it}
import startest/expect

pub fn gfm_alert_tests() {
  describe("Alerts", [
    it("allows notes", fn() {
      "> [!NOTE]\n> Highlights information that users should take into account, even when skimming."
      |> commonmark.parse
      |> expect.to_equal(ast.Document(
        [
          ast.AlertBlock(level: ast.NoteAlert, contents: [
            ast.Paragraph([
              ast.PlainText(
                "Highlights information that users should take into account, even when skimming.",
              ),
            ]),
          ]),
        ],
        dict.new(),
      ))
    }),
    it("allows tips", fn() {
      "> [!TIP]\n> Optional information to help a user be more successful."
      |> commonmark.parse
      |> expect.to_equal(ast.Document(
        [
          ast.AlertBlock(level: ast.TipAlert, contents: [
            ast.Paragraph([
              ast.PlainText(
                "Optional information to help a user be more successful.",
              ),
            ]),
          ]),
        ],
        dict.new(),
      ))
    }),
    it("allows important", fn() {
      "> [!IMPORTANT]\n> Crucial information necessary for users to succeed."
      |> commonmark.parse
      |> expect.to_equal(ast.Document(
        [
          ast.AlertBlock(level: ast.ImportantAlert, contents: [
            ast.Paragraph([
              ast.PlainText(
                "Crucial information necessary for users to succeed.",
              ),
            ]),
          ]),
        ],
        dict.new(),
      ))
    }),
    it("allows warning", fn() {
      "> [!WARNING]\n> Critical content demanding immediate user attention due to potential risks."
      |> commonmark.parse
      |> expect.to_equal(ast.Document(
        [
          ast.AlertBlock(level: ast.WarningAlert, contents: [
            ast.Paragraph([
              ast.PlainText(
                "Critical content demanding immediate user attention due to potential risks.",
              ),
            ]),
          ]),
        ],
        dict.new(),
      ))
    }),
    it("allows caution", fn() {
      "> [!CAUTION]\n> Negative potential consequences of an action."
      |> commonmark.parse
      |> expect.to_equal(ast.Document(
        [
          ast.AlertBlock(level: ast.CautionAlert, contents: [
            ast.Paragraph([
              ast.PlainText("Negative potential consequences of an action."),
            ]),
          ]),
        ],
        dict.new(),
      ))
    }),
    it("disallows other types", fn() {
      "> [!WIBBLE]\n> This is wobble."
      |> commonmark.parse
      |> expect.to_equal(ast.Document(
        [
          ast.BlockQuote([
            ast.Paragraph([
              ast.PlainText("[!WIBBLE]"),
              ast.SoftLineBreak,
              ast.PlainText("This is wobble."),
            ]),
          ]),
        ],
        dict.new(),
      ))
    }),
  ])
}
