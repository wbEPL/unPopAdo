*! version 2.0.0   Eduard Bukin ebukin@worldbank.org   2 Jul 2026
/*
un_pop: long-format UN WPP2024 population estimates/projections for one or
more countries, under a single projection variant, left in memory.

--------------------------------------------------------------------------
SOURCE DATA
--------------------------------------------------------------------------
Reads the pre-cleaned UN WPP2024 "Population on 1 January by 5-year age
group and sex" files produced by clean_wpp_population_data.R (see the
unPopData repo). Under root/ there must be:

    lookup_countries.dta   locid iso3_code iso2_code location
                            (one row per country/area)
    lookup_scenarios.dta   varid variant
                            (varid 0 = "Historical", reserved -- never a
                            user-selectable variant; every other varid is
                            a UN projection variant, e.g. "Medium")
    <ISO3>.dta              locid varid time agegrpstart sex pop
                            (one file per country; sex is a labelled int,
                            1 = Male, 2 = Female; pop is in thousands)

Historical rows (varid 0, 1950-2023, identical across every variant) plus
the chosen variant's projection rows (varid > 0, 2024 onward) are kept and
stacked into one continuous series per country, then all requested
countries are stacked together.

--------------------------------------------------------------------------
ROOT: GitHub by default, local folder as an override
--------------------------------------------------------------------------
root() is OPTIONAL (unlike v1.0.0, where it was mandatory). If omitted, it
defaults to the raw-file base URL of the unPopData GitHub repo:

    https://raw.githubusercontent.com/wbEPL/unPopData/main/clean

Stata's `use` reads .dta files directly over http(s), so nothing is
downloaded to disk -- the data is fetched straight into memory. This
requires a working internet connection; if the unPopData repo, branch, or
folder layout ever changes, pass an updated root() to override the
default without touching this file.

If root() IS supplied, it must point at a folder (local path or another
URL) laid out exactly like unPopData's clean/ folder above -- i.e. point
root() at the clean/ folder itself, not its parent. A local mirror is
simply a checkout of unPopData, e.g.:

    un_pop, country(GNB) root("../unPopData/clean")

--------------------------------------------------------------------------
VARIANT: dynamically validated, so today's one-variant limit is a data
fact, not a hardcoded one
--------------------------------------------------------------------------
variant() is validated against whatever non-historical rows exist in
lookup_scenarios.dta -- it is NOT a hardcoded list in this .ado. Right now
clean_wpp_population_data.R only builds "Medium", so "Medium" (the
default) is the only accepted value. When that script is re-run with more
entries from its ALL_SCENARIOS table (e.g. "High", "Low"), those variants
become selectable here automatically, with no code change required.
Exactly one variant is selected per call.

Matching is case-insensitive for both country() and variant(); the
canonical casing from the lookup tables is always used in the output.

--------------------------------------------------------------------------
OPTIONS
--------------------------------------------------------------------------
COUNTRY(string)   One or more ISO3 codes, space- and/or comma-separated,
                  e.g. country(GNB) or country("GNB SEN COL") or
                  country("GNB, SEN, COL"). Mandatory. Case-insensitive;
                  duplicates are silently collapsed. If ANY code is not in
                  lookup_countries.dta, NO data is loaded for ANY country
                  -- the command errors out (198) listing the bad code(s)
                  plus the full iso3_code/location reference table.

ROOT(string)      Local folder or URL holding the clean/ layout described
                  above. Optional; defaults to the unPopData GitHub raw
                  URL. Unreachable/missing files -> error 601.

VARIANT(string)   UN projection variant name. Optional, defaults to
                  "Medium". Unmatched -> error 198 listing the variants
                  actually available in lookup_scenarios.dta.

--------------------------------------------------------------------------
OUTPUT (left in memory, not saved to disk)
--------------------------------------------------------------------------
One row per country x year x 5-year age group x sex. Variable names are
carried over unchanged from the source files (no renaming); only
iso3_code, location, iso2_code and locid are new, merged in from
lookup_countries:

    iso3_code    ISO3 code                       (from lookup_countries)
    location     country / area name              (from lookup_countries)
    iso2_code    ISO2 code                        (from lookup_countries)
    locid        UN location ID                   (from lookup_countries /
                                                     <ISO3>.dta)
    variant      requested variant name, applied to BOTH the historical
                 and projection rows so the series reads as one continuous
                 scenario (from lookup_scenarios)
    varid        UN VarID of the row's source file (0 = historical)
                                                     (from <ISO3>.dta)
    time         calendar year (1 January), 1950 onward
                                                     (from <ISO3>.dta)
    agegrpstart  5-year age group, start age (0, 5, 10, ..., 100)
                                                     (from <ISO3>.dta)
    sex          labelled 1 = Male, 2 = Female     (from <ISO3>.dta)
    pop          population count, in thousands    (from <ISO3>.dta)

Sorted by iso3_code variant time agegrpstart sex.

--------------------------------------------------------------------------
EXAMPLES
--------------------------------------------------------------------------
    * Single country, default root (GitHub) and variant (Medium)
    un_pop, country(GNB)

    * Multiple countries, explicit variant
    un_pop, country("GNB SEN COL") variant(Medium)

    * Local mirror of unPopData instead of GitHub
    un_pop, country(GNB) root("../unPopData/clean")

--------------------------------------------------------------------------
CHANGES FROM v1.0.0
--------------------------------------------------------------------------
  - root() is now optional (defaults to GitHub) instead of mandatory.
  - country() now accepts multiple ISO3 codes, not just one.
  - Reads unPopData's one-file-per-country layout (lookup_countries.dta /
    lookup_scenarios.dta / <ISO3>.dta) instead of the older single
    baseline_population_1950_2023.csv + projection_<scenario>.csv layout.
  - location/iso2_code/locid are merged in from lookup_countries; all
    other variables (iso3_code, varid, time, agegrpstart, sex, pop) keep
    the exact names they have in the source .dta files -- no renaming to
    a country/year/cohort/gender/value schema, and no edu_level
    placeholder (this source has no education dimension). agegrpstart is
    the numeric age-group start rather than the UN's string AgeGrp label
    (e.g. "0-4"), since that is what the new source files carry.
*/

cap program drop un_pop
program define un_pop
version 16.0

syntax , COUNTRY(string) [ROOT(string) VARIANT(string)]

*# 0. Resolve root: default to GitHub, else normalize the user's path/URL ------
local ghdefault "https://raw.githubusercontent.com/wbEPL/unPopData/main/clean"
if ("`root'" == "") local root "`ghdefault'"
local root = subinstr("`root'", "\", "/", .)
while (substr("`root'", -1, 1) == "/") {
    local root = substr("`root'", 1, strlen("`root'") - 1)
}

*# 1. Parse & normalize the COUNTRY() list (space- or comma-separated) ---------
local country_list = subinstr(upper("`country'"), ",", " ", .)
local country_list : list clean country_list
local country_list : list uniq country_list
if ("`country_list'" == "") {
    di as error "country() cannot be blank."
    error 198
}

*# 2. Load lookup_countries.dta; validate every requested code at once ---------
tempfile tf_countries
qui cap use "`root'/lookup_countries.dta", clear
if _rc {
    di as error "Could not load lookup_countries.dta from root '`root''."
    di as text  "Check that root() is a valid local folder or URL, and (if a URL) that you have a working internet connection."
    error 601
}
qui save `tf_countries'

qui levelsof iso3_code, local(valid_countries) clean
local bad_countries : list country_list - valid_countries
if ("`bad_countries'" != "") {
    di as error "Country code(s) not found in lookup_countries.dta: `bad_countries'"
    di as text  "Full reference of valid country codes (iso3_code -- location):"
    list iso3_code location, sep(0) noobs
    error 198
}

*# 3. Load lookup_scenarios.dta; resolve VARIANT() case-insensitively ----------
if ("`variant'" == "") local variant "Medium"
local HISTORICAL_VARID = 0

tempfile tf_scenarios
qui cap use "`root'/lookup_scenarios.dta", clear
if _rc {
    di as error "Could not load lookup_scenarios.dta from root '`root''."
    di as text  "Check that root() is a valid local folder or URL, and (if a URL) that you have a working internet connection."
    error 601
}
qui save `tf_scenarios'

local req_variant_upper = upper("`variant'")
qui gen byte __sel = (upper(variant) == "`req_variant_upper'" & varid != `HISTORICAL_VARID')
qui count if __sel
if (r(N) == 0) {
    di as error "Variant '`variant'' not available."
    di as text  "Available variants (Historical is the automatic shared baseline, not user-selectable):"
    list variant if varid != `HISTORICAL_VARID', sep(0) noobs
    error 198
}
qui levelsof varid if __sel, local(sel_varid) clean
if (`: word count `sel_varid'' > 1) {
    di as error "Internal error: variant '`variant'' matches more than one varid in lookup_scenarios.dta."
    error 9999
}
qui levelsof variant if __sel, local(canon_variant) clean
drop __sel

*# 4. Load + filter + stack every requested country's data ---------------------
local n_countries : word count `country_list'
tempfile stacked
local i 0
foreach c of local country_list {
    local ++i
    qui cap use "`root'/`c'.dta", clear
    if _rc {
        di as error "Could not load `c'.dta from root '`root''."
        di as text  "Check that root() is a valid local folder or URL, and (if a URL) that you have a working internet connection."
        error 601
    }
    qui keep if inlist(varid, `HISTORICAL_VARID', `sel_varid')
    if (`i' == 1) {
        qui save `stacked'
    }
    else {
        qui append using `stacked'
        qui save `stacked', replace
    }
}
use `stacked', clear

*# 5. Merge in the variant name, then relabel the whole series with it ---------
qui merge m:1 varid using `tf_scenarios', keep(match master)
cap assert _merge == 3
if _rc {
    di as error "Internal error: some varid values in the country data were not found in lookup_scenarios.dta (data/schema mismatch)."
    error 9999
}
drop _merge
qui replace variant = "`canon_variant'"

*# 6. Merge in country identifiers (iso3_code, iso2_code, location) ------------
qui merge m:1 locid using `tf_countries', keep(match master)
cap assert _merge == 3
if _rc {
    di as error "Internal error: some locid values in the country data were not found in lookup_countries.dta (data/schema mismatch)."
    error 9999
}
drop _merge

*# 7. Order & sort -- original per-country variable names are preserved --------
keep  iso3_code location iso2_code locid variant varid time agegrpstart sex pop
order iso3_code location iso2_code locid variant varid time agegrpstart sex pop
sort  iso3_code variant time agegrpstart sex

label variable iso3_code   "ISO3 country code"
label variable location    "Country / area name (UN WPP)"
label variable iso2_code   "ISO2 country code"
label variable locid       "UN location ID"
label variable variant     "Projection variant / simulation version"
label variable varid       "UN VarID of the source row (0 = shared historical row)"
label variable time        "Calendar year (1 January)"
label variable agegrpstart "5-year age group, start age (0, 5, ..., 100)"
label variable sex         "Sex (1 = Male, 2 = Female)"
label variable pop         "Population, thousands"

di as text "----- un_pop: `n_countries' countries (`country_list') variant=`canon_variant' -> `=_N' obs in memory -----"

end
