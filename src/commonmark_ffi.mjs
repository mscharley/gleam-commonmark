import { ParserRegexes } from "./commonmark/internal/definitions.mjs";
import * as $regex from "../gleam_stdlib/gleam/regex.mjs";
import {
	makeError,
} from "./gleam.mjs";

export function get_target_regexes() {
	return [
		"^( {0,3})(([~`])\\3{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$",
		"^ {0,3}(?:([-*_]))(?:[ \t]*\\1){2,}[ \t]*$",
	];
}

