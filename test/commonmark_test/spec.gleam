// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark_test/helpers
import gleam/list
import gleam/option.{None}
import startest

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
  31, 344, 475, 476, 477, 491,
]

const ignore_roundtrip = [
  39, 81, 82, 95, 109, 123, 124, 127, 134, 228, 229, 230, 232, 244, 281, 283,
  315, 320, 321, 329, 330, 331, 339, 489, 492, 499, 509,
]

/// This is a list of expected failures
const blacklist = [
  5, 6, 7, 9, 21, 22, 23, 24, 32, 33, 34, 40, 55, 93, 138, 145, 192, 193, 194,
  195, 196, 198, 200, 201, 202, 203, 204, 205, 206, 207, 208, 210, 214, 215, 216,
  217, 218, 249, 273, 274, 278, 279, 280, 282, 290, 291, 292, 293, 294, 296, 300,
  303, 305, 307, 308, 309, 312, 317, 318, 319, 323, 325, 326, 338, 346, 347, 351,
  352, 353, 354, 358, 359, 360, 361, 362, 363, 366, 367, 368, 369, 371, 372, 373,
  374, 375, 376, 379, 380, 383, 384, 385, 386, 387, 388, 389, 391, 392, 397, 398,
  400, 401, 402, 407, 408, 409, 418, 419, 425, 426, 427, 432, 442, 443, 454, 455,
  470, 471, 472, 473, 474, 494, 495, 496, 498, 500, 503, 504, 506, 507, 510, 512,
  518, 519, 520, 521, 522, 524, 526, 527, 528, 529, 530, 531, 532, 533, 534, 535,
  536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 549, 550, 553, 554, 555, 556,
  557, 558, 559, 560, 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571, 573,
  576, 577, 582, 583, 584, 585, 586, 587, 588, 589, 591, 592, 593, 595, 603, 642,
  643,
]

/// Run only this test
const only = None

pub fn commonmark_spec_tests() {
  let spec = helpers.parse_json_spec(spec_file)

  startest.describe(
    "CommonMark spec",
    helpers.run_spec(
      spec
        |> list.filter(fn(s) { !list.contains(html_tests, s.example) }),
      blacklist,
      invalid_tests,
      ignore_roundtrip,
      only,
    ),
  )
}
