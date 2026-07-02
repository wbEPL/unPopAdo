*# test_un_pop.do: smoke- and edge-case tests for un_pop.ado -------------------
*# Run from anywhere; only assumes a checkout of unPopData at LOCAL_ROOT
*# below (edit it if your checkout lives elsewhere). Every check prints
*# PASS/FAIL so results can be grepped: failures start with "FAIL".
*#
*# Covers: single country, multiple countries, explicit/default/lowercase
*# variant, comma- vs space-separated country lists, bad country code(s),
*# bad variant, bad root, and structural checks on the merged output
*# (no missing merges, one consistent variant label, labelled gender).

clear all
set more off
version 16.0

*# Absolute paths so this runs regardless of the current working directory.
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

*# 1. Single country, default root/variant --------------------------------------
di as text _newline "===== 1. single country, default variant, local root ====="
un_pop, country(GNB) root("`LOCAL_ROOT'")
local ok = (_N > 0)
_check "1a. loads some data" `ok'

qui levelsof country, local(c1) clean
local ok = (`: word count `c1'' == 1)
_check "1b. exactly one country in output" `ok'
local ok = ("`c1'" == "GNB")
_check "1c. country == GNB" `ok'

qui levelsof variant, local(v1) clean
local ok = ("`v1'" == "Medium")
_check "1d. default variant == Medium" `ok'

qui count if missing(location)
local ok = (r(N) == 0)
_check "1e. no missing location values" `ok'

qui count if missing(iso2_code)
local ok = (r(N) == 0)
_check "1f. no missing iso2_code values" `ok'

qui count if missing(value)
local ok = (r(N) == 0)
_check "1g. no missing value (pop)" `ok'

qui tab gender
local ok = (r(r) == 2)
_check "1h. gender takes exactly 2 values" `ok'

qui count if year < 1950
local ok = (r(N) == 0)
_check "1i. no years before 1950" `ok'

*# 2. Multiple countries, space-separated ----------------------------------------
di as text _newline "===== 2. multiple countries (space-separated) ====="
un_pop, country("GNB SEN COL") root("`LOCAL_ROOT'")
qui levelsof country, local(clist2) clean
local ok = ("`clist2'" == "COL GNB SEN")
_check "2a. all 3 countries present, alphabetized by iso3" `ok'

*# 3. Multiple countries, comma-separated + mixed case ---------------------------
di as text _newline "===== 3. multiple countries (comma-separated, mixed case) ====="
un_pop, country("gnb, Sen ,col") root("`LOCAL_ROOT'")
qui levelsof country, local(clist3) clean
local ok = ("`clist3'" == "`clist2'")
_check "3a. comma/space/case all normalize the same way" `ok'

*# 4. Explicit + lowercase variant -----------------------------------------------
di as text _newline "===== 4. explicit + lowercase variant ====="
un_pop, country(GNB) root("`LOCAL_ROOT'") variant(medium)
qui levelsof variant, local(v4) clean
local ok = ("`v4'" == "Medium")
_check "4a. lowercase 'medium' resolves to canonical 'Medium'" `ok'

*# 5. variant column is one consistent label across historical + projection -----
di as text _newline "===== 5. one variant label spans historical + projection years ====="
un_pop, country(GNB) root("`LOCAL_ROOT'")
qui count if year < 2024 & variant != "Medium"
local ok = (r(N) == 0)
_check "5a. historical rows also carry the requested variant label" `ok'
qui count if year >= 2024 & variant != "Medium"
local ok = (r(N) == 0)
_check "5b. projection rows carry the requested variant label" `ok'

*# 6. country() omitted -- mandatory option, fails at Stata's own parser --------
di as text _newline "===== 6. country() omitted ====="
cap noisily un_pop, root("`LOCAL_ROOT'")
local ok = (_rc != 0)
_check "6a. missing country() errors" `ok'

*# 7. Single unmatched country code -----------------------------------------------
di as text _newline "===== 7. unmatched country code ====="
cap noisily un_pop, country(ZZZ) root("`LOCAL_ROOT'")
local ok = (_rc == 198)
_check "7a. bad country code errors with r(198)" `ok'

*# 8. Mixed valid/invalid country codes -- nothing loaded, all named -------------
di as text _newline "===== 8. one bad code among several good ones ====="
cap noisily un_pop, country("GNB ZZZ SEN") root("`LOCAL_ROOT'")
local ok = (_rc == 198)
_check "8a. any bad code blocks the whole call" `ok'

*# 9. Unmatched variant -----------------------------------------------------------
di as text _newline "===== 9. unmatched variant ====="
cap noisily un_pop, country(GNB) root("`LOCAL_ROOT'") variant("Nope")
local ok = (_rc == 198)
_check "9a. bad variant errors with r(198)" `ok'

*# 10. Historical is not a selectable variant -------------------------------------
di as text _newline "===== 10. 'Historical' is reserved, not selectable ====="
cap noisily un_pop, country(GNB) root("`LOCAL_ROOT'") variant("Historical")
local ok = (_rc == 198)
_check "10a. requesting Historical directly errors" `ok'

*# 11. Bad root (local path that does not exist) ----------------------------------
di as text _newline "===== 11. root does not exist ====="
cap noisily un_pop, country(GNB) root("./this/path/does/not/exist")
local ok = (_rc == 601)
_check "11a. bad root errors with r(601)" `ok'

*# 12. blank country() -----------------------------------------------------------
di as text _newline "===== 12. blank country() ====="
cap noisily un_pop, country("   ") root("`LOCAL_ROOT'")
local ok = (_rc != 0)
_check "12a. blank country() errors" `ok'

*# 13. Default root -- GitHub (only meaningful once unPopData is pushed) ---------
di as text _newline "===== 13. default root (GitHub) -- informational, not asserted ====="
cap noisily un_pop, country(GNB)
if (_rc == 0) {
    di as result "PASS -- 13a. GitHub default root reachable and loads GNB (`=_N' obs)"
}
else {
    di as text "INFO -- 13a. GitHub default root not reachable yet (rc=`_rc'); expected until unPopData is pushed/public."
}

di as text _newline "===== done ====="
