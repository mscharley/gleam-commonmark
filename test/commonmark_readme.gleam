import birdie
import commonmark
import pprint
import simplifile

pub fn readme_test() {
  let assert Ok(markdown) = simplifile.read("./README.md")

  markdown
  |> commonmark.parse
  |> pprint.format
  |> birdie.snap(title: "CommonMark readme")
}
