/*====================================================================
Project: Labor Market Transitions Analysis using Harmonized LAC Panel Data
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/11/12
Last modification: 	2025/11/12
====================================================================
PURPOSE: This script analyzes labor market transitions using harmonized 
         panel household survey data from LAC countries. It examines
         transitions in employment status, job type, earnings, and skill levels.

METHODOLOGY:
- Analyzes transitions in four labor market dimensions:
  * Employment status (employed vs not working)
  * Employment type (unpaid, self-employed, salaried, employer, not working)
  * Earnings quintiles (Q1-Q5 plus "No earnings")
  * Occupational skill levels (Low, Medium, High, plus "Not working")
- Uses survey weights for population representativeness
- Includes individuals with valid data in at least one period
- Missing values in one period (but non-missing in the other) coded as "Not working"/"No earnings"
- Excludes observations missing in both periods

OUTPUT:
- Excel file with separate sheets for each transition matrix:
  * Summary - Dataset info and methodology notes
  * Employment_Status - Employed vs Not working transitions
  * Employment_Type - Job relationship transitions
  * Earnings_Quintiles - Welfare quintile transitions
  * Skill_Groups - Occupational skill level transitions
  * Each sheet includes weighted and unweighted sample sizes

STRUCTURE:
1. Setup and configuration
2. Load and prepare harmonized panel data
3. Reshape data for transition analysis
4. Employment status transitions
5. Employment type transitions
6. Earnings quintile transitions
7. Skill group transitions
8. Export results to Excel
*=================================================================*/

clear all
set more off
set maxvar 10000

**# ==============================================================================
**# 0. SETUP AND CONFIGURATION
**# ==============================================================================

* Define paths (MODIFY THESE AS NEEDED)
global input_data "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\PER"
global output_path "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Excel\01_transition_matrix"

* Create output directory if it doesn't exist
cap mkdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Excel"
cap mkdir "$output_path"

* Define input panel dataset (MODIFY AS NEEDED)
global input_panel "01_PER_2019-2023_panel.dta"

* Output file name
global output_file "02_PER_Job_transitions_2019_2023.xlsx"

noi di ""
noi di "=== LABOR MARKET TRANSITIONS ANALYSIS ==="
noi di "Dataset: $input_panel"
noi di ""

**# ==============================================================================
**# 1. LOAD AND PREPARE HARMONIZED PANEL DATA
**# ==============================================================================

use "$input_data/$input_panel", clear

noi di "Raw data loaded. Total observations: " _N

* Verify we have two time periods
tab time, missing
qui levelsof time, local(time_periods)
local n_periods: word count `time_periods'
assert `n_periods' == 2

* Store time period labels for later use
qui sum ano if time == 0
local year_t0 = r(mean)
qui sum ano if time == 1  
local year_t1 = r(mean)

noi di ""
noi di "Time periods identified: `year_t0' (t0) and `year_t1' (t1)"

**# ==============================================================================
**# 2. FILTER TO BALANCED PANEL
**# ==============================================================================

* Filter to balanced panel
keep if balanced_panel == 1

noi di "Balanced panel observations: " _N

* Count unique individuals and households
qui count if time == 0
local n_individuals_all = r(N)
preserve
keep if time == 0
qui tab household_id
local n_households_all = r(r)
restore

noi di "Balanced panel: `n_individuals_all' individuals in `n_households_all' households"
noi di ""

**# ==============================================================================
**# 3. RESHAPE DATA FOR TRANSITION ANALYSIS
**# ==============================================================================

noi di "=== RESHAPING DATA ==="

* Keep essential variables - including cohh for filtering
keep indiv_id household_id time ano employed emptype welfare skill_group iweight balanced_panel cohh

* Reshape to wide format for transition analysis
reshape wide ano employed emptype welfare skill_group iweight cohh, i(indiv_id) j(time)

* Rename for clarity
rename employed0 employed_t0
rename employed1 employed_t1
rename emptype0 emptype_t0
rename emptype1 emptype_t1
rename welfare0 welfare_t0
rename welfare1 welfare_t1
rename skill_group0 skill_group_t0
rename skill_group1 skill_group_t1
rename iweight0 weight
rename cohh0 cohh_t0
rename cohh1 cohh_t1

* Clean up
drop iweight1 ano0 ano1

label var employed_t0 "Employment status at t0 (1=Employed, 0=Not employed)"
label var employed_t1 "Employment status at t1 (1=Employed, 0=Not employed)"
label var emptype_t0 "Employment type at t0 (1=Unpaid, 2=Self-emp, 3=Salaried, 4=Employer)"
label var emptype_t1 "Employment type at t1 (1=Unpaid, 2=Self-emp, 3=Salaried, 4=Employer)"
label var welfare_t0 "Annual per capita income at t0 (USD 2021 PPP)"
label var welfare_t1 "Annual per capita income at t1 (USD 2021 PPP)"
label var skill_group_t0 "Occupational skill level at t0 (1=Low, 2=Medium, 3=High)"
label var skill_group_t1 "Occupational skill level at t1 (1=Low, 2=Medium, 3=High)"
label var weight "Individual survey weight (from t0)"
label var cohh_t0 "Head of household indicator at t0"

* Apply cohh==1 filter
keep if cohh_t0 == 1

noi di "Data reshaped to wide format"
noi di "Sample after cohh==1 filter: " _N " individuals"
noi di ""

**# ==============================================================================
**# 4. EMPLOYMENT STATUS TRANSITIONS
**# ==============================================================================

noi di "=== ANALYZING EMPLOYMENT STATUS TRANSITIONS ==="

* Recode missing values:
* If missing in one period but non-missing in the other → code as 0 (Not working)
* If missing in both periods → will be excluded below

gen employed_t0_clean = employed_t0
replace employed_t0_clean = 0 if missing(employed_t0) & !missing(employed_t1)

gen employed_t1_clean = employed_t1
replace employed_t1_clean = 0 if missing(employed_t1) & !missing(employed_t0)

* Exclude observations missing in both periods
gen valid_employment = (!missing(employed_t0_clean) & !missing(employed_t1_clean))

noi di "Total observations with at least one non-missing employment status: " _N
qui count if valid_employment == 1
noi di "Valid observations for employment transitions: " r(N)
qui count if valid_employment == 0
noi di "Excluded (missing in both periods): " r(N)
noi di ""

preserve

* Keep only valid observations
keep if valid_employment == 1

* Create labeled status variables
gen status_t0_emp = employed_t0_clean
gen status_t1_emp = employed_t1_clean

label define emp_lbl 0 "Not working" 1 "Employed"
label values status_t0_emp emp_lbl
label values status_t1_emp emp_lbl

* Calculate weighted transition matrix
tab status_t0_emp status_t1_emp [aw=weight], matcell(trans_emp_freq)

* Calculate percentages - denominator is sum of matrix cells
mat trans_emp_pct = trans_emp_freq
local total_weight = trans_emp_freq[1,1] + trans_emp_freq[1,2] + trans_emp_freq[2,1] + trans_emp_freq[2,2]
forval i = 1/2 {
    forval j = 1/2 {
        mat trans_emp_pct[`i',`j'] = 100 * trans_emp_freq[`i',`j'] / `total_weight'
    }
}

noi di "Employment Status Transition Matrix (% of total sample):"
noi di "                    t1: Not working    t1: Employed"
noi mat list trans_emp_pct, format(%9.2f)

* Verify sum
local sum_check = trans_emp_pct[1,1] + trans_emp_pct[1,2] + trans_emp_pct[2,1] + trans_emp_pct[2,2]
noi di "Sum of percentages: " %5.2f `sum_check' "% (should be 100%)"

* Calculate sample sizes
qui count
local n_unweighted = r(N)
qui sum weight
local n_weighted = r(sum)

noi di ""
noi di "Sample size - Unweighted: " %8.0fc `n_unweighted'
noi di "Sample size - Weighted: " %12.0fc `n_weighted'

* SAVE THE CLEANED VARIABLES FOR USE IN SUBSEQUENT ANALYSES
tempfile base_for_other_analyses
save `base_for_other_analyses'

* Create dataset for export
clear
set obs 6

gen str50 variable = ""
gen not_working_t1 = .
gen employed_t1 = .
gen str100 notes = ""

replace variable = "Status at t0 → Status at t1" in 1
replace variable = "Not working → Not working" in 2
replace variable = "Not working → Employed (Job entry)" in 3
replace variable = "Employed → Not working (Job exit)" in 4
replace variable = "Employed → Employed (Remained employed)" in 5

replace not_working_t1 = trans_emp_pct[1,1] in 2
replace employed_t1 = trans_emp_pct[1,2] in 3
replace not_working_t1 = trans_emp_pct[2,1] in 4
replace employed_t1 = trans_emp_pct[2,2] in 5

replace notes = "Variable: employed (1=Employed, 0=Not employed)" in 1
replace notes = "Missing in one period → coded as 0 (Not working)" in 2
replace notes = "Excluded: Observations missing in both periods" in 3
replace notes = "Sample (unweighted): " + string(`n_unweighted', "%8.0fc") in 4
replace notes = "Sample (weighted): " + string(`n_weighted', "%12.0fc") in 5

tempfile emp_results
save `emp_results'

restore

noi di "Employment status transitions calculated"
noi di ""

**# ==============================================================================
**# 5. EMPLOYMENT TYPE TRANSITIONS
**# ==============================================================================

noi di "=== ANALYZING EMPLOYMENT TYPE TRANSITIONS ==="

* USE THE SAME SAMPLE AS EMPLOYMENT STATUS
* Start with the exact same valid_employment filter
keep if valid_employment == 1

* NOW recode emptype based on the CLEANED employment status
* If employed_t0_clean==0 → set emptype to 0 (Not working)
* If employed_t1_clean==0 → set emptype to 0 (Not working)

gen emptype_t0_clean = emptype_t0
replace emptype_t0_clean = 0 if employed_t0_clean == 0

gen emptype_t1_clean = emptype_t1
replace emptype_t1_clean = 0 if employed_t1_clean == 0

noi di "Total observations in employment type analysis: " _N
qui count if missing(emptype_t0_clean) | missing(emptype_t1_clean)
if r(N) > 0 {
    noi di "WARNING: " r(N) " observations have missing emptype despite being employed"
}

preserve

* Create labeled status variables
gen status_t0_emptype = emptype_t0_clean
gen status_t1_emptype = emptype_t1_clean

label define emptype_lbl_m 0 "Not working" 1 "Unpaid worker" 2 "Self-employed" 3 "Salaried" 4 "Employer"
label values status_t0_emptype emptype_lbl_m
label values status_t1_emptype emptype_lbl_m

* Calculate weighted transition matrix
tab status_t0_emptype status_t1_emptype [aw=weight], matcell(trans_emptype_freq)

* Calculate percentages - denominator is sum of matrix cells
mat trans_emptype_pct = trans_emptype_freq
local total_weight = 0
forval i = 1/5 {
    forval j = 1/5 {
        local total_weight = `total_weight' + trans_emptype_freq[`i',`j']
    }
}
forval i = 1/5 {
    forval j = 1/5 {
        mat trans_emptype_pct[`i',`j'] = 100 * trans_emptype_freq[`i',`j'] / `total_weight'
    }
}

noi di "Employment Type Transition Matrix (% of total sample):"
noi mat list trans_emptype_pct, format(%9.2f)

* Verify sum
local sum_check = 0
forval i = 1/5 {
    forval j = 1/5 {
        local sum_check = `sum_check' + trans_emptype_pct[`i',`j']
    }
}
noi di "Sum of percentages: " %5.2f `sum_check' "% (should be 100%)"

* Calculate sample sizes
qui count
local n_unweighted = r(N)
qui sum weight
local n_weighted = r(sum)

noi di ""
noi di "Sample size - Unweighted: " %8.0fc `n_unweighted'
noi di "Sample size - Weighted: " %12.0fc `n_weighted'

* Create dataset for export
clear
set obs 9

gen str50 variable = ""
gen not_working_t1 = .
gen unpaid_t1 = .
gen self_employed_t1 = .
gen salaried_t1 = .
gen employer_t1 = .
gen str100 notes = ""

replace variable = "Status at t0 → Status at t1" in 1
replace variable = "Not working at t0" in 2
replace variable = "Unpaid worker at t0" in 3
replace variable = "Self-employed at t0" in 4
replace variable = "Salaried at t0" in 5
replace variable = "Employer at t0" in 6

* Fill in transition percentages
forval i = 1/5 {
    local row = `i' + 1
    forval j = 1/5 {
        if `j' == 1 {
            replace not_working_t1 = trans_emptype_pct[`i',`j'] in `row'
        }
        else if `j' == 2 {
            replace unpaid_t1 = trans_emptype_pct[`i',`j'] in `row'
        }
        else if `j' == 3 {
            replace self_employed_t1 = trans_emptype_pct[`i',`j'] in `row'
        }
        else if `j' == 4 {
            replace salaried_t1 = trans_emptype_pct[`i',`j'] in `row'
        }
        else if `j' == 5 {
            replace employer_t1 = trans_emptype_pct[`i',`j'] in `row'
        }
    }
}

replace notes = "Variable: emptype (1=Unpaid, 2=Self-employed, 3=Salaried, 4=Employer)" in 1
replace notes = "Not working based on employed==0 (same sample as employment status)" in 2
replace notes = "Shares should match employment status analysis" in 3
replace notes = "Sample (unweighted): " + string(`n_unweighted', "%8.0fc") in 4
replace notes = "Sample (weighted): " + string(`n_weighted', "%12.0fc") in 5

tempfile emptype_results
save `emptype_results'

restore

noi di "Employment type transitions calculated"
noi di ""



**# ==============================================================================
**# 6. EARNINGS QUINTILE TRANSITIONS
**# ==============================================================================

noi di "=== ANALYZING EARNINGS QUINTILE TRANSITIONS ==="

* Identify observations with at least one non-missing welfare value
gen valid_earnings = (!missing(welfare_t0) | !missing(welfare_t1))

qui count if valid_earnings == 1
noi di "Valid observations for earnings transitions: " r(N)
qui count if valid_earnings == 0
noi di "Excluded (missing in both periods): " r(N)
noi di ""

preserve

* Keep only valid observations
keep if valid_earnings == 1

* Calculate quintiles at t0 (only for non-missing values)
qui _pctile welfare_t0 [aw=weight] if !missing(welfare_t0), nq(5)
local p20_t0 = r(r1)
local p40_t0 = r(r2)
local p60_t0 = r(r3)
local p80_t0 = r(r4)

* Calculate quintiles at t1 (only for non-missing values)
qui _pctile welfare_t1 [aw=weight] if !missing(welfare_t1), nq(5)
local p20_t1 = r(r1)
local p40_t1 = r(r2)
local p60_t1 = r(r3)
local p80_t1 = r(r4)

* Create quintiles at t0 (0 = No earnings for missing values)
gen quintile_t0 = 0 if missing(welfare_t0)
replace quintile_t0 = 1 if welfare_t0 <= `p20_t0' & !missing(welfare_t0)
replace quintile_t0 = 2 if welfare_t0 > `p20_t0' & welfare_t0 <= `p40_t0' & !missing(welfare_t0)
replace quintile_t0 = 3 if welfare_t0 > `p40_t0' & welfare_t0 <= `p60_t0' & !missing(welfare_t0)
replace quintile_t0 = 4 if welfare_t0 > `p60_t0' & welfare_t0 <= `p80_t0' & !missing(welfare_t0)
replace quintile_t0 = 5 if welfare_t0 > `p80_t0' & !missing(welfare_t0)

* Create quintiles at t1 (0 = No earnings for missing values)
gen quintile_t1 = 0 if missing(welfare_t1)
replace quintile_t1 = 1 if welfare_t1 <= `p20_t1' & !missing(welfare_t1)
replace quintile_t1 = 2 if welfare_t1 > `p20_t1' & welfare_t1 <= `p40_t1' & !missing(welfare_t1)
replace quintile_t1 = 3 if welfare_t1 > `p40_t1' & welfare_t1 <= `p60_t1' & !missing(welfare_t1)
replace quintile_t1 = 4 if welfare_t1 > `p60_t1' & welfare_t1 <= `p80_t1' & !missing(welfare_t1)
replace quintile_t1 = 5 if welfare_t1 > `p80_t1' & !missing(welfare_t1)

label define quintile_lbl 0 "No earnings" 1 "Q1 (Poorest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (Richest)"
label values quintile_t0 quintile_lbl
label values quintile_t1 quintile_lbl

* Calculate weighted transition matrix
tab quintile_t0 quintile_t1 [aw=weight], matcell(trans_quint_freq)

* Get actual matrix dimensions
local n_rows = rowsof(trans_quint_freq)
local n_cols = colsof(trans_quint_freq)

noi di "Matrix dimensions: `n_rows' rows x `n_cols' columns"

* Calculate percentages - denominator is sum of matrix cells
mat trans_quint_pct = trans_quint_freq
local total_weight = 0
forval i = 1/`n_rows' {
    forval j = 1/`n_cols' {
        local total_weight = `total_weight' + trans_quint_freq[`i',`j']
    }
}
forval i = 1/`n_rows' {
    forval j = 1/`n_cols' {
        mat trans_quint_pct[`i',`j'] = 100 * trans_quint_freq[`i',`j'] / `total_weight'
    }
}

noi di "Earnings Quintile Transition Matrix (% of total sample):"
noi mat list trans_quint_pct, format(%9.2f)

* Verify sum
local sum_check = 0
forval i = 1/`n_rows' {
    forval j = 1/`n_cols' {
        local sum_check = `sum_check' + trans_quint_pct[`i',`j']
    }
}
noi di "Sum of percentages: " %5.2f `sum_check' "% (should be 100%)"

* Calculate sample sizes
qui count
local n_unweighted = r(N)
qui sum weight
local n_weighted = r(sum)

noi di ""
noi di "Sample size - Unweighted: " %8.0fc `n_unweighted'
noi di "Sample size - Weighted: " %12.0fc `n_weighted'

* Check if "No earnings" category exists
qui count if quintile_t0 == 0 | quintile_t1 == 0
local has_no_earnings = (r(N) > 0)

* Create dataset for export - adjust size based on whether we have "No earnings"
clear
if `has_no_earnings' == 1 {
    set obs 10
    local n_categories = 6
}
else {
    set obs 9
    local n_categories = 5
}

gen str50 variable = ""
gen no_earnings_t1 = .
gen q1_t1 = .
gen q2_t1 = .
gen q3_t1 = .
gen q4_t1 = .
gen q5_t1 = .
gen str100 notes = ""

replace variable = "Status at t0 → Status at t1" in 1

if `has_no_earnings' == 1 {
    replace variable = "No earnings at t0" in 2
    replace variable = "Q1 (Poorest) at t0" in 3
    replace variable = "Q2 at t0" in 4
    replace variable = "Q3 at t0" in 5
    replace variable = "Q4 at t0" in 6
    replace variable = "Q5 (Richest) at t0" in 7
}
else {
    replace variable = "Q1 (Poorest) at t0" in 2
    replace variable = "Q2 at t0" in 3
    replace variable = "Q3 at t0" in 4
    replace variable = "Q4 at t0" in 5
    replace variable = "Q5 (Richest) at t0" in 6
}

* Fill in transition percentages based on actual matrix dimensions
forval i = 1/`n_rows' {
    local row = `i' + 1
    forval j = 1/`n_cols' {
        * Determine which column to fill based on matrix structure
        if `has_no_earnings' == 1 {
            if `j' == 1 {
                replace no_earnings_t1 = trans_quint_pct[`i',`j'] in `row'
            }
            else {
                local col = `j' - 1
                replace q`col'_t1 = trans_quint_pct[`i',`j'] in `row'
            }
        }
        else {
            * No "No earnings" category, so j maps directly to quintile
            replace q`j'_t1 = trans_quint_pct[`i',`j'] in `row'
        }
    }
}

replace notes = "Variable: welfare (annual per capita income, USD 2021 PPP)" in 1
replace notes = "Quintiles calculated separately for t0 and t1 using weighted distributions" in 2
if `has_no_earnings' == 1 {
    replace notes = "Missing welfare → coded as 'No earnings'" in 3
    replace notes = "Excluded: Observations missing in both periods" in 4
    replace notes = "Sample (unweighted): " + string(`n_unweighted', "%8.0fc") in 5
    replace notes = "Sample (weighted): " + string(`n_weighted', "%12.0fc") in 6
}
else {
    replace notes = "Note: No 'No earnings' category in this sample (all have welfare data)" in 3
    replace notes = "Excluded: Observations missing in both periods" in 4
    replace notes = "Sample (unweighted): " + string(`n_unweighted', "%8.0fc") in 5
    replace notes = "Sample (weighted): " + string(`n_weighted', "%12.0fc") in 6
}

tempfile earnings_results
save `earnings_results'

restore

noi di "Earnings quintile transitions calculated"
noi di ""

**# ==============================================================================
**# 7. SKILL GROUP TRANSITIONS
**# ==============================================================================

noi di "=== ANALYZING SKILL GROUP TRANSITIONS ==="

* USE THE SAME SAMPLE AS EMPLOYMENT STATUS
* Keep only those with valid_employment==1
keep if valid_employment == 1

* NOW recode skill_group based on the CLEANED employment status
gen skill_group_t0_clean = skill_group_t0
replace skill_group_t0_clean = 0 if employed_t0_clean == 0

gen skill_group_t1_clean = skill_group_t1
replace skill_group_t1_clean = 0 if employed_t1_clean == 0

noi di "Total observations in skill group analysis: " _N
qui count if missing(skill_group_t0_clean) | missing(skill_group_t1_clean)
if r(N) > 0 {
    noi di "WARNING: " r(N) " observations have missing skill_group despite being employed"
}

preserve

* Create labeled status variables
gen status_t0_skill = skill_group_t0_clean
gen status_t1_skill = skill_group_t1_clean

label define skill_lbl_m 0 "Not working" 1 "Low skill" 2 "Medium skill" 3 "High skill"
label values status_t0_skill skill_lbl_m
label values status_t1_skill skill_lbl_m

* Calculate weighted transition matrix
tab status_t0_skill status_t1_skill [aw=weight], matcell(trans_skill_freq)

* Calculate percentages - denominator is sum of matrix cells
mat trans_skill_pct = trans_skill_freq
local total_weight = 0
forval i = 1/4 {
    forval j = 1/4 {
        local total_weight = `total_weight' + trans_skill_freq[`i',`j']
    }
}
forval i = 1/4 {
    forval j = 1/4 {
        mat trans_skill_pct[`i',`j'] = 100 * trans_skill_freq[`i',`j'] / `total_weight'
    }
}

noi di "Skill Group Transition Matrix (% of total sample):"
noi mat list trans_skill_pct, format(%9.2f)

* Verify sum
local sum_check = 0
forval i = 1/4 {
    forval j = 1/4 {
        local sum_check = `sum_check' + trans_skill_pct[`i',`j']
    }
}
noi di "Sum of percentages: " %5.2f `sum_check' "% (should be 100%)"

* Calculate sample sizes
qui count
local n_unweighted = r(N)
qui sum weight
local n_weighted = r(sum)

noi di ""
noi di "Sample size - Unweighted: " %8.0fc `n_unweighted'
noi di "Sample size - Weighted: " %12.0fc `n_weighted'

* Create dataset for export
clear
set obs 8

gen str50 variable = ""
gen not_working_t1 = .
gen low_skill_t1 = .
gen medium_skill_t1 = .
gen high_skill_t1 = .
gen str100 notes = ""

replace variable = "Status at t0 → Status at t1" in 1
replace variable = "Not working at t0" in 2
replace variable = "Low skill at t0" in 3
replace variable = "Medium skill at t0" in 4
replace variable = "High skill at t0" in 5

* Fill in transition percentages
forval i = 1/4 {
    local row = `i' + 1
    forval j = 1/4 {
        if `j' == 1 {
            replace not_working_t1 = trans_skill_pct[`i',`j'] in `row'
        }
        else if `j' == 2 {
            replace low_skill_t1 = trans_skill_pct[`i',`j'] in `row'
        }
        else if `j' == 3 {
            replace medium_skill_t1 = trans_skill_pct[`i',`j'] in `row'
        }
        else if `j' == 4 {
            replace high_skill_t1 = trans_skill_pct[`i',`j'] in `row'
        }
    }
}

replace notes = "Variable: skill_group (1=Low skill, 2=Medium skill, 3=High skill)" in 1
replace notes = "Not working based on employed==0 (same sample as employment status)" in 2
replace notes = "Shares should match employment status analysis" in 3
replace notes = "Sample (unweighted): " + string(`n_unweighted', "%8.0fc") in 4
replace notes = "Sample (weighted): " + string(`n_weighted', "%12.0fc") in 5

tempfile skill_results
save `skill_results'

restore

noi di "Skill group transitions calculated"
noi di ""

**# ==============================================================================
**# 8. CREATE SUMMARY SHEET
**# ==============================================================================

preserve

clear
set obs 30

gen str50 metric = ""
gen str100 value = ""
gen str100 description = ""

local row = 1

* General information
replace metric = "DATASET INFORMATION" in `row'
local ++row

replace metric = "Dataset" in `row'
replace value = "$input_panel" in `row'
local ++row

replace metric = "Time period" in `row'
replace value = "`year_t0' to `year_t1'" in `row'
local ++row

replace metric = "Total individuals (balanced panel)" in `row'
replace value = string(`n_individuals_all', "%8.0fc") in `row'
local ++row

replace metric = "Total households (balanced panel)" in `row'
replace value = string(`n_households_all', "%8.0fc") in `row'
local ++row

replace metric = "" in `row'
local ++row

* Methodology
replace metric = "METHODOLOGY" in `row'
local ++row

replace metric = "Sample restrictions" in `row'
replace description = "Balanced panel with cohh==1" in `row'
local ++row

replace metric = "Missing value treatment" in `row'
replace description = "Missing in one period → coded as 'Not working'/'No earnings'" in `row'
local ++row

replace metric = "Exclusion criteria" in `row'
replace description = "Observations missing in both periods are excluded" in `row'
local ++row

replace metric = "Survey weights" in `row'
replace description = "All calculations use individual weights from t0 (iweight0)" in `row'
local ++row

replace metric = "Transition matrices" in `row'
replace description = "All values represent % of total sample" in `row'
local ++row

replace metric = "" in `row'
local ++row

* Labor market variables
replace metric = "LABOR MARKET VARIABLES" in `row'
local ++row

replace metric = "employed" in `row'
replace description = "1=Employed, 0=Not employed" in `row'
local ++row

replace metric = "emptype" in `row'
replace description = "1=Unpaid worker, 2=Self-employed, 3=Salaried, 4=Employer" in `row'
local ++row

replace metric = "welfare" in `row'
replace description = "Annual per capita income (USD 2021 PPP)" in `row'
local ++row

replace metric = "skill_group" in `row'
replace description = "1=Low skill, 2=Medium skill, 3=High skill" in `row'
local ++row

replace metric = "" in `row'
local ++row

* Output sheets
replace metric = "OUTPUT SHEETS" in `row'
local ++row

replace metric = "1. Employment_Status" in `row'
replace description = "Employed vs Not working transitions" in `row'
local ++row

replace metric = "2. Employment_Type" in `row'
replace description = "Job relationship transitions (Unpaid, Self-emp, Salaried, Employer)" in `row'
local ++row

replace metric = "3. Earnings_Quintiles" in `row'
replace description = "Welfare quintile transitions (Q1-Q5 plus No earnings)" in `row'
local ++row

replace metric = "4. Skill_Groups" in `row'
replace description = "Occupational skill level transitions (Low, Medium, High, Not working)" in `row'
local ++row

drop if missing(metric) & missing(description)

tempfile summary_results
save `summary_results'

restore

noi di "Summary statistics compiled"
noi di ""

**# ==============================================================================
**# 9. EXPORT ALL RESULTS TO EXCEL
**# ==============================================================================

noi di "=== EXPORTING RESULTS TO EXCEL ==="

* Start fresh Excel file with summary sheet
use `summary_results', clear
export excel metric value description using ///
    "$output_path/$output_file", ///
    sheet("Summary", replace) firstrow(variables)

* Export employment status transitions
use `emp_results', clear
export excel variable not_working_t1 employed_t1 notes using ///
    "$output_path/$output_file", ///
    sheet("Employment_Status", modify) firstrow(variables)

* Export employment type transitions
use `emptype_results', clear
export excel variable not_working_t1 unpaid_t1 self_employed_t1 salaried_t1 employer_t1 notes using ///
    "$output_path/$output_file", ///
    sheet("Employment_Type", modify) firstrow(variables)

* Export earnings quintile transitions
use `earnings_results', clear
export excel variable no_earnings_t1 q1_t1 q2_t1 q3_t1 q4_t1 q5_t1 notes using ///
    "$output_path/$output_file", ///
    sheet("Earnings_Quintiles", modify) firstrow(variables)

* Export skill group transitions
use `skill_results', clear
export excel variable not_working_t1 low_skill_t1 medium_skill_t1 high_skill_t1 notes using ///
    "$output_path/$output_file", ///
    sheet("Skill_Groups", modify) firstrow(variables)

noi di ""
noi di "=== ANALYSIS COMPLETED SUCCESSFULLY ==="
noi di ""
noi di "Results exported to:"
noi di "$output_path/$output_file"
noi di ""
noi di "Excel sheets created:"
noi di "  1. Summary - Dataset information and methodology"
noi di "  2. Employment_Status - Employment status transitions (Employed vs Not working)"
noi di "  3. Employment_Type - Job type transitions (Unpaid, Self-emp, Salaried, Employer, Not working)"
noi di "  4. Earnings_Quintiles - Welfare quintile transitions (Q1-Q5 plus No earnings)"
noi di "  5. Skill_Groups - Occupational skill transitions (Low, Medium, High, Not working)"
noi di ""