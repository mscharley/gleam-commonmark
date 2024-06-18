@target(erlang)
import commonmark
@target(erlang)
import glychee/benchmark
@target(erlang)
import glychee/configuration
@target(erlang)
import simplifile

@target(erlang)
pub fn main() {
  // Configuration is optional
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  let assert Ok(readme) = simplifile.read("./README.md")

  // Run the benchmarks
  benchmark.run(
    [
      benchmark.Function(label: "parse only", callable: fn(test_data) {
        fn() {
          test_data |> commonmark.parse
          Nil
        }
      }),
      benchmark.Function(label: "render", callable: fn(test_data) {
        fn() {
          test_data |> commonmark.render_to_html
          Nil
        }
      }),
    ],
    [benchmark.Data(label: "README", data: readme)],
  )
}
