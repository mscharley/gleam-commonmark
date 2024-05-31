import startest
import startest/config
import startest/reporters/dot

pub fn main() {
  startest.default_config()
  |> config.with_reporters([dot.new()])
  |> startest.run
}
