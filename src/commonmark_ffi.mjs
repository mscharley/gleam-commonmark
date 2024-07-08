import { ParserRegexes } from "./commonmark/internal/definitions.mjs";
import * as $regex from "../gleam_stdlib/gleam/regex.mjs";
import {
	makeError,
} from "./gleam.mjs";

function get_regex(re_string, line) {
	let $ = $regex.from_string(re_string);
	if (!$.isOk()) {
		throw makeError(
			"assignment_no_match",
			"commonmark/internal/parser/block",
			line,
			"get_platform_regexes",
			"Assignment pattern did not match",
			{ value: $ }
		)
	}
	return $[0];
}

const Atx_header_regex = get_regex("^ {0,3}(#{1,6})([ \t]+.*?)?(?:(?<=[ \t])#*)?[ \t]*$", 21);
const Block_quote_regex = get_regex("^ {0,3}> ?(.*)$", 22);
const Fenced_code_start_regex = get_regex( "^( {0,3})(([~`])\\3{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$", 23);
const Hr_regex = get_regex("^ {0,3}(?:([-*_]))(?:[ \t]*\\1){2,}[ \t]*$", 24);
const Indented_code_regex = get_regex("^(?: {0,3}\t|    )|^[ \t]*$", 25);
const Ol_regex = get_regex("^( {0,3})([0-9]{1,9})([.)])(?:( {1,4})(.*))?$", 26);
const Setext_header_regex = get_regex("^ {0,3}([-=])+[ \t]*$", 27);
const Ul_regex = get_regex("^( {0,3})([-*+])(?:( {1,4})(.*))?$", 28);

export function get_static_regexes() {
	return new ParserRegexes(
		Atx_header_regex,
		Block_quote_regex,
		Fenced_code_start_regex,
		Hr_regex,
		Indented_code_regex,
		Ol_regex,
		Setext_header_regex,
		Ul_regex,
	);
}

