//// TODO: This file needs to be code generated based on the HTML5 spec.

pub fn match_html_entity(
  input: List(String),
) -> Result(#(List(String), String), Nil) {
  // The spec reference the HTML5 spec for the definitive list of these:
  // https://html.spec.whatwg.org/entities.json
  case input {
    ["A", "E", "l", "i", "g", ";", ..rest] -> Ok(#(rest, "Æ"))
    ["a", "m", "p", ";", ..rest] -> Ok(#(rest, "&"))
    [
      "C",
      "l",
      "o",
      "c",
      "k",
      "w",
      "i",
      "s",
      "e",
      "C",
      "o",
      "n",
      "t",
      "o",
      "u",
      "r",
      "I",
      "n",
      "t",
      "e",
      "g",
      "r",
      "a",
      "l",
      ";",
      ..rest
    ] -> Ok(#(rest, "∲"))
    ["c", "o", "p", "y", ";", ..rest] -> Ok(#(rest, "©"))
    ["D", "c", "a", "r", "o", "n", ";", ..rest] -> Ok(#(rest, "Ď"))
    [
      "D",
      "i",
      "f",
      "f",
      "e",
      "r",
      "e",
      "n",
      "t",
      "i",
      "a",
      "l",
      "D",
      ";",
      ..rest
    ] -> Ok(#(rest, "ⅆ"))
    ["f", "r", "a", "c", "3", "4", ";", ..rest] -> Ok(#(rest, "¾"))
    ["H", "i", "l", "b", "e", "r", "t", "S", "p", "a", "c", "e", ";", ..rest] ->
      Ok(#(rest, "ℋ"))
    ["n", "b", "s", "p", ";", ..rest] -> Ok(#(rest, "\u{A0}"))
    ["n", "g", "E", ";", ..rest] -> Ok(#(rest, "≧̸"))
    ["q", "u", "o", "t", ";", ..rest] -> Ok(#(rest, "\""))
    _ -> Error(Nil)
  }
}
