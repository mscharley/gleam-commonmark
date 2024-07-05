import commonmark.{parse}
import commonmark/html.{render_to_html}
import glychee/benchmark
import glychee/configuration
import simplifile

pub fn main() {
  // Configuration is optional
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  let assert Ok(readme) = simplifile.read("../README.md")

  // Run the benchmarks
  benchmark.run(
    [
      benchmark.Function(label: "parse only", callable: fn(test_data) {
        fn() {
          test_data |> parse
          Nil
        }
      }),
      benchmark.Function(label: "render", callable: fn(test_data) {
        fn() {
          test_data |> render_to_html
          Nil
        }
      }),
    ],
    [benchmark.Data(label: "README", data: readme)],
  )
}
