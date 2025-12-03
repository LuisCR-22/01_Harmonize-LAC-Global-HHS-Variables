/*====================================================================
Project: Adding CPI Data to Harmonized LAC Panel Datasets
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/12/01
Last modification: 	2025/12/01
====================================================================*/

clear all
set more off

**# ==============================================================================
**# 0. SETUP AND PATHS
**# ==============================================================================

global wdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team"
global cpi_data "$wdir\Dta"
global output_data "$wdir\Dta\PER"

* Country-specific settings (must match harmonization script)
global current_country "Peru"
global current_iso "PER"

* Define year combinations (must match harmonization script)
if "$current_country" == "Peru" {
    local combo1 "2019 2021"
    local combo2 "2021 2022"
    local combo3 "2022 2023"
    local combo4 "2019 2023"
    local n_combos = 4
}

noi di ""
noi di "=== ADDING CPI DATA TO HARMONIZED PANEL DATASETS ==="
noi di "Country: $current_country (ISO: $current_iso)"
noi di ""

**# ==============================================================================
**# 1. PREPARE CPI DATASET
**# ==============================================================================

noi di "Step 1: Preparing CPI dataset..."

use "$cpi_data/CPI_5_countries.dta", clear

* Check structure
noi di "  Original CPI dataset loaded. Observations: " _N
list in 1/5, clean noobs

* Extract country code from TSNAME
gen pais = ""
replace pais = lower(substr(TSNAME, 5, 3))
label var pais "Country code (extracted from TSNAME)"

* Parse DATE field to extract year and month
gen ano = real(substr(DATE, 1, 4))
label var ano "Year (extracted from DATE)"

gen mes = real(substr(DATE, 7, 2))
label var mes "Month (extracted from DATE)"

* Rename VALUE to cpiwave for merge
rename VALUE cpiwave
label var cpiwave "Average monthly CPI (from IMF data)"

* Keep only necessary variables
keep pais ano mes cpiwave

* Check for duplicates
duplicates drop pais ano mes, force

* Summary statistics
noi di "  CPI dataset prepared:"
qui sum ano
noi di "    Year range: " r(min) " - " r(max)
qui sum mes
noi di "    Month range: " r(min) " - " r(max)
noi di "    Total observations: " _N

* Verify country extraction
noi di "  Countries in CPI dataset:"
qui levelsof pais, local(countries)
foreach c of local countries {
    noi di "    - `c'"
}
noi di ""

* Save prepared CPI dataset temporarily
tempfile cpi_prepared
save `cpi_prepared', replace

**# ==============================================================================
**# 2. CREATE CPIWAVE DATASET (AVERAGE BY COUNTRY-YEAR)
**# ==============================================================================

noi di "Step 2: Calculating average CPI for each survey wave/year by country..."

use `cpi_prepared', clear

* Calculate average CPI for each year by country
collapse (mean) cpiwave_avg=cpiwave (count) n_months=cpiwave, by(pais ano)
rename cpiwave_avg cpiwave
label var cpiwave "Average monthly CPI during data collection period for this wave"
label var n_months "Number of months used in wave average"

noi di "  Wave CPI averages calculated:"
noi di "  Total country-year combinations: " _N
list pais ano cpiwave n_months in 1/20, clean noobs separator(5)
noi di ""

* Save cpiwave dataset temporarily
tempfile cpiwave_prepared
save `cpiwave_prepared', replace

**# ==============================================================================
**# 3. CREATE CPI2021 DATASET (AVERAGE ACROSS ALL MONTHS IN 2021)
**# ==============================================================================

noi di "Step 3: Calculating average CPI for 2021 by country..."

use `cpi_prepared', clear

* Keep only 2021 data
keep if ano == 2021

* Check if we have any 2021 data
qui count
if r(N) == 0 {
    noi di "  ERROR: No 2021 data found in CPI dataset!"
    noi di "  Available years:"
    use `cpi_prepared', clear
    tab ano, missing
    error 2000
}

noi di "  2021 observations found: " _N

* Check if we have 12 months for each country
noi di "  Checking 2021 data completeness:"
bysort pais: gen n_months_check = _N
bysort pais: gen first_obs = (_n == 1)
list pais n_months_check if first_obs, clean noobs

qui sum n_months_check
if r(min) < 12 {
    noi di "  WARNING: Some countries have fewer than 12 months in 2021!"
}
drop n_months_check first_obs

* Calculate average CPI for 2021 by country
collapse (mean) cpi2021=cpiwave (count) n_months=cpiwave, by(pais)
label var cpi2021 "Average monthly CPI in 2021 (mean of 12 months)"
label var n_months "Number of months used in 2021 average"

noi di "  2021 CPI averages calculated:"
list pais cpi2021 n_months, clean noobs separator(0)
noi di ""

* Save cpi2021 dataset temporarily
tempfile cpi2021_prepared
save `cpi2021_prepared', replace

**# ==============================================================================
**# 4. LOOP THROUGH PANEL DATASETS AND MERGE CPI DATA
**# ==============================================================================

noi di "Step 4: Merging CPI data with panel datasets..."
noi di ""

forvalues i = 1/`n_combos' {
    
    * Parse the year combination
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    
    noi di "Processing: 01_${current_iso}_`t0'-`t1'_panel.dta"
    
    * Load panel dataset
    use "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", clear
    
    * Store original number of observations
    local n_before = _N
    
    * Check if merge keys exist
    cap confirm variable pais ano
    if _rc {
        noi di "  ERROR: Required merge variables (pais, ano) not found!"
        noi di "  Skipping this dataset."
        continue
    }
    
    **# -------------------------------------------------------------------------
    **# 4.1 MERGE CPIWAVE (constant within wave: country-year)
    **# -------------------------------------------------------------------------
    
    noi di "  [A] Merging cpiwave (constant within wave)..."
    noi di "    Before merge: `n_before' observations"
    
    * Check current cpiwave status
    qui count if !missing(cpiwave)
    if r(N) > 0 {
        noi di "    Note: " r(N) " observations already have cpiwave values (will be replaced)"
    }
    
    * Perform merge for cpiwave (on pais + ano only, NOT mes)
    merge m:1 pais ano using `cpiwave_prepared', ///
        keepusing(cpiwave n_months) ///
        update replace ///
        gen(_merge_cpiwave)
    
    * Check merge results
    qui count if _merge_cpiwave == 1
    local n_master_only = r(N)
    qui count if _merge_cpiwave == 3 | _merge_cpiwave == 4 | _merge_cpiwave == 5
    local n_matched = r(N)
    
    noi di "    Master only (no CPI match): `n_master_only'"
    noi di "    Matched: `n_matched'"
    
    * Warning if many observations lack CPI data
    if `n_master_only' > 0 {
        local pct_missing = (`n_master_only' / `n_before') * 100
        if `pct_missing' > 5 {
            noi di "    WARNING: " %5.2f `pct_missing' "% of observations lack cpiwave data!"
            * Show which country-years are missing
            preserve
            keep if _merge_cpiwave == 1
            contract pais ano
            noi di "    Missing CPI combinations:"
            list pais ano, clean noobs
            restore
        }
    }
    
    * Keep only observations from master dataset
    keep if _merge_cpiwave != 2
    drop _merge_cpiwave n_months
    
    * Verify cpiwave is constant within wave
    qui bysort ano: egen check_constant = sd(cpiwave)
    qui sum check_constant
    if r(max) > 0.001 & r(max) < . {
        noi di "    NOTE: cpiwave varies within wave (expected if multiple countries)"
    }
    drop check_constant
    
    * Check coverage
    qui count if !missing(cpiwave)
    local n_with_cpiwave = r(N)
    local pct_with_cpiwave = (`n_with_cpiwave' / _N) * 100
    noi di "    After merge: `n_with_cpiwave' observations with cpiwave (" %5.2f `pct_with_cpiwave' "%)"
    
    **# -------------------------------------------------------------------------
    **# 4.2 MERGE CPI2021 (constant within country)
    **# -------------------------------------------------------------------------
    
    noi di "  [B] Merging cpi2021 (constant within country)..."
    
    * Check current cpi2021 status
    qui count if !missing(cpi2021)
    if r(N) > 0 {
        noi di "    Note: " r(N) " observations already have cpi2021 values (will be replaced)"
    }
    
    * Perform merge for cpi2021
    merge m:1 pais using `cpi2021_prepared', ///
        keepusing(cpi2021 n_months) ///
        update replace ///
        gen(_merge_cpi2021)
    
    * Check merge results
    qui count if _merge_cpi2021 == 1
    local n_master_only_2021 = r(N)
    qui count if _merge_cpi2021 == 3 | _merge_cpi2021 == 4 | _merge_cpi2021 == 5
    local n_matched_2021 = r(N)
    
    noi di "    Master only (no 2021 average): `n_master_only_2021'"
    noi di "    Matched: `n_matched_2021'"
    
    * Warning if observations lack cpi2021
    if `n_master_only_2021' > 0 {
        noi di "    WARNING: Some observations lack cpi2021 data (country not in 2021 CPI dataset)!"
    }
    
    * Keep only observations from master dataset
    keep if _merge_cpi2021 != 2
    drop _merge_cpi2021 n_months
    
    * Check coverage and value
    qui count if !missing(cpi2021)
    local n_with_cpi2021 = r(N)
    local pct_with_cpi2021 = (`n_with_cpi2021' / _N) * 100
    noi di "    After merge: `n_with_cpi2021' observations with cpi2021 (" %5.2f `pct_with_cpi2021' "%)"
    
    * Display the cpi2021 value for this country
    qui sum cpi2021
    if r(N) > 0 {
        noi di "    ${current_iso} cpi2021 value: " %8.2f r(mean)
    }
    
    **# -------------------------------------------------------------------------
    **# 4.3 FINAL SUMMARY FOR THIS DATASET
    **# -------------------------------------------------------------------------
    
    noi di "  Final status:"
    noi di "    Total observations: " _N
    qui sum cpiwave, detail
    if r(N) > 0 {
        noi di "    cpiwave range: " %8.2f r(min) " - " %8.2f r(max)
    }
    qui sum cpi2021
    if r(N) > 0 {
        noi di "    cpi2021 value: " %8.2f r(mean) " (constant for all obs)"
    }
    
    * Add notes about CPI merge
    note cpiwave: Updated with IMF CPI data on $S_DATE
    note cpiwave: Average monthly CPI during data collection period (by country-year)
    note cpiwave: Merged on country (pais) and year (ano) - constant within wave
    note cpi2021: Updated with IMF CPI data on $S_DATE
    note cpi2021: Average of all 12 monthly CPI values in 2021 by country
    note cpi2021: Merged on country (pais) only - constant within country
    
    * Save updated dataset (overwrites original)
    save "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", replace
    noi di "  Saved updated dataset"
    noi di ""
}

**# ==============================================================================
**# 5. FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "=== CPI MERGE COMPLETED ==="
noi di ""
noi di "Country: $current_country (ISO: $current_iso)"
noi di "Number of panel datasets updated: `n_combos'"
noi di "Output location: $output_data"
noi di ""
noi di "Updated datasets:"
forvalues i = 1/`n_combos' {
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    noi di "  - 01_${current_iso}_`t0'-`t1'_panel.dta"
}
noi di ""
noi di "Variables updated:"
noi di "  - cpiwave: Wave-level CPI (average across data collection months, constant within country-year)"
noi di "  - cpi2021: 2021 reference CPI (average of 12 months, constant within country)"
noi di ""