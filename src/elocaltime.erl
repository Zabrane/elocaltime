-module(elocaltime).

-include("elocaltime.hrl").

-export([
    start/0,
    start/1,
    stop/0,

    civil_lookup/2,
    absolute_lookup/2,

    utc2local_datetime/2,
    utc2local_ts/2,

    local2utc_ts/3,
    local2utc_datetime/3,
    is_timezone_valid/1,

    format/2,
    format/3
]).

-type reason() :: any().
-type datetime() :: calendar:datetime() | timestamp().
-type timezone() :: binary() | ?TIMEZONE_UTC | ?TIMEZONE_LOCAL | ?TIMEZONE_FIXED(integer()).
-type disambiguation() :: ?DS_STANDARD | ?DS_DAYLIGHT | ?DS_BOTH.
-type absolute_lookup() :: #absolute_lookup{}.
-type civil_lookup() :: #civil_lookup{}.

-spec start() ->
    ok  | {error, reason()}.

start() ->
    start(temporary).

-spec start(permanent | transient | temporary) ->
    ok | {error, reason()}.

start(Type) ->
    case application:ensure_all_started(elocaltime, Type) of
        {ok, _} ->
            ok;
        Other ->
            Other
    end.

-spec stop() ->
    ok.

stop() ->
    application:stop(elocaltime).

-spec civil_lookup(datetime(), timezone()) ->
    {ok, civil_lookup()} | {error, reason()}.

civil_lookup(Date, Timezone) ->
    case elocaltime_timezone:get_tz(Timezone) of
        {ok, TzRef} ->
            elocaltime_nif:civil_lookup(to_datetime(Date), TzRef);
        Error ->
            Error
    end.

-spec absolute_lookup(datetime(), timezone()) ->
    {ok, absolute_lookup()} | {error, reason()}.

absolute_lookup(Date, Timezone) ->
    case elocaltime_timezone:get_tz(Timezone) of
        {ok, TzRef} ->
            elocaltime_nif:absolute_lookup(to_seconds(Date), TzRef);
        Error ->
            Error
    end.

-spec utc2local_datetime(datetime(), timezone()) ->
    {ok, calendar:datetime()} | {error, reason()}.

utc2local_datetime(Date, Timezone) ->
    case absolute_lookup(Date, Timezone) of
        {ok, #absolute_lookup{date = LocalDate}} ->
            {ok, LocalDate};
        Error ->
            Error
    end.

-spec utc2local_ts(datetime(), timezone()) ->
    {ok, timestamp()} | {error, reason()}.

utc2local_ts(Date, Timezone) ->
    case utc2local_datetime(Date, Timezone) of
        {ok, DateTime} ->
            {ok, elocaltime_utils:datetime2ts(DateTime)};
        Error ->
            Error
    end.

-spec local2utc_ts(datetime(), timezone(), disambiguation()) ->
    {ok, timestamp()} | {ok, timestamp(), timestamp()} | {error, reason()}.

local2utc_ts(Date, Timezone, Disambiguation) ->
    case civil_lookup(Date, Timezone) of
        {ok, CivilLookup} ->
            disambiguation(CivilLookup, Disambiguation);
        Error ->
            Error
    end.

-spec local2utc_datetime(datetime(), timezone(), disambiguation()) ->
    {ok, calendar:datetime()} | {ok, calendar:datetime(), calendar:datetime()} | {error, reason()}.

local2utc_datetime(Date, Timezone, Disambiguation) ->
    case local2utc_ts(Date, Timezone, Disambiguation) of
        {ok, Dt} ->
            {ok, elocaltime_utils:ts2datetime(Dt)};
        {ok, DtPre, DtPost} ->
            {ok, elocaltime_utils:ts2datetime(DtPre), elocaltime_utils:ts2datetime(DtPost)};
        Error ->
            Error
    end.

-spec is_timezone_valid(timezone()) ->
    boolean().

is_timezone_valid(Timezone) ->
    elocaltime_timezone:is_valid(Timezone).

-spec format(binary(), datetime()) ->
    {ok, binary()}.

format(Format, DateTime) ->
    elocaltime_nif:format(Format, to_seconds(DateTime)).

-spec format(binary(), datetime(), timezone()) ->
    {ok, binary()}.

format(Format, DateTime, Timezone) ->
    case elocaltime_timezone:get_tz(Timezone) of
        {ok, TzRef} ->
            elocaltime_nif:format(Format, to_seconds(DateTime), TzRef);
        Error ->
            Error
    end.

%private

-spec disambiguation(civil_lookup(), disambiguation()) ->
    {ok, timestamp()} | {ok, timestamp(), timestamp()}.

disambiguation(#civil_lookup{civil_kind = Kind, pre = Pre, trans = _Trans, post = Post}, Disambiguation) ->
    case Kind of
        ?CIVIL_KIND_UNIQUE ->
            {ok, Pre};
        _ ->
            case Disambiguation of
                ?DS_STANDARD ->
                    {ok, Pre};
                ?DS_DAYLIGHT ->
                    {ok, Post};
                ?DS_BOTH ->
                    {ok, Pre, Post}
            end
    end.

-spec to_seconds(datetime()) ->
    timestamp().

to_seconds(V) when is_integer(V) ->
    V;
to_seconds(V) ->
    elocaltime_utils:datetime2ts(V).

-spec to_datetime(datetime()) ->
    calendar:datetime().

to_datetime(V) when is_integer(V) ->
    elocaltime_utils:ts2datetime(V);
to_datetime(V) ->
    V.
