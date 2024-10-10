// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

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

