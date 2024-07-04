import * as $regex from "../gleam_stdlib/gleam/regex.mjs";
import {
  makeError,
} from "./gleam.mjs";

const hr_regex_string = "^ {0,3}(?:([-*_]))(?:[ \t]*\\1){2,}[ \t]*$";

const fenced_code_start_regex_string = "^( {0,3})(([~`])\\3{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$";

export function get_platform_regexes() {
  let $ = $regex.from_string(hr_regex_string);
  if (!$.isOk()) {
    throw makeError(
      "assignment_no_match",
      "commonmark/internal/parser/block",
      152,
      "get_platform_regexes",
      "Assignment pattern did not match",
      { value: $ }
    )
  }
  let hr_regex = $[0];
  let $1 = $regex.from_string(fenced_code_start_regex_string);
  if (!$1.isOk()) {
    throw makeError(
      "assignment_no_match",
      "commonmark/internal/parser/block",
      153,
      "get_platform_regexes",
      "Assignment pattern did not match",
      { value: $1 }
    )
  }
  let fenced_code_start_regex = $1[0];
  return [hr_regex, fenced_code_start_regex];
}

