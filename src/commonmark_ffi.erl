-module(commonmark_ffi).
-compile([no_auto_import]).

-export([get_target_regexes/0]).

get_target_regexes() ->
	{
		<<"^( {0,3})(([~`])\\g{3}{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$"/utf8>>,
		<<"^ {0,3}(?:([-*_]))(?:[ \t]*\\g{1}){2,}[ \t]*$"/utf8>>
	}.
