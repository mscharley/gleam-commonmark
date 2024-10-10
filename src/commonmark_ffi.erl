% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this
% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(commonmark_ffi).
-compile([no_auto_import]).

-export([get_target_regexes/0]).

get_target_regexes() ->
	{
		<<"^( {0,3})(([~`])\\g{3}{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$"/utf8>>,
		<<"^ {0,3}(?:([-*_]))(?:[ \t]*\\g{1}){2,}[ \t]*$"/utf8>>
	}.
