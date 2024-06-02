import startest

import startest/config.{Config}
import startest/reporters/dot

pub fn main() {
  Config(..startest.default_config(), reporters: [dot.new()])
  // |> config.with_reporters([dot.new()])
  |> startest.run
}
