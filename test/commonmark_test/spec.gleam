import commonmark
import gleam/dict
import gleam/dynamic.{field, int as int_field, list, string}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None}
import simplifile
import startest.{describe, it, xit}
import startest/expect

const spec_file = "./test/commonmark_test/spec-0.31.2.json"

/// A list of tests involving invalid markdown that won't parse in strict mode
const invalid_tests = []

const html_tests = [
  // HTML blocks
  148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163,
  164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179,
  180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,
  // Raw HTML
  613, 614, 615, 616, 617, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628,
  629, 630, 631, 632,
  // Other tests that rely on inline HTML
]

/// This is a list of expected failures
const blacklist = [
  5, 6, 7, 9, 15, 17, 21, 22, 23, 24, 31, 32, 33, 34, 35, 37, 40, 56, 61, 66, 80,
  81, 82, 93, 121, 138, 145, 192, 193, 194, 195, 196, 198, 200, 201, 202, 203,
  204, 205, 206, 207, 208, 210, 214, 215, 216, 217, 218, 249, 273, 274, 278, 279,
  280, 282, 290, 291, 292, 293, 294, 296, 298, 299, 300, 303, 305, 307, 308, 309,
  312, 317, 318, 319, 323, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335,
  336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 349, 350, 355, 356,
  357, 364, 369, 370, 373, 376, 377, 378, 381, 382, 389, 390, 393, 394, 395, 396,
  399, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416,
  417, 418, 419, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 437,
  438, 440, 441, 442, 443, 444, 445, 446, 447, 449, 450, 452, 453, 454, 455, 456,
  457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 470, 471, 472,
  473, 474, 475, 476, 477, 478, 479, 482, 483, 484, 485, 486, 487, 489, 491, 492,
  493, 494, 495, 496, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 509, 510,
  512, 514, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 525, 526, 527, 528,
  529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544,
  545, 549, 550, 553, 554, 555, 556, 557, 558, 559, 560, 561, 562, 563, 564, 565,
  566, 567, 568, 569, 570, 571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581,
  582, 583, 584, 585, 586, 587, 588, 589, 591, 592, 593, 595, 603, 606, 638, 639,
  640, 641, 642, 643,
]

/// Run only this test
const only = None

type Test {
  Test(example: Int, markdown: String, html: String, section: String)
}

pub fn commonmark_spec_tests() {
  let spec_decoder =
    list(dynamic.decode4(
      Test,
      field("example", of: int_field),
      field("markdown", of: string),
      field("html", of: string),
      field("section", of: string),
    ))

  let assert Ok(spec_json) = spec_file |> simplifile.read
  let assert Ok(specs) = spec_json |> json.decode(spec_decoder)

  describe(
    "CommonMark spec",
    specs
      |> list.filter(fn(s) { !list.contains(html_tests, s.example) })
      |> list.group(fn(s) { s.section })
      |> dict.to_list
      |> list.map(run_section),
  )
}

fn run_section(ts: #(String, List(Test))) {
  let #(title, reversed_tests) = ts
  let tests = list.reverse(reversed_tests)

  describe(
    title,
    list.concat([
      list.map(tests, run_safe_test),
      list.map(
        tests |> list.filter(fn(t) { !list.contains(invalid_tests, t) }),
        run_strict_test,
      ),
    ]),
  )
}

fn run_safe_test(t: Test) {
  let allowed =
    only
    |> option.map(fn(n) { n == t.example })
    |> option.lazy_unwrap(fn() { !list.contains(blacklist, t.example) })

  let f = case allowed {
    True -> it
    False -> xit
  }

  f("Example " <> int.to_string(t.example), fn() {
    t.markdown
    |> commonmark.render_to_html
    |> expect.to_equal(t.html)
  })
}

fn run_strict_test(t: Test) {
  let allowed =
    only
    |> option.map(fn(n) { n == t.example })
    |> option.lazy_unwrap(fn() { !list.contains(blacklist, t.example) })

  let f = case allowed {
    True -> it
    False -> xit
  }

  f("Example " <> int.to_string(t.example) <> " (strict)", fn() {
    t.markdown
    |> commonmark.render_to_html_strict
    |> expect.to_equal(Ok(t.html))
  })
}
