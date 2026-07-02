*# test_un_pop.do: smoke- and edge-case tests for un_pop.ado -------------------
*# Run from anywhere; only assumes a checkout of unPopData at LOCAL_ROOT
*# below (edit it if your checkout lives elsewhere). Every check prints
*# PASS/FAIL so results can be grepped: failures start with "FAIL".
*#
*# The happy-path checks (single country + multiple countries) run twice:
*# first against the GitHub default root (no root() at all), then against
*# a local root() override -- both must load correctly and agree.
*#
*# Also covers: explicit/default/lowercase variant, comma- vs
*# space-separated country lists, bad country code(s), bad variant, bad
*# root, and structural checks on the merged output (no missing merges,
*# one consistent variant label, original variable names preserved, no
*# edu_level placeholder).

clear all
set more off
version 16.0

*# Absolute path so this runs regardless of the current working directory.
local ADO_DIR    "C:/Users/wb532966/eb-local/macro-micro/unPopAdo"
local LOCAL_ROOT "C:/Users/wb532966/eb-local/macro-micro/unPopData/clean"

cap program drop un_pop
run "`ADO_DIR'/un_pop.ado"

cap program drop _check
program define _check
    args label ok
    if (`ok') {
        di as result "PASS -- `label'"
    }
    else {
        di as error  "FAIL -- `label'"
    }
end

*# _happy_path: single-country + multiple-country load, run once per root -------
*# `root' == "" means "no root() at all" (the GitHub default).
cap program drop _happy_path
program define _happy_path
    args label root

    if ("`root'" == "") {
        local rootopt ""
    }
    else {
        local rootopt `"root("`root'")"'
    }

    *# -- single country --
    un_pop, country(GNB) `rootopt'
    local ok = (_N > 0)
    _check "[`label'] single country: loads some data" `ok'

    qui levelsof iso3_code, local(c1) clean
    local ok = ("`c1'" == "GNB")
    _check "[`label'] single country: iso3_code == GNB" `ok'

    qui levelsof variant, local(v1) clean
    local ok = ("`v1'" == "Medium")
    _check "[`label'] single country: default variant == Medium" `ok'

    qui count if missing(location)
    local ok = (r(N) == 0)
    _check "[`label'] single country: no missing location (country merge)" `ok'

    qui count if missing(pop)
    local ok = (r(N) == 0)
    _check "[`label'] single country: no missing pop values" `ok'

    qui tab sex
    local ok = (r(r) == 2)
    _check "[`label'] single country: sex takes exactly 2 values" `ok'

    cap qui describe edu_level
    local ok = (_rc != 0)
    _check "[`label'] single country: edu_level is not present" `ok'

    *# -- multiple countries, loaded together --
    un_pop, country("GNB SEN COL") `rootopt'
    local ok = (_N > 0)
    _check "[`label'] multiple countries: loads some data" `ok'

    qui levelsof iso3_code, local(cl) clean
    local ok = ("`cl'" == "COL GNB SEN")
    _check "[`label'] multiple countries: all 3 present, alphabetized by iso3" `ok'

    qui count if missing(location)
    local ok = (r(N) == 0)
    _check "[`label'] multiple countries: no missing location (country merge)" `ok'

    foreach iso in COL GNB SEN {
        qui count if iso3_code == "`iso'"
        local ok = (r(N) > 0)
        _check "[`label'] multiple countries: `iso' rows present" `ok'
    }
end

*# A. Happy path against GitHub, the default root (no root() supplied) ----------
di as text _newline "===== A. GitHub (default root, no root() supplied) ====="
_happy_path "GitHub" ""

*# B. Happy path against a local root() override --------------------------------
di as text _newline "===== B. local root() override ====="
_happy_path "Local" "`LOCAL_ROOT'"

*# C. Comma-separated + mixed-case country list ----------------------------------
di as text _newline "===== C. comma-separated, mixed-case country list ====="
un_pop, country("gnb, Sen ,col") root("`LOCAL_ROOT'")
qui levelsof iso3_code, local(clist_c) clean
local ok = ("`clist_c'" == "COL GNB SEN")
_check "C1. comma/space/case all normalize to the same 3 countries" `ok'

*# D. Explicit + lowercase variant -----------------------------------------------
di as text _newline "===== D. explicit + lowercase variant ====="
un_pop, country(GNB) root("`LOCAL_ROOT'") variant(medium)
qui levelsof variant, local(v4) clean
local ok = ("`v4'" == "Medium")
_check "D1. lowercase 'medium' resolves to canonical 'Medium'" `ok'

*# E. variant column is one consistent label across historical + projection -----
di as text _newline "===== E. one variant label spans historical + projection years ====="
un_pop, country(GNB) root("`LOCAL_ROOT'")
qui count if time < 2024 & variant != "Medium"
local ok = (r(N) == 0)
_check "E1. historical rows also carry the requested variant label" `ok'
qui count if time >= 2024 & variant != "Medium"
local ok = (r(N) == 0)
_check "E2. projection rows carry the requested variant label" `ok'

*# F. country() omitted -- mandatory option, fails at Stata's own parser --------
di as text _newline "===== F. country() omitted ====="
cap noisily un_pop, root("`LOCAL_ROOT'")
local ok = (_rc != 0)
_check "F1. missing country() errors" `ok'

*# G. Single unmatched country code -----------------------------------------------
di as text _newline "===== G. unmatched country code ====="
cap noisily un_pop, country(ZZZ) root("`LOCAL_ROOT'")
local ok = (_rc == 198)
_check "G1. bad country code errors with r(198)" `ok'

*# H. Mixed valid/invalid country codes -- nothing loaded, all named ------------
di as text _newline "===== H. one bad code among several good ones ====="
cap noisily un_pop, country("GNB ZZZ SEN") root("`LOCAL_ROOT'")
local ok = (_rc == 198)
_check "H1. any bad code blocks the whole call" `ok'

*# I. Unmatched variant -----------------------------------------------------------
di as text _newline "===== I. unmatched variant ====="
cap noisily un_pop, country(GNB) root("`LOCAL_ROOT'") variant("Nope")
local ok = (_rc == 198)
_check "I1. bad variant errors with r(198)" `ok'

*# J. Historical is not a selectable variant ---------------------------------------
di as text _newline "===== J. 'Historical' is reserved, not selectable ====="
cap noisily un_pop, country(GNB) root("`LOCAL_ROOT'") variant("Historical")
local ok = (_rc == 198)
_check "J1. requesting Historical directly errors" `ok'

*# K. Bad root (local path that does not exist) -----------------------------------
di as text _newline "===== K. root does not exist ====="
cap noisily un_pop, country(GNB) root("./this/path/does/not/exist")
local ok = (_rc == 601)
_check "K1. bad root errors with r(601)" `ok'

*# L. blank country() --------------------------------------------------------------
di as text _newline "===== L. blank country() ====="
cap noisily un_pop, country("   ") root("`LOCAL_ROOT'")
local ok = (_rc != 0)
_check "L1. blank country() errors" `ok'

di as text _newline "===== done ====="
