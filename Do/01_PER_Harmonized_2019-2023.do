/*====================================================================
Project: Harmonizing LAC HH Surveys with Global Syntax
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/11/06
Last modification: 	2025/11/06
====================================================================
PURPOSE: This script harmonizes panel household survey data from LAC 
         countries to align with global team variable naming conventions
         and structure. Creates separate datasets for each 1-year panel
         combination.

METHODOLOGY:
- Maintains all original variables for error tracking
- Creates harmonized variables following global standards
- Generates separate datasets for each consecutive year panel
- Flexible structure allows easy adaptation for different countries

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
**# 0. SETUP AND COUNTRY-SPECIFIC CONFIGURATIONS
**# ==============================================================================

* Define paths
global wdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team"
global input_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2025\2021PPP\Vulnerability line\Data\Peru"
global output_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta"

* Create output directory if it doesn't exist
cap mkdir "$output_data"

* Country-specific settings
global current_country "Peru"
global current_iso "PER"

* Define year combinations based on country
if "$current_country" == "Peru" {
    * Peru has 2015-2019 and 2019-2023 panels (without 2020) We are using only the second one for now
    * Define all 1-year consecutive panels + 2019-2021 special panel
    * IMPORTANT: No commas - each pair is a separate element
    local combo1 "2019 2021"
    local combo2 "2021 2022"
    local combo3 "2022 2023"
    local n_combos = 3
    global input_file "01_Enaho_SEDLAC_Panel_2019_2023.dta"
}
else if "$current_country" == "Brazil" {
    * Brazil has 2016-2019 and 2022-2023 panels
    local year_combos "2016 2017, 2017 2018, 2018 2019, 2022 2023"
    local n_combos = 4
    global input_file "" // To be specified
}

* ISIC classification note for country-specific adjustments
global isic_revision "3" // Peru uses ISIC Rev 3; adjust for other countries

noi di ""
noi di "=== HARMONIZATION OF PANEL DATA TO GLOBAL STANDARDS ==="
noi di "Country: $current_country (ISO: $current_iso)"
noi di "Processing `n_combos' one-year panel combinations"
noi di ""

**# ==============================================================================
**# 1. LOAD AND PREPARE BASE DATA
**# ==============================================================================

use "$input_data/$input_file", clear

noi di "Original dataset loaded. Total observations: " _N
noi di ""

**# ==============================================================================
**# 2. CREATE HARMONIZED IDENTIFIERS AND BASIC VARIABLES
**# ==============================================================================

* Country identifiers
rename pais country
label var country "Country name"

rename pais_ocaux cnt
label var cnt "Country ISO 3-letter code"

* Household and individual identifiers
rename idp_h household_id
label var household_id "Household panel identifier (original: idp_h)"

rename idp_i indiv_id
label var indiv_id "Individual panel identifier (original: idp_i)"

* Wave number - sequential starting from first year in data
qui sum ano
local first_year = r(min)
gen wave = ano - `first_year' + 1
label var wave "Wave number (sequential from first survey year)"

* Note: 'time' variable will be created within each panel loop (0 = initial, 1 = final)

**# ==============================================================================
**# 3. CREATE HARMONIZED WEIGHTS
**# ==============================================================================

* Individual weight (already exists as pondera)
rename pondera iweight
label var iweight "Individual weight (original: pondera)"

* Household weight - use household head's individual weight
sort household_id ano indiv_id
by household_id ano: egen hweight = max(iweight * (relacion == 1))
label var hweight "Household weight (household head's individual weight)"

**# ==============================================================================
**# 4. CREATE HARMONIZED WELFARE VARIABLES
**# ==============================================================================

* Welfare aggregate in USD 2021 PPP
rename ipcf_ppp21 welfare
label var welfare "Annual income per capita, USD 2021 PPP (original: ipcf_ppp21)"
note welfare: Type: Income | Spatially deflated: Yes (urban/rural) | Per capita: Yes

* Nominal welfare aggregate in local currency
rename ipcf welfarenom
label var welfarenom "Annual income per capita, local currency (original: ipcf)"

* CPI and PPP variables
gen cpiwave = .
label var cpiwave "Average monthly CPI during data collection (to be filled)"

gen cpi2021 = .
label var cpi2021 "Average monthly CPI in 2021 (to be filled)"

rename ppp21 ppp2021
label var ppp2021 "PPP conversion factor 2021, LCU per int'l dollar (original: ppp21)"

**# ==============================================================================
**# 5. CREATE HARMONIZED EMPLOYMENT VARIABLES
**# ==============================================================================

**# 5.1 Employment status

* Basic employment indicator
gen employed=ocupado
label var employed "Employed (1=Yes, 0=No) (original: ocupado)"

* Detailed employment status
gen empstat = .
replace empstat = 0 if pea == 0  // Inactive
replace empstat = 1 if ocupado == 0 & pea == 1  // Unemployed
replace empstat = 2 if ocupado == 1  // Employed
label var empstat "Employment status (0=Inactive, 1=Unemployed, 2=Employed)"
label define empstat_lbl 0 "Inactive" 1 "Unemployed" 2 "Employed"
label values empstat empstat_lbl

**# 5.2 Employment type

* Job relationship
gen emptype = .
replace emptype = 4 if relab == 1  // Employer
replace emptype = 3 if relab == 2  // Salaried
replace emptype = 2 if relab == 3  // Self-employed
replace emptype = 1 if relab == 4  // Unpaid worker
label var emptype "Job relationship (1=Unpaid, 2=Self-employed, 3=Salaried, 4=Employer)"
label define emptype_lbl 1 "Unpaid Worker" 2 "Self-Employed" 3 "Salaried" 4 "Employer"
label values emptype emptype_lbl

**# 5.3 Wages and earnings

* Rename existing wage variable and create placeholder for annual wage
cap rename wage hourly_wage_lc
cap label var hourly_wage_lc "Hourly wage in local currency (original: wage)"

gen wage = .
label var wage "Annual wage of salaried employees, USD 2021 PPP (to be filled)"

gen earnings = .
label var earnings "Annual labor earnings of self-employed/employers, USD 2021 PPP (to be filled)"

**# 5.4 Occupation codes (ISCO-08)

* 4-digit, 3-digit, 2-digit codes (already exist)
rename isco08_4d isco_4d
label var isco_4d "ISCO-08 occupation code, 4-digit (original: isco08_4d)"

rename isco08_3d isco_3d
label var isco_3d "ISCO-08 occupation code, 3-digit (original: isco08_3d)"

rename isco08_2d isco_2d
label var isco_2d "ISCO-08 occupation code, 2-digit (original: isco08_2d)"

* 1-digit code - extract from 2-digit, accounting for leading zeros
gen isco_1d = .
* For 2-digit codes >= 10, take first digit
replace isco_1d = floor(isco_2d / 10) if isco_2d >= 10 & !missing(isco_2d)
* For 2-digit codes < 10, the code is 0X, so 1-digit is 0
replace isco_1d = 0 if isco_2d < 10 & isco_2d >= 0 & !missing(isco_2d)
label var isco_1d "ISCO-08 occupation code, 1-digit (derived from isco_2d)"

**# 5.5 Occupational group and skill level

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
* Note: Occupational code 0 (Armed Forces) doesn't fit neatly into skill categories
* Leave as missing per instructions to think carefully about classification
gen skill_group = .
replace skill_group = 3 if inrange(occup, 1, 3)  // High skill: Managers, Professionals, Technicians
replace skill_group = 2 if inrange(occup, 4, 8)  // Medium skill: Clerical through Operators
replace skill_group = 1 if occup == 9  // Low skill: Elementary occupations
* occup == 0 (Armed Forces) left as missing
label var skill_group "Skill level (1=Low, 2=Medium, 3=High)"
label define skill_lbl 1 "Low skill" 2 "Medium skill" 3 "High skill"
label values skill_group skill_lbl
note skill_group: Based on ISCO 1-digit. Armed Forces (occup=0) coded as missing.

**# 5.6 Formality indicators for salaried workers

* Written contract
rename contrato contract
label var contract "Has written contract (original: contrato)"

* Pension contribution
rename djubila socsec
label var socsec "Contributes to pension (original: djubila)"

* Health insurance
rename dsegsale health
label var health "Contributes to health insurance (original: dsegsale)"

**# 5.7 Sector of economic activity

* ISIC 1-digit - extract from 4-digit sector_orig
* Account for leading zeros (3-digit codes with leading 0 missing)
gen isic_1d = .
* For 4-digit codes >= 1000, take first digit
replace isic_1d = floor(sector_orig / 1000) if sector_orig >= 1000 & !missing(sector_orig)
* For codes < 1000, the leading digit is 0
replace isic_1d = 0 if sector_orig < 1000 & sector_orig >= 0 & !missing(sector_orig)
label var isic_1d "ISIC 1-digit (derived from sector_orig 4-digit)"
note isic_1d: Derived from sector_orig (4-digit ISIC Rev $isic_revision)

* Rename current sector variable
rename sector ten_sectors
label var ten_sectors "Original 10-sector classification (original: sector)"

* Create new 3-category sector variable based on ISIC 1-digit
* Based on the frequency table provided:
* ISIC 1 (Agriculture, hunting, forestry) + ISIC 2 (Fishing) = Agriculture
* ISIC 3 (Mining) + ISIC 4 (Manufacturing) + ISIC 5 (Utilities) + ISIC 6 (Construction) = Industry  
* ISIC 7-17 (All service sectors) = Services
gen sector = .
replace sector = 1 if inlist(isic_1d, 1, 2)  // Agriculture (includes fishing)
replace sector = 2 if inlist(isic_1d, 3, 4, 5, 6)  // Industry (mining, manufacturing, utilities, construction)
replace sector = 3 if inrange(isic_1d, 7, 17)  // Services (all remaining)
label var sector "Broad economic sector (1=Agriculture, 2=Industry, 3=Services)"
label define sector_lbl 1 "Agriculture" 2 "Industry" 3 "Services"
label values sector sector_lbl

**# ==============================================================================
**# 6. CREATE HARMONIZED DEMOGRAPHIC VARIABLES
**# ==============================================================================

**# 6.1 Geographic location

* Urban/rural
rename urbano urban
label var urban "Urban residence (1=Urban, 0=Rural) (original: urbano)"

**# 6.2 Household relationship

* Create three dummy variables based on relationship to household head
gen head = (relacion == 1)
label var head "Household head (1=Yes, 0=No)"

gen spouse = (relacion == 2)
label var spouse "Spouse/Partner (1=Yes, 0=No)"

gen others = inlist(relacion, 3, 4, 5, 6)
label var others "Other household member (1=Yes, 0=No)"

**# 6.3 Individual characteristics

* Age - capped at 100
rename edad age
replace age = 100 if age > 100 & !missing(age)
label var age "Age in years, capped at 100 (original: edad)"

* Sex - create female from hombre (which is 1 for male)
gen female = 1 - hombre
replace female = . if missing(hombre)
label var female "Female (1=Female, 0=Male) (original: hombre inverted)"

* Educational attainment - add 1 to nivel to match requested categories
gen educat7 = nivel + 1 if !missing(nivel)
label var educat7 "Educational attainment (1-7 scale) (original: nivel + 1)"
label define educat7_lbl 1 "Never attended" 2 "Incomplete primary" ///
    3 "Complete primary" 4 "Incomplete secondary" 5 "Complete secondary" ///
    6 "Incomplete tertiary" 7 "Complete tertiary"
label values educat7 educat7_lbl

**# ==============================================================================
**# 7. LOOP THROUGH YEAR COMBINATIONS AND CREATE SEPARATE PANEL DATASETS
**# ==============================================================================

noi di ""
noi di "=== CREATING SEPARATE DATASETS FOR EACH ONE-YEAR PANEL ==="
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
    
    * Keep only observations from these two years
    keep if ano == `t0' | ano == `t1'
    
    * Identify balanced panel members (appear in both years)
    sort indiv_id ano
    by indiv_id: egen has_t0 = max(ano == `t0')
    by indiv_id: egen has_t1 = max(ano == `t1')
    gen balanced_panel = (has_t0 == 1 & has_t1 == 1)
    label var balanced_panel "Balanced panel indicator (1=Appears in both waves)"
    
    * Create time variable (0 = initial wave, 1 = final wave)
    gen time = (ano == `t1')
    label var time "Time period (0=Initial wave, 1=Final wave)"
    label define time_lbl_`i' 0 "Initial wave (`t0')" 1 "Final wave (`t1')"
    label values time time_lbl_`i'
    
    * Count individuals and households
    qui count if balanced_panel == 1 & time == 0
    local n_individuals = r(N)
    qui tab household_id if balanced_panel == 1 & time == 0
    local n_households = r(r)
    
    noi di "  Balanced panel: `n_individuals' individuals in `n_households' households"
    
    * Add dataset notes
    note: Harmonized panel dataset for $current_country (`t0'-`t1')
    note: Harmonized to global team standards on $S_DATE
    note: Original variables maintained alongside harmonized variables
    note: Balanced panel includes only individuals present in both `t0' and `t1'
    
    * Save dataset
    save "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", replace
    noi di "  Saved: 01_${current_iso}_`t0'-`t1'_panel.dta"
    noi di ""
    
    restore
}

**# ==============================================================================
**# 8. FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "=== HARMONIZATION COMPLETED ==="
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
noi di "All original variables have been maintained for error tracking."
noi di "Harmonized variables follow global team naming conventions."
noi di ""

* Display variable mapping summary
noi di "KEY VARIABLE MAPPINGS:"
noi di "======================"
noi di "household_id ← idp_h"
noi di "indiv_id ← idp_i"
noi di "welfare ← ipcf_ppp21"
noi di "welfarenom ← ipcf"
noi di "employed ← ocupado"
noi di "urban ← urbano"
noi di "age ← edad (capped at 100)"
noi di "female ← 1 - hombre"
noi di "educat7 ← nivel + 1"
noi di ""
noi di "For full variable documentation, see dataset notes and labels."
noi di ""