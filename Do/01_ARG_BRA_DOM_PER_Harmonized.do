/*====================================================================
Project: Harmonizing LAC HH Surveys with Global Syntax
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/12/02
Last modification: 	2025/12/02
====================================================================
PURPOSE: This script harmonizes panel household survey data from LAC 
         countries to align with global team variable naming conventions
         and structure. Creates separate datasets for each panel
         combination (1-year panels + full panel where applicable).

METHODOLOGY:
- Preserves ALL original variables for backward compatibility
- Creates harmonized variables following global standards
- Generates separate datasets for each consecutive year panel
- Flexible structure allows easy adaptation for different countries

KEY CHANGES FROM ORIGINAL:
- All original variables are preserved (no renaming, only new variable creation)
- Single script handles multiple countries via country_selection macro
- Peru: Includes full 2019-2023 panel in addition to 1-year panels
- Argentina: Only 1-year consecutive panels
- Brazil: 2022-2023 panel (visit 1 in 2022, visit 5 in 2023)
- Dominican Republic: 1-year consecutive panels 2017-2023
- Maintains compatibility with both old and new variable naming conventions
- wage: Total annual wage of salaried employees (USD 2021 PPP)
- earnings: Annual labor earnings of self-employed/employers (USD 2021 PPP)
- cpiwave: Average monthly CPI during data collection
- cpi2021: Average monthly CPI in 2021

STRUCTURE:
1. Setup and country-specific configurations
2. Load and prepare data
3. Create harmonized identifiers and weights
4. Create harmonized welfare variables
5. Create harmonized employment variables
6. Create harmonized demographic variables
7. Loop through year combinations and save separate datasets
*=================================================================*/

clear all
set more off

**# ==============================================================================
**# 0. USER CONFIGURATION - SET COUNTRY HERE
**# ==============================================================================

***********************************************
*** CHANGE THIS MACRO TO SELECT COUNTRY   ***
***********************************************
global country_selection "DOM"  
* Options: "PER" (Peru), "ARG" (Argentina), "BRA" (Brazil), or "DOM" (Dominican Republic)
***********************************************

**# ==============================================================================
**# 1. COUNTRY-SPECIFIC CONFIGURATIONS
**# ==============================================================================

* Base paths
global wdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team"

* Country-specific settings
if "$country_selection" == "PER" {
    global current_country "Peru"
    global current_iso "PER"
    global input_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2025\2021PPP\Vulnerability line\Data\Raw\Peru"
    global output_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\PER"
    global input_file "01_Enaho_SEDLAC_Panel_2019_2023.dta"
    
    * Peru has 2019-2023 panel (without 2020)
    * Define all 1-year consecutive panels + full 2019-2023 panel
    local combo1 "2019 2021"
    local combo2 "2021 2022"
    local combo3 "2022 2023"
    local combo4 "2019 2023"
    local n_combos = 4
}
else if "$country_selection" == "ARG" {
    global current_country "Argentina"
    global current_iso "ARG"
    global input_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2025\2021PPP\Vulnerability line\Data\Raw\Argentina"
    global output_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\ARG"
    global input_file "01_ARG_SEDLAC_Panel_2016_2024.dta"
    
    * Argentina has consecutive years 2016-2024
    * Define all 1-year consecutive panels (no long panel)
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
    global input_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2025\2021PPP\Vulnerability line\Data\Raw\Brazil"
    global output_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\BRA"
    global input_file "09_BRA_PNAD_Harmonized_2022-2023.dta"
    
    * Brazil has 2022-2023 panel
    * Note: has_22 and has_23 variables already account for correct visits
    * (visit 1 in 2022, visit 5 in 2023)
    local combo1 "2022 2023"
    local n_combos = 1
}
else if "$country_selection" == "DOM" {
    global current_country "Dominican Republic"
    global current_iso "DOM"
    global input_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2025\2021PPP\Vulnerability line\Data\Raw\DR"
    global output_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\DOM"
    global input_file "01_DR_SEDLAC_Panel_2016_2023.dta"
    
    * Dominican Republic has consecutive years 2017-2023
    * Define all 1-year consecutive panels
    local combo1 "2017 2018"
    local combo2 "2018 2019"
    local combo3 "2019 2020"
    local combo4 "2020 2021"
    local combo5 "2021 2022"
    local combo6 "2022 2023"
    local n_combos = 6
}
else {
    noi di as error "ERROR: Invalid country_selection. Must be 'PER', 'ARG', 'BRA', or 'DOM'"
    noi di as error "Current value: $country_selection"
    exit 198
}

* Create output directory if it doesn't exist
cap mkdir "$output_data"

noi di ""
noi di "==============================================================================="
noi di "=== HARMONIZATION OF PANEL DATA TO GLOBAL STANDARDS ==="
noi di "==============================================================================="
noi di "Country Selected: $current_country (ISO: $current_iso)"
noi di "Processing `n_combos' panel combinations"
noi di "Input file: $input_file"
noi di "Output directory: $output_data"
noi di "==============================================================================="
noi di ""

**# ==============================================================================
**# 2. LOAD AND PREPARE BASE DATA
**# ==============================================================================

use "$input_data/$input_file", clear

noi di "Original dataset loaded. Total observations: " _N
noi di ""

**# ==============================================================================
**# 3. CREATE HARMONIZED IDENTIFIERS AND BASIC VARIABLES
**# ==============================================================================

* Country identifiers (preserve originals)
gen country = pais
label var country "Country name (original: pais)"

gen cnt = pais
label var cnt "Country ISO 3-letter code (original: pais_ocaux)"

* Household and individual identifiers (preserve originals)
cap drop household_id
gen household_id = idp_h
label var household_id "Household panel identifier (original: idp_h)"

gen indiv_id = idp_i
label var indiv_id "Individual panel identifier (original: idp_i)"

* Wave number - sequential starting from first year in data
qui sum ano
local first_year = r(min)
gen wave = ano - `first_year' + 1
label var wave "Wave number (sequential from first survey year)"

**# ==============================================================================
**# 4. CREATE HARMONIZED WEIGHTS
**# ==============================================================================

* Individual weight (preserve original)
gen iweight = pondera
label var iweight "Individual weight (original: pondera)"

* Household weight - use household head's individual weight
sort household_id ano indiv_id
by household_id ano: egen hweight = max(iweight * (relacion == 1))
label var hweight "Household weight (household head's individual weight)"

**# ==============================================================================
**# 5. CREATE HARMONIZED WELFARE VARIABLES
**# ==============================================================================

* Welfare aggregate in USD 2021 PPP (preserve original)
gen welfare = ipcf_ppp21*12 //convert to annual terms
label var welfare "Annual income per capita, USD 2021 PPP (original: ipcf_ppp21)"
note welfare: Type: Income | Spatially deflated: Yes (urban/rural) | Per capita: Yes

* Nominal welfare aggregate in local currency (preserve original)
gen welfarenom = ipcf*12
label var welfarenom "Annual income per capita, local currency (original: ipcf)"

* CPI and PPP variables
gen cpiwave = .
label var cpiwave "Average monthly CPI during data collection"

gen cpi2021 = .
label var cpi2021 "Average monthly CPI in 2021"

* PPP conversion factor (preserve original)
gen ppp2021 = ppp21
label var ppp2021 "PPP conversion factor 2021, LCU per int'l dollar (original: ppp21)"

**# ==============================================================================
**# 6. CREATE HARMONIZED EMPLOYMENT VARIABLES
**# ==============================================================================

**# 6.1 Employment status

* Basic employment indicator (preserve original)
gen employed = ocupado
label var employed "Employed (1=Yes, 0=No) (original: ocupado)"

* Detailed employment status
gen empstat = .
replace empstat = 0 if pea == 0  // Inactive
replace empstat = 1 if ocupado == 0 & pea == 1  // Unemployed
replace empstat = 2 if ocupado == 1  // Employed
label var empstat "Employment status (0=Inactive, 1=Unemployed, 2=Employed)"
label define empstat_lbl 0 "Inactive" 1 "Unemployed" 2 "Employed"
label values empstat empstat_lbl

**# 6.2 Employment type

* Job relationship
gen emptype = .
replace emptype = 4 if relab == 1  // Employer
replace emptype = 3 if relab == 2  // Salaried
replace emptype = 2 if relab == 3  // Self-employed
replace emptype = 1 if relab == 4  // Unpaid worker
label var emptype "Job relationship (1=Unpaid, 2=Self-employed, 3=Salaried, 4=Employer)"
label define emptype_lbl 1 "Unpaid Worker" 2 "Self-Employed" 3 "Salaried" 4 "Employer"
label values emptype emptype_lbl

**# 6.3 Wages and earnings

* Rename original hourly wage variable from SEDLAC
cap confirm variable wage
if !_rc {
    gen hourly_wage_lc = wage
    label var hourly_wage_lc "Hourly wage in local currency (originally: wage in SEDLAC)"
    drop wage
}

* Create placeholder for annual wage (to be populated later)
gen wage = .
label var wage "Total annual wage of salaried employees, USD 2021 PPP"

* Create placeholder for annual earnings (to be populated later)
gen earnings = .
label var earnings "Annual labor earnings of self-employed/employers, USD 2021 PPP"

**# 6.4 Occupation codes (ISCO-08)

* Country-specific handling of ISCO variables
if "$country_selection" == "PER" {
    * Peru has all three ISCO detail levels
    gen isco_4d = isco08_4d
    label var isco_4d "ISCO-08 occupation code, 4-digit (original: isco08_4d)"
    
    gen isco_3d = isco08_3d
    label var isco_3d "ISCO-08 occupation code, 3-digit (original: isco08_3d)"
    
    gen isco_2d = isco08_2d
    label var isco_2d "ISCO-08 occupation code, 2-digit (original: isco08_2d)"
}
else if "$country_selection" == "DOM" {
    * Dominican Republic has all three ISCO detail levels
    * isco08_2d is byte (numeric) - use directly
    * isco08_3d and isco08_4d are strings - need to convert
    
    gen isco_2d = isco08_2d
    label var isco_2d "ISCO-08 occupation code, 2-digit (original: isco08_2d)"
    
    destring isco08_3d, gen(isco_3d)
    label var isco_3d "ISCO-08 occupation code, 3-digit (original: isco08_3d)"
    
    destring isco08_4d, gen(isco_4d)
    label var isco_4d "ISCO-08 occupation code, 4-digit (original: isco08_4d)"
}
else if "$country_selection" == "ARG" | "$country_selection" == "BRA" {
    * Argentina and Brazil only have 2-digit ISCO
    gen isco_4d = .
    label var isco_4d "ISCO-08 occupation code, 4-digit (not available for $current_country)"
    
    gen isco_3d = .
    label var isco_3d "ISCO-08 occupation code, 3-digit (not available for $current_country)"
    
    gen isco_2d = isco08_2d
    label var isco_2d "ISCO-08 occupation code, 2-digit (original: isco08_2d)"
}

* 1-digit code - extract from 2-digit
gen isco_1d = .
replace isco_1d = floor(isco_2d / 10) if isco_2d >= 10 & !missing(isco_2d)
replace isco_1d = 0 if isco_2d < 10 & isco_2d >= 0 & !missing(isco_2d)
label var isco_1d "ISCO-08 occupation code, 1-digit (derived from isco_2d)"

**# 6.5 Occupational group and skill level

* Occupational group (same as 1-digit ISCO)
cap drop occup
gen occup = isco_1d
label var occup "Occupational group (0-9, based on ISCO 1-digit)"
label define occup_lbl 0 "Armed Forces" 1 "Managers" 2 "Professionals" ///
    3 "Technicians" 4 "Clerical Support" 5 "Services and Sales" ///
    6 "Skilled Agricultural" 7 "Craft and Related Trades" ///
    8 "Plant/Machine Operators" 9 "Elementary Occupations"
label values occup occup_lbl

* Skill group
gen skill_group = .
replace skill_group = 3 if inrange(occup, 1, 3)  // High skill
replace skill_group = 2 if inrange(occup, 4, 8)  // Medium skill
replace skill_group = 1 if occup == 9  // Low skill
label var skill_group "Skill level (1=Low, 2=Medium, 3=High)"
label define skill_lbl 1 "Low skill" 2 "Medium skill" 3 "High skill"
label values skill_group skill_lbl
note skill_group: Based on ISCO 1-digit. Armed Forces (occup=0) coded as missing.

**# 6.6 Formality indicators for salaried workers (preserve originals)

gen contract = contrato
label var contract "Has written contract (original: contrato)"

gen socsec = djubila
label var socsec "Contributes to pension (original: djubila)"

gen health = dsegsale
label var health "Contributes to health insurance (original: dsegsale)"

**# 6.7 Sector of economic activity

* Handle sector1d string variable for DOM
if "$country_selection" == "DOM" {
    destring sector1d, replace
}

* All countries now use sector1d directly (1-digit ISIC)
gen isic_1d = sector1d
label var isic_1d "ISIC 1-digit (original: sector1d)"

* Preserve original 10-sector variable if it exists
cap confirm variable sector
if !_rc {
    gen ten_sectors = sector
    label var ten_sectors "Original 10-sector classification (original: sector)"
}

* Create new 3-category sector variable based on ISIC 1-digit
* Agriculture: ISIC 1-digit = 1 (Agriculture, hunting, forestry), 2 (Fishing)
* Industry: ISIC 1-digit = 3 (Mining), 4 (Manufacturing), 6 (Construction)
* Services: ISIC 1-digit = 5 (Electricity/gas/water), 7-17 (All service activities)
cap drop sector
gen sector = .
replace sector = 1 if inlist(isic_1d, 1, 2)  // Agriculture and Fishing
replace sector = 2 if inlist(isic_1d, 3, 4, 6)  // Mining, Manufacturing, Construction
replace sector = 3 if isic_1d == 5 | inrange(isic_1d, 7, 17)  // Utilities and all Services
label var sector "Broad economic sector based on ISIC 1-digit"
label define sector_lbl 1 "Agriculture (includes fishing)" ///
    2 "Industry (mining, manufacturing, construction)" ///
    3 "Services (utilities and all service activities)"
label values sector sector_lbl
note sector: Agriculture = ISIC 1-2 | Industry = ISIC 3,4,6 | Services = ISIC 5,7-17

**# ==============================================================================
**# 7. CREATE HARMONIZED DEMOGRAPHIC VARIABLES
**# ==============================================================================

**# 7.1 Geographic location (preserve original)

gen urban = urbano
label var urban "Urban residence (1=Urban, 0=Rural) (original: urbano)"

**# 7.2 Household relationship

* Create dummy variables based on relationship to household head
gen head = (relacion == 1)
label var head "Household head (1=Yes, 0=No)"

gen spouse = (relacion == 2)
label var spouse "Spouse/Partner (1=Yes, 0=No)"

gen others = inlist(relacion, 3, 4, 5, 6)
label var others "Other household member (1=Yes, 0=No)"

**# 7.3 Individual characteristics

* Age - capped at 100 (preserve original)
cap drop age
gen age = edad
replace age = 100 if age > 100 & !missing(age)
label var age "Age in years, capped at 100 (original: edad)"

* Sex - create female from hombre
gen female = 1 - hombre
replace female = . if missing(hombre)
label var female "Female (1=Female, 0=Male) (derived from hombre)"

* Educational attainment
gen educat7 = nivel + 1 if !missing(nivel)
label var educat7 "Educational attainment (1-7 scale) (original: nivel + 1)"
label define educat7_lbl 1 "Never attended" 2 "Incomplete primary" ///
    3 "Complete primary" 4 "Incomplete secondary" 5 "Complete secondary" ///
    6 "Incomplete tertiary" 7 "Complete tertiary"
label values educat7 educat7_lbl

**# ==============================================================================
**# 8. LOOP THROUGH YEAR COMBINATIONS AND CREATE SEPARATE PANEL DATASETS
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "=== CREATING SEPARATE DATASETS FOR EACH PANEL COMBINATION ==="
noi di "==============================================================================="
noi di ""

* Loop through each year combination
forvalues i = 1/`n_combos' {
    
    * Parse the year combination
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    
    noi di "Processing panel: `t0'-`t1'"
    
    * Load fresh copy of harmonized data
    preserve
    
    * Identify and keep balanced panel members (country-specific approach)
    if "$country_selection" == "ARG" {
        * Argentina: Filter using pre-existing has_XX variables (XX = last 2 digits)
        local t0_short = mod(`t0', 100)  // Extract last 2 digits (2016 → 16)
        local t1_short = mod(`t1', 100)  // Extract last 2 digits (2017 → 17)
        
        * Keep individuals who appear in EITHER year
        keep if has_`t0_short' == 1 | has_`t1_short' == 1
        
        * Now keep only observations from these two years
        keep if ano == `t0' | ano == `t1'
        
        * Create balanced panel indicator (appears in BOTH years)
        gen balanced_panel = (has_`t0_short' == 1 & has_`t1_short' == 1)
        label var balanced_panel "Balanced panel indicator (1=Appears in both waves)"
        noi di "  Using pre-existing has_`t0_short' and has_`t1_short' variables"
    }
    else if "$country_selection" == "BRA" | "$country_selection" == "DOM" {
        * Brazil and Dominican Republic: Filter using pre-existing has_XX variables
        local t0_short = mod(`t0', 100)  // Extract last 2 digits
        local t1_short = mod(`t1', 100)  // Extract last 2 digits
        
        * Keep individuals who appear in EITHER year (with correct visits)
        keep if has_`t0_short' == 1 | has_`t1_short' == 1
        
        * Filter to coherent households
        keep if cohh == 1
        
        * Keep only observations from these two years
        keep if ano == `t0' | ano == `t1'
        
        * Create balanced panel indicator (appears in BOTH years)
        gen balanced_panel = (has_`t0_short' == 1 & has_`t1_short' == 1)
        label var balanced_panel "Balanced panel indicator (1=Appears in both waves)"
        noi di "  Using pre-existing has_`t0_short' and has_`t1_short' variables"
        
        if "$country_selection" == "BRA" {
            noi di "  Note: Variables account for correct visits (visit 1 in 2022, visit 5 in 2023)"
        }
    }
    else if "$country_selection" == "PER" {
        * Peru: First keep observations from the two years
        keep if ano == `t0' | ano == `t1'
        
        * Then identify balanced panel members using original approach
        sort indiv_id ano
        by indiv_id: egen has_t0 = max(ano == `t0')
        by indiv_id: egen has_t1 = max(ano == `t1')
        gen balanced_panel = (has_t0 == 1 & has_t1 == 1)
        label var balanced_panel "Balanced panel indicator (1=Appears in both waves)"
    }
    
    * Create time variable (0 = initial wave, 1 = final wave)
    gen time = (ano == `t1')
    label var time "Time period (0=Initial wave, 1=Final wave)"
    label define time_lbl_`i' 0 "Initial wave (`t0')" 1 "Final wave (`t1')"
    label values time time_lbl_`i'
    
	* Count individuals and households
	qui count if balanced_panel == 1 & time == 0
	local n_individuals = r(N)
	tempvar tag
	egen `tag' = tag(household_id) if balanced_panel == 1 & time == 0
	qui count if `tag' == 1
	local n_households = r(N)
    
    noi di "  Balanced panel: `n_individuals' individuals in `n_households' households"
    
    * Add dataset notes
    note: Harmonized panel dataset for $current_country (`t0'-`t1')
    note: Harmonized to global team standards on $S_DATE
    note: Original variables preserved alongside harmonized variables
    note: Balanced panel includes only individuals present in both `t0' and `t1'
    
    * Add Brazil-specific note if applicable
    if "$country_selection" == "BRA" {
        note: Brazil panel matches visit 1 in `t0' with visit 5 in `t1'
    }
    
    * Save dataset
	* Reorder variables: IDs, time, panel status, geography, weights, welfare, demographics
	order idp_i idp_h household_id indiv_id ///
		  ano wave time balanced_panel ///
		  country cnt urban ///
		  iweight hweight ///
		  welfare welfarenom ///
		  employed empstat emptype ///
		  age female head spouse others
    save "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", replace
    noi di "  Saved: 01_${current_iso}_`t0'-`t1'_panel.dta"
    noi di ""
    
    restore
}

**# ==============================================================================
**# 9. FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "=== HARMONIZATION COMPLETED ==="
noi di "==============================================================================="
noi di ""
noi di "Country: $current_country (ISO: $current_iso)"
noi di "Number of panel datasets created: `n_combos'"
noi di "Output location: $output_data"
noi di ""
noi di "Datasets created:"
forvalues i = 1/`n_combos' {
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    noi di "  - 01_${current_iso}_`t0'-`t1'_panel.dta"
}
noi di ""
noi di "All original variables have been preserved."
noi di "Harmonized variables follow global team naming conventions."
if "$country_selection" == "BRA" {
    noi di ""
    noi di "BRAZIL-SPECIFIC NOTE:"
    noi di "Panel matches visit 1 in 2022 with visit 5 in 2023"
    noi di "has_22 and has_23 variables already account for correct visits"
}
noi di "==============================================================================="
noi di ""