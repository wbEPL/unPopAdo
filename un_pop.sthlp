{smcl}
{* *! version 2.0.0  2 Jul 2026}{...}
{viewerjumpto "Syntax" "un_pop##syntax"}{...}
{viewerjumpto "Description" "un_pop##description"}{...}
{viewerjumpto "Options" "un_pop##options"}{...}
{viewerjumpto "Root layout" "un_pop##root"}{...}
{viewerjumpto "Stored output" "un_pop##output"}{...}
{viewerjumpto "Examples" "un_pop##examples"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{bf:un_pop} {hline 2}}UN WPP2024 population estimates/projections for one or more countries{p_end}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:un_pop} {cmd:,} {opt c:ountry(string)} [{opt r:oot(string)} {opt v:ariant(string)}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt c:ountry(string)}}one or more ISO3 codes; {bf:required}{p_end}
{synopt:{opt r:oot(string)}}local folder or URL with the clean/ data layout; default is the unPopData GitHub repo{p_end}
{synopt:{opt v:ariant(string)}}UN projection variant; default {bf:Medium}{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:un_pop} loads the UN WPP2024 "Population on 1 January by 5-year age
group and sex" series for one or more countries and leaves the result as
the dataset in memory (nothing is saved to disk; whatever was loaded
before {cmd:un_pop} ran is replaced).

{pstd}
For each requested country it stacks the shared 1950-2023 historical
rows with the chosen variant's 2024-onward projection rows into one
continuous series, then merges in country identifiers (from
{bf:lookup_countries}) and the variant name (from {bf:lookup_scenarios}),
so the returned data needs no further lookups.

{marker options}{...}
{title:Options}

{phang}
{opt country(string)} is one or more ISO3 codes, separated by spaces
and/or commas -- {cmd:country(GNB)}, {cmd:country("GNB SEN COL")}, and
{cmd:country("GNB, SEN, COL")} are all valid. Matching is
case-insensitive and duplicates are dropped automatically. Required.

{pmore}
If any requested code is not in {bf:lookup_countries.dta}, {cmd:un_pop}
loads nothing for any country: it stops with {cmd:r(198)}, naming the bad
code(s) and printing the full iso3_code/location reference table so you
can find the right one.

{phang}
{opt root(string)} points at a folder laid out like unPopData's
{bf:clean/} folder (see {help un_pop##root:Root layout} below) -- either a
local path or a URL. Optional; if omitted, defaults to the raw-file base
URL of the unPopData GitHub repository, so {cmd:un_pop} works out of the
box with no local data at all. Unreachable or missing files stop with
{cmd:r(601)}.

{phang}
{opt variant(string)} selects one UN projection variant (case-insensitive;
the canonical casing from {bf:lookup_scenarios.dta} is used in the
output). Optional, defaults to {bf:Medium}. This is validated dynamically
against whatever non-historical variants exist in
{bf:lookup_scenarios.dta} -- {bf:Medium} is simply the only one built by
the current data pipeline today; more variants (High, Low, ...) become
selectable the moment the data adds them, with no change to this command.
An unmatched variant stops with {cmd:r(198)}, listing what is actually
available. {bf:Historical} is the shared pre-2024 baseline, not a
user-selectable variant, and is rejected the same way.

{marker root}{...}
{title:Root layout}

{pstd}
Whether {opt root()} is a local path or a URL, it must point directly at
a folder containing:

{p2colset 9 32 34 2}{...}
{p2col:{bf:lookup_countries.dta}}locid, iso3_code, iso2_code, location -- one row per country{p_end}
{p2col:{bf:lookup_scenarios.dta}}varid, variant -- varid 0 is the reserved "Historical" baseline{p_end}
{p2col:{bf:<ISO3>.dta}}locid, varid, time, agegrpstart, sex, pop -- one file per country{p_end}
{p2colreset}{...}

{pstd}
This is exactly the {bf:clean/} folder produced by
{bf:clean_wpp_population_data.R} in the unPopData repository. A local
{opt root()} is simply a checkout of that repository:
{cmd:un_pop, country(GNB) root("../unPopData/clean")}.

{marker output}{...}
{title:Stored output}

{pstd}
Left in memory, one row per country x year x 5-year age group x sex,
sorted by iso3_code variant time agegrpstart sex. Variable names are
carried over unchanged from the source files -- only {bf:iso3_code},
{bf:location}, {bf:iso2_code} and {bf:locid} are new, merged in from
{bf:lookup_countries}:

{p2colset 9 20 22 2}{...}
{p2col:{bf:iso3_code}}ISO3 country code{p_end}
{p2col:{bf:location}}country / area name{p_end}
{p2col:{bf:iso2_code}}ISO2 country code{p_end}
{p2col:{bf:locid}}UN location ID{p_end}
{p2col:{bf:variant}}requested variant name, applied to both historical and projection rows{p_end}
{p2col:{bf:varid}}UN VarID of the source row (0 = historical){p_end}
{p2col:{bf:time}}calendar year (1 January), 1950 onward{p_end}
{p2col:{bf:agegrpstart}}5-year age group, start age (0, 5, ..., 100){p_end}
{p2col:{bf:sex}}labelled 1 = Male, 2 = Female{p_end}
{p2col:{bf:pop}}population, in thousands{p_end}
{p2colreset}{...}

{marker examples}{...}
{title:Examples}

{phang}{cmd:. un_pop, country(GNB)}{p_end}
{phang}{cmd:. un_pop, country("GNB SEN COL") variant(Medium)}{p_end}
{phang}{cmd:. un_pop, country(GNB) root("../unPopData/clean")}{p_end}

{title:Author}

{pstd}Eduard Bukin, ebukin@worldbank.org{p_end}
