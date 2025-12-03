/*====================================================================
Project: Adding CPI Data to Harmonized LAC Panel Datasets
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/12/02
Last modification: 	2025/12/02
====================================================================
PURPOSE: Merges CPI data (cpiwave and cpi2021) with harmonized panel
         datasets for all LAC countries in the analysis.

METHODOLOGY:
- Loads IMF CPI data containing all 5 countries
- Creates cpiwave: Average monthly CPI during data collection (by country-year)
- Creates cpi2021: Average of 12 monthly CPI values in 2021 (by country)
- Merges both CPI variables into each country's panel datasets
- Handles country-specific panel structures

STRUCTURE:
1. Country-specific configurations (must match harmonization script)
2. Prepare CPI dataset (common for all countries)
3. Create cpiwave dataset (average by country-year)
4. Create cpi2021 dataset (average across 2021 by country)
5. Loop through panel datasets and merge CPI data
====================================================================*/

clear all
set more off

**# ==============================================================================
**# 0. USER CONFIGURATION - SET COUNTRY HERE
**# ==============================================================================

***********************************************
*** CHANGE THIS MACRO TO SELECT COUNTRY   ***
***********************************************
*global country_selection "PER"  
* Options: "PER" (Peru), "ARG" (Argentina), "BRA" (Brazil), "DOM" (Dominican Republic), or "SLV" (El Salvador)
***********************************************

**# ==============================================================================
**# 1. COUNTRY-SPECIFIC CONFIGURATIONS (MUST MATCH HARMONIZATION SCRIPT)
**# ==============================================================================

* Base paths
global wdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team"
global cpi_data "$wdir\Dta"

* Country-specific settings
if "$country_selection" == "PER" {
    global current_country "Peru"
    global current_iso "PER"
    global output_data "$wdir\Dta\PER"
    
    * Peru panel combinations (must match harmonization)
    local combo1 "2019 2021"
    local combo2 "2021 2022"
    local combo3 "2022 2023"
    local combo4 "2019 2023"
    local n_combos = 4
}
else if "$country_selection" == "ARG" {
    global current_country "Argentina"
    global current_iso "ARG"
    global output_data "$wdir\Dta\ARG"
    
    * Argentina panel combinations (must match harmonization)
    local combo1 "2016 2017"
    local combo2 "2017 2018"
    local combo3 "2018 2019"
    local combo4 "2019 2020"
    local combo5 "2020 2021"
    local combo6 "2021 2022"
    local combo7 "2022 2023"
    local combo8 "2023 2024"
    local n_combos = 8
}
else if "$country_selection" == "BRA" {
    global current_country "Brazil"
    global current_iso "BRA"
    global output_data "$wdir\Dta\BRA"
    
    * Brazil panel combinations (must match harmonization)
    local combo1 "2022 2023"
    local n_combos = 1
}
else if "$country_selection" == "DOM" {
    global current_country "Dominican Republic"
    global current_iso "DOM"
    global output_data "$wdir\Dta\DOM"
    
    * Dominican Republic panel combinations (must match harmonization)
    local combo1 "2017 2018"
    local combo2 "2018 2019"
    local combo3 "2019 2020"
    local combo4 "2020 2021"
    local combo5 "2021 2022"
    local combo6 "2022 2023"
    local n_combos = 6
}
else if "$country_selection" == "SLV" {
    global current_country "El Salvador"
    global current_iso "SLV"
    global output_data "$wdir\Dta\SLV"
    
    * El Salvador panel combinations (must match harmonization)
    *local combo1 "2021 2022"
    local combo1 "2022 2023"
    local n_combos = 1
}
else {
    noi di as error "ERROR: Invalid country_selection. Must be 'PER', 'ARG', 'BRA', 'DOM', or 'SLV'"
    noi di as error "Current value: $country_selection"
    exit 198
}

noi di ""
noi di "==============================================================================="
noi di "=== ADDING CPI DATA TO HARMONIZED PANEL DATASETS ==="
noi di "==============================================================================="
noi di "Country Selected: $current_country (ISO: $current_iso)"
noi di "Processing `n_combos' panel dataset(s)"
noi di "Output directory: $output_data"
noi di "==============================================================================="
noi di ""

**# ==============================================================================
**# 2. PREPARE CPI DATASET (COMMON FOR ALL COUNTRIES)
**# ==============================================================================

noi di "Step 1: Preparing CPI dataset (contains all 5 countries)..."

use "$cpi_data/CPI_5_countries.dta", clear

* Check structure
noi di "  Original CPI dataset loaded. Total observations: " _N

* Extract country code from TSNAME (format: "CPI_XXX_...")
gen pais = ""
replace pais = lower(substr(TSNAME, 5, 3))
label var pais "Country code (extracted from TSNAME)"

* Verify country codes extracted
noi di "  Countries found in CPI dataset:"
qui levelsof pais, local(cpi_countries)
foreach c of local cpi_countries {
    qui count if pais == "`c'"
    noi di "    - `c' (`r(N)' observations)"
}

* Check if current country is in CPI data
local country_code = lower("$current_iso")
qui count if pais == "`country_code'"
if r(N) == 0 {
    noi di as error "  ERROR: Country '$current_iso' not found in CPI dataset!"
    noi di as error "  Available countries: `cpi_countries'"
    exit 2000
}
else {
    noi di "  ✓ Current country ($current_iso) found in CPI data (`r(N)' observations)"
}
noi di ""

* Parse DATE field to extract year and month
gen ano = real(substr(DATE, 1, 4))
label var ano "Year (extracted from DATE)"

gen mes = real(substr(DATE, 7, 2))
label var mes "Month (extracted from DATE)"

* Rename VALUE to cpiwave for consistency
rename VALUE cpiwave
label var cpiwave "Monthly CPI value (from IMF data)"

* Keep only necessary variables
keep pais ano mes cpiwave

* Check for duplicates
duplicates report pais ano mes
duplicates drop pais ano mes, force

* Summary statistics for current country
noi di "CPI data summary for $current_iso:"
preserve
keep if pais == "`country_code'"
qui sum ano
noi di "  Year range: " r(min) " - " r(max)
qui sum mes
noi di "  Months per year: 1-12"
qui sum cpiwave
noi di "  CPI value range: " %8.2f r(min) " - " %8.2f r(max)
qui count
noi di "  Total monthly observations: " r(N)
restore
noi di ""

* Save prepared CPI dataset temporarily
tempfile cpi_prepared
save `cpi_prepared', replace

**# ==============================================================================
**# 3. CREATE CPIWAVE DATASET (AVERAGE BY COUNTRY-YEAR)
**# ==============================================================================

noi di "Step 2: Calculating average CPI for each country-year combination..."

use `cpi_prepared', clear

* Calculate average CPI for each year by country
* This accounts for the actual data collection period across the year
collapse (mean) cpiwave_avg=cpiwave (count) n_months=cpiwave, by(pais ano)
rename cpiwave_avg cpiwave
label var cpiwave "Average monthly CPI during data collection year (by country-year)"
label var n_months "Number of months used in wave average"

noi di "  Wave CPI averages calculated for all countries:"
noi di "  Total country-year combinations: " _N

* Show sample for current country
noi di ""
noi di "  Sample for $current_iso:"
local country_code = lower("$current_iso")
list pais ano cpiwave n_months if pais == "`country_code'", ///
    clean noobs separator(0) abbreviate(15)
noi di ""

* Verify completeness (should have 12 months per year)
qui sum n_months
if r(min) < 12 {
    noi di "  WARNING: Some country-years have fewer than 12 months!"
    list pais ano n_months if n_months < 12, clean noobs
    noi di ""
}

* Save cpiwave dataset temporarily
tempfile cpiwave_prepared
save `cpiwave_prepared', replace

**# ==============================================================================
**# 4. CREATE CPI2021 DATASET (AVERAGE ACROSS ALL MONTHS IN 2021 BY COUNTRY)
**# ==============================================================================

noi di "Step 3: Calculating average CPI for 2021 by country..."

use `cpi_prepared', clear

* Keep only 2021 data
keep if ano == 2021

* Check if we have 2021 data
qui count
if r(N) == 0 {
    noi di as error "  ERROR: No 2021 data found in CPI dataset!"
    noi di as error "  Available years:"
    use `cpi_prepared', clear
    tab ano, missing
    exit 2000
}

noi di "  2021 observations found: " r(N)

* Check completeness for current country
local country_code = lower("$current_iso")
qui count if pais == "`country_code'" & ano == 2021
local n_2021_obs = r(N)
noi di "  2021 observations for $current_iso: `n_2021_obs'"
if `n_2021_obs' < 12 {
    noi di "  WARNING: $current_iso has fewer than 12 months in 2021!"
}
else if `n_2021_obs' == 12 {
    noi di "  ✓ $current_iso has complete 2021 data (12 months)"
}

* Calculate average CPI for 2021 by country
collapse (mean) cpi2021=cpiwave (count) n_months=cpiwave, by(pais)
label var cpi2021 "Average monthly CPI in 2021 (mean across all 12 months)"
label var n_months "Number of months used in 2021 average"

noi di ""
noi di "  2021 CPI averages calculated for all countries:"
list pais cpi2021 n_months, clean noobs separator(0) abbreviate(15)

* Display value for current country
qui sum cpi2021 if pais == "`country_code'"
if r(N) > 0 {
    noi di ""
    noi di "  $current_iso cpi2021 value: " %8.2f r(mean)
}
else {
    noi di as error "  ERROR: No 2021 average calculated for $current_iso!"
}
noi di ""

* Save cpi2021 dataset temporarily
tempfile cpi2021_prepared
save `cpi2021_prepared', replace

**# ==============================================================================
**# 5. LOOP THROUGH PANEL DATASETS AND MERGE CPI DATA
**# ==============================================================================

noi di "==============================================================================="
noi di "Step 4: Merging CPI data with $current_country panel datasets..."
noi di "==============================================================================="
noi di ""

* Country code for merging (lowercase to match CPI data - SEDLAC standard)
local country_code = lower("$current_iso")

forvalues i = 1/`n_combos' {
    
    * Parse the year combination
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    
    noi di "Processing: 01_${current_iso}_`t0'-`t1'_panel.dta"
    
    * Check if file exists
    cap confirm file "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta"
    if _rc {
        noi di as error "  ERROR: File not found!"
        noi di as error "  Expected: $output_data/01_${current_iso}_`t0'-`t1'_panel.dta"
        noi di as error "  Skipping this panel..."
        noi di ""
        continue
    }
    
    * Load panel dataset
    use "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", clear
    
    * Store original number of observations
    local n_before = _N
    
    * Verify merge keys exist
    cap confirm variable pais ano
    if _rc {
        noi di as error "  ERROR: Required merge variables (pais, ano) not found!"
        noi di as error "  Cannot merge CPI data. Skipping this dataset."
        noi di ""
        continue
    }
    
    * Display dataset country information (informative, not blocking)
    qui levelsof pais, local(dataset_countries) clean
    noi di "  Dataset country code: `dataset_countries'"
    noi di "  Expected country code: `country_code'"
    
    * Count number of unique countries (should be 1)
    local n_countries : word count `dataset_countries'
    if `n_countries' > 1 {
        noi di as error "  WARNING: Multiple countries found in dataset!"
        noi di as error "  This is unexpected. Proceeding with merge but verify results."
    }
    
    **# -------------------------------------------------------------------------
    **# 5.1 MERGE CPIWAVE (constant within country-year)
    **# -------------------------------------------------------------------------
    
    noi di ""
    noi di "  [A] Merging cpiwave (average CPI by country-year)..."
    noi di "    Before merge: `n_before' observations"
    
    * Check if cpiwave already exists and drop it
    cap confirm variable cpiwave
    if !_rc {
        qui count if !missing(cpiwave)
        if r(N) > 0 {
            noi di "    Note: Existing cpiwave values will be replaced"
        }
        drop cpiwave
    }
    
    * Perform merge for cpiwave (on pais + ano)
    merge m:1 pais ano using `cpiwave_prepared', ///
        keepusing(cpiwave n_months) ///
        gen(_merge_cpiwave)
    
    * Check merge results
    qui count if _merge_cpiwave == 1
    local n_master_only = r(N)
    qui count if _merge_cpiwave == 3
    local n_matched = r(N)
    qui count if _merge_cpiwave == 2
    local n_using_only = r(N)
    
    noi di "    Merge results:"
    noi di "      Master only (no CPI match): `n_master_only'"
    noi di "      Matched: `n_matched'"
    if `n_using_only' > 0 {
        noi di "      Using only (CPI years not in panel): `n_using_only' [dropped]"
    }
    
    * Warning if many observations lack CPI data
    if `n_master_only' > 0 {
        local pct_missing = (`n_master_only' / `n_before') * 100
        if `pct_missing' > 5 {
            noi di "    WARNING: " %5.2f `pct_missing' "% of observations lack cpiwave data!"
            * Show which country-years are missing
            preserve
            keep if _merge_cpiwave == 1
            contract pais ano
            noi di "    Missing CPI for these country-years:"
            list pais ano, clean noobs abbreviate(15)
            restore
        }
    }
    
    * Keep only observations from master dataset
    keep if _merge_cpiwave != 2
    drop _merge_cpiwave n_months
    
    * Verify cpiwave coverage
    qui count if !missing(cpiwave)
    local n_with_cpiwave = r(N)
    local pct_with_cpiwave = (`n_with_cpiwave' / _N) * 100
    noi di "    ✓ After merge: `n_with_cpiwave' observations with cpiwave (" %5.2f `pct_with_cpiwave' "%)"
    
    * Display cpiwave summary for this panel
    qui sum cpiwave if ano == `t0', meanonly
    if r(N) > 0 {
        noi di "      Year `t0' average CPI: " %8.2f r(mean)
    }
    qui sum cpiwave if ano == `t1', meanonly
    if r(N) > 0 {
        noi di "      Year `t1' average CPI: " %8.2f r(mean)
    }
    
    **# -------------------------------------------------------------------------
    **# 5.2 MERGE CPI2021 (constant within country)
    **# -------------------------------------------------------------------------
    
    noi di ""
    noi di "  [B] Merging cpi2021 (2021 average by country)..."
    
    * Check if cpi2021 already exists and drop it
    cap confirm variable cpi2021
    if !_rc {
        qui count if !missing(cpi2021)
        if r(N) > 0 {
            noi di "    Note: Existing cpi2021 values will be replaced"
        }
        drop cpi2021
    }
    
    * Perform merge for cpi2021 (on pais only)
    merge m:1 pais using `cpi2021_prepared', ///
        keepusing(cpi2021 n_months) ///
        gen(_merge_cpi2021)
    
    * Check merge results
    qui count if _merge_cpi2021 == 1
    local n_master_only_2021 = r(N)
    qui count if _merge_cpi2021 == 3
    local n_matched_2021 = r(N)
    
    noi di "    Merge results:"
    noi di "      Master only (no 2021 average): `n_master_only_2021'"
    noi di "      Matched: `n_matched_2021'"
    
    * Warning if observations lack cpi2021
    if `n_master_only_2021' > 0 {
        noi di as error "    ERROR: Failed to merge cpi2021!"
        noi di as error "    This country may not be in the 2021 CPI dataset."
        noi di as error "    Check CPI_5_countries.dta for country: `country_code'"
    }
    
    * Keep only observations from master dataset
    keep if _merge_cpi2021 != 2
    drop _merge_cpi2021 n_months
    
    * Verify cpi2021 coverage and display value
    qui count if !missing(cpi2021)
    local n_with_cpi2021 = r(N)
    local pct_with_cpi2021 = (`n_with_cpi2021' / _N) * 100
    noi di "    ✓ After merge: `n_with_cpi2021' observations with cpi2021 (" %5.2f `pct_with_cpi2021' "%)"
    
    qui sum cpi2021, meanonly
    if r(N) > 0 {
        noi di "      ${current_iso} cpi2021 value: " %8.2f r(mean) " (constant for all observations)"
    }
    
	**# -------------------------------------------------------------------------
    **# 5.3 VERIFY DATA INTEGRITY AND SAVE
    **# -------------------------------------------------------------------------
    
    noi di ""
    noi di "  [C] Final verification and save..."
    
    * Verify both CPI variables exist and have reasonable coverage
    qui count
    local n_total = r(N)
    qui count if !missing(cpiwave) & !missing(cpi2021)
    local n_both = r(N)
    local pct_both = (`n_both' / `n_total') * 100
    
    noi di "    Total observations: `n_total'"
    noi di "    Observations with both CPI variables: `n_both' (" %5.2f `pct_both' "%)"
    
    * Verify observations match expected count
    if `n_total' != `n_before' {
        noi di as error "    WARNING: Observation count changed during merge!"
        noi di as error "    Before: `n_before' | After: `n_total'"
    }
    
    * Display summary statistics for CPI variables
    qui sum cpiwave, detail
    if r(N) > 0 {
        noi di "    cpiwave: min=" %8.2f r(min) " | max=" %8.2f r(max) " | mean=" %8.2f r(mean)
    }
    else {
        noi di as error "    ERROR: No valid cpiwave values after merge!"
    }
    
    qui sum cpi2021, detail
    if r(N) > 0 {
        noi di "    cpi2021: " %8.2f r(mean) " (constant across all obs)"
    }
    else {
        noi di as error "    ERROR: No valid cpi2021 values after merge!"
    }
    
    * Quick verification using simpler approach (no egen needed)
    * Check unique values per year for cpiwave
    preserve
    collapse (mean) cpiwave_check=cpiwave (count) n=cpiwave, by(ano)
    qui count
    local n_years = r(N)
    noi di "    ✓ cpiwave has `n_years' distinct year(s) as expected"
    restore
    
    * Check that cpi2021 has only one unique value
    qui tab cpi2021
    if r(r) == 1 {
        noi di "    ✓ cpi2021 is constant across all observations (as expected)"
    }
    else {
        noi di as error "    WARNING: cpi2021 has " r(r) " distinct values (should be 1!)"
    }
    
    * Add notes about CPI merge
    note cpiwave: Updated with IMF CPI data on $S_DATE
    note cpiwave: Average monthly CPI during data collection year (by country-year)
    note cpiwave: Merged on country (pais) and year (ano) - constant within country-year
    note cpiwave: Source: CPI_5_countries.dta
    
    note cpi2021: Updated with IMF CPI data on $S_DATE
    note cpi2021: Average of all 12 monthly CPI values in 2021 by country
    note cpi2021: Merged on country (pais) only - constant within country
    note cpi2021: Used as reference year for PPP conversions
    note cpi2021: Source: CPI_5_countries.dta
    
    * Save updated dataset (overwrites original)
    save "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", replace
    noi di "    ✓ Saved updated dataset"
    noi di ""
    noi di "  " _dup(75) "-"
    noi di ""
}

**# ==============================================================================
**# 6. FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "=== CPI MERGE COMPLETED SUCCESSFULLY ==="
noi di "==============================================================================="
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
    noi di "  ✓ 01_${current_iso}_`t0'-`t1'_panel.dta"
}
noi di ""
noi di "Variables added/updated:"
noi di "  • cpiwave: Wave-level average CPI (by country-year)"
noi di "    - Varies by year within the panel"
noi di "    - Constant within each country-year"
noi di "    - Used for temporal price adjustments"
noi di ""
noi di "  • cpi2021: 2021 reference CPI (by country)"
noi di "    - Average of 12 monthly values in 2021"
noi di "    - Constant across all observations for this country"
noi di "    - Used as denominator for PPP conversions to 2021 base"
noi di ""
noi di "Source: CPI_5_countries.dta (IMF Consumer Price Index data)"
noi di "==============================================================================="
noi di ""