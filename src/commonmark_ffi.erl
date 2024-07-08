-module(commonmark_ffi).
-compile([no_auto_import]).

-export([get_static_regexes/0]).

-spec get_regex(bitstring(), integer()) -> gleam@regex:regex().
get_regex(String, Line) -> 
	_assert_subject = gleam@regex:from_string(String),
	{ok, Re} = case _assert_subject of
		{ok, _} -> _assert_subject;
		_assert_fail ->
			erlang:error(#{gleam_error => let_assert,
			             message => <<"Assertion pattern match failed"/utf8>>,
			             value => _assert_fail,
			             module => <<"commonmark_ffi"/utf8>>,
			             function => <<"get_static_regexes"/utf8>>,
			             line => Line})
	end,
	Re.

-spec get_static_regexes() -> commonmark@internal@definitions:parser_regexes().
get_static_regexes() ->
	case catch persistent_term:get(commonmark_ffi) of
		{ 'EXIT', { badarg, _ } } -> 
			Atx_header_regex = get_regex(<<"^ {0,3}(#{1,6})([ \t]+.*?)?(?:(?<=[ \t])#*)?[ \t]*$"/utf8>>, 25),
			Block_quote_regex = get_regex(<<"^ {0,3}> ?(.*)$"/utf8>>, 26),
			Fenced_code_start_regex = get_regex(<<"^( {0,3})(([~`])\\g{3}{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$"/utf8>>, 27),
			Hr_regex = get_regex(<<"^ {0,3}(?:([-*_]))(?:[ \t]*\\g{1}){2,}[ \t]*$"/utf8>>, 28),
			Indented_code_regex = get_regex(<<"^(?: {0,3}\t|    )|^[ \t]*$"/utf8>>, 29),
			Ol_regex = get_regex(<<"^( {0,3})([0-9]{1,9})([.)])(?:( {1,4})(.*))?$"/utf8>>, 30),
			Setext_header_regex = get_regex(<<"^ {0,3}([-=])+[ \t]*$"/utf8>>, 31),
			Ul_regex = get_regex(<<"^( {0,3})([-*+])(?:( {1,4})(.*))?$"/utf8>>, 32),
			Value = {
				parser_regexes,
				Atx_header_regex,
				Block_quote_regex,
				Fenced_code_start_regex,
				Hr_regex,
				Indented_code_regex,
				Ol_regex,
				Setext_header_regex,
				Ul_regex
			},
			persistent_term:put(commonmark_ffi, { ok, Value }),
			Value;
		{ ok, Value } -> Value
	end.
