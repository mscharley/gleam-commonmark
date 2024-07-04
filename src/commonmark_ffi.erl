-module(commonmark_ffi).
-compile([no_auto_import]).

-export([get_platform_regexes/0]).

-spec get_platform_regexes() -> {gleam@regex:regex(), gleam@regex:regex()}.
get_platform_regexes() ->
    _assert_subject = gleam@regex:from_string(
        <<"^ {0,3}(?:([-*_]))(?:[ \t]*\\g{1}){2,}[ \t]*$"/utf8>>
    ),
    {ok, Hr_regex} = case _assert_subject of
        {ok, _} -> _assert_subject;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Assertion pattern match failed"/utf8>>,
                        value => _assert_fail,
                        module => <<"commonmark_ffi"/utf8>>,
                        function => <<"get_platform_regexes"/utf8>>,
                        line => 8})
    end,
    _assert_subject@1 = gleam@regex:from_string(
        <<"^( {0,3})(([~`])\\g{3}{2,})[ \t]*(([^\\s]+).*?)?[ \t]*$"/utf8>>
    ),
    {ok, Fenced_code_start_regex} = case _assert_subject@1 of
        {ok, _} -> _assert_subject@1;
        _assert_fail@1 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Assertion pattern match failed"/utf8>>,
                        value => _assert_fail@1,
                        module => <<"commonmark_ffi"/utf8>>,
                        function => <<"get_platform_regexes"/utf8>>,
                        line => 21})
    end,
    {Hr_regex, Fenced_code_start_regex}.
