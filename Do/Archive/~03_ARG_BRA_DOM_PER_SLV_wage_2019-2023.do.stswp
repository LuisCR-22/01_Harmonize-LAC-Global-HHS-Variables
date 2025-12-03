/*====================================================================
Project: Creating Annual Wage and Earnings Variables for Harmonized LAC Panel Datasets
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/12/01
Last modification: 	2025/12/03
====================================================================
PURPOSE: This script creates annual wage and earnings variables in USD 2021 PPP
         using different income measures by employment type. Creates two versions
         of each (IMF CPI and SEDLAC CPI) for comparison purposes.
         
         UPDATED: Now works for all 5 LAC countries with country selection macro.
         FIXED: Handles DOM string hours variables and clears between iterations.

METHODOLOGY:
- WAGE: For salaried employees only (emptype==3)
  * Uses hourly_wage_lc and annualizes with hours worked
  * Formula: (hourly_wage_lc × hstrt × 52) × CPI_ratio / (ppp2021 × conversion)
  
- EARNINGS: For self-employed and employers (emptype==2 and emptype==4)
  * Uses ila (monthly labor income) and annualizes to yearly
  * Formula: (ila × 12) × CPI_ratio / (ppp2021 × conversion)

INPUTS REQUIRED:
For WAGE:
- hourly_wage_lc: Hourly wage in local currency
- hstrt: Total hours worked per week
- emptype==3: Salaried employees

For EARNINGS:
- ila: Monthly labor income in local currency
- emptype==2 or emptype==4: Self-employed or employers

For BOTH:
- cpiwave, cpi2021: IMF CPI values
- ipc_sedlac, ipc21_sedlac: SEDLAC CPI values
- ppp2021: PPP conversion factor
- conversion: Currency unit adjustment factor

OUTPUTS:
- wage: Annual wage in USD 2021 PPP (salaried, IMF CPI)
- wage_sedlac: Annual wage in USD 2021 PPP (salaried, SEDLAC CPI)
- earnings: Annual earnings in USD 2021 PPP (self-employed/employers, IMF CPI)
- earnings_sedlac: Annual earnings in USD 2021 PPP (self-employed/employers, SEDLAC CPI)
*=================================================================*/

clear all
set more off

**# ==============================================================================
**# 0. USER CONFIGURATION - SET COUNTRY HERE
**# ==============================================================================

***********************************************
*** CHANGE THIS MACRO TO SELECT COUNTRY   ***
***********************************************
*global country_selection "BRA"  
* Options: "PER" (Peru), "ARG" (Argentina), "BRA" (Brazil), "DOM" (Dominican Republic), or "SLV" (El Salvador)
***********************************************

**# ==============================================================================
**# 1. COUNTRY-SPECIFIC CONFIGURATIONS (MUST MATCH HARMONIZATION SCRIPT)
**# ==============================================================================

* Base paths
global wdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team"

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
noi di "=== CREATING ANNUAL WAGE AND EARNINGS VARIABLES ==="
noi di "==============================================================================="
noi di "Country Selected: $current_country (ISO: $current_iso)"
noi di "Processing `n_combos' panel dataset(s)"
noi di "Output directory: $output_data"
noi di "==============================================================================="
noi di ""

**# ==============================================================================
**# 2. LOOP THROUGH PANEL DATASETS
**# ==============================================================================

forvalues i = 1/`n_combos' {
    
    * Parse the year combination
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    
    noi di "==============================================================================="
    noi di "Processing: 01_${current_iso}_`t0'-`t1'_panel.dta"
    noi di "==============================================================================="
    noi di ""
    
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
    local n_total = _N
    
    **# =========================================================================
	**# COUNTRY-SPECIFIC DATA FIXES
	**# =========================================================================

	* Fix for Dominican Republic: Convert string hours variables to numeric
	if "$current_iso" == "DOM" {
		noi di "Applying DOM-specific fix: Converting string hours variables to numeric..."
		
		* CRITICAL FIX: Drop any existing temporary variables from previous runs
		cap drop __*
		
		* Check if hstrt is string (only convert if string)
		local converted = 0
		cap confirm string variable hstrt
		if !_rc {
			quietly destring hstrt, replace force
			label var hstrt "Total hours worked per week"
			local converted = 1
		}
		
		* Check if hstrp is string
		cap confirm string variable hstrp
		if !_rc {
			quietly destring hstrp, replace force
			label var hstrp "Hours worked in main occupation"
			local converted = 1
		}
		
		* Check if hstrs is string
		cap confirm string variable hstrs
		if !_rc {
			quietly destring hstrs, replace force
			label var hstrs "Hours worked in secondary occupation"
			local converted = 1
		}
		
		* Clean up any temporary variables created by destring
		cap drop __*
		
		if `converted' == 1 {
			qui count if missing(hstrt) & emptype == 3
			if r(N) > 0 {
				noi di "  Note: " r(N) " salaried employees have missing hours after conversion"
			}
			noi di "  ✓ Hours variables converted to numeric"
		}
		else {
			noi di "  ✓ Hours variables already numeric"
		}
		noi di ""
	}
    
    **# =========================================================================
    **# PART A: WAGE CREATION FOR SALARIED EMPLOYEES (emptype==3)
    **# =========================================================================
    
    noi di "==========================================================================="
    noi di "PART A: CREATING WAGE VARIABLES FOR SALARIED EMPLOYEES"
    noi di "==========================================================================="
    noi di ""
    
    **# -------------------------------------------------------------------------
    **# A.1 VERIFY REQUIRED VARIABLES FOR WAGE
    **# -------------------------------------------------------------------------
    
    noi di "Step A.1: Verifying required variables for wage..."
    
    * Check for required variables
    local required_vars_wage "hourly_wage_lc hstrt emptype cpiwave cpi2021 ppp2021 conversion ipc_sedlac ipc21_sedlac"
    local missing_vars ""
    
    foreach var of local required_vars_wage {
        cap confirm variable `var'
        if _rc {
            local missing_vars "`missing_vars' `var'"
        }
    }
    
    if "`missing_vars'" != "" {
        noi di as error "  ERROR: Missing required variables for wage:`missing_vars'"
        noi di as error "  Skipping wage creation for this dataset."
        local skip_wage = 1
    }
    else {
        noi di "  ✓ All required variables for wage present"
        local skip_wage = 0
    }
    noi di ""
    
    if `skip_wage' == 0 {
        
        **# ---------------------------------------------------------------------
        **# A.2 IDENTIFY SALARIED EMPLOYEES
        **# ---------------------------------------------------------------------
        
        noi di "Step A.2: Identifying salaried employees..."
        
        * Count salaried employees
        qui count if emptype == 3
        local n_salaried = r(N)
        local pct_salaried = (`n_salaried' / `n_total') * 100
        
        noi di "  Total observations: `n_total'"
        noi di "  Salaried employees (emptype==3): `n_salaried' (" %5.2f `pct_salaried' "%)"
        
        * Check data availability for salaried employees
        qui count if emptype == 3 & !missing(hourly_wage_lc) & !missing(hstrt)
        local n_with_wage_hours = r(N)
        
        if `n_salaried' > 0 {
            local pct_with_data = (`n_with_wage_hours' / `n_salaried') * 100
            noi di "  Salaried with wage & hours data: `n_with_wage_hours' (" %5.2f `pct_with_data' "% of salaried)"
        }
        else {
            noi di "  Note: No salaried employees in this dataset"
        }
        
        * Show distribution of hours for salaried employees if data exists
        if `n_with_wage_hours' > 0 {
            noi di "  Hours worked per week (hstrt) - Salaried employees:"
            qui sum hstrt if emptype == 3, detail
            noi di "    Mean: " %6.2f r(mean) " | Median: " %6.2f r(p50) " | SD: " %6.2f r(sd)
            noi di "    Min: " %6.2f r(min) " | Max: " %6.2f r(max)
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.3 CREATE ANNUAL HOURS AND ANNUAL NOMINAL WAGE
        **# ---------------------------------------------------------------------
        
        noi di "Step A.3: Creating annual hours and annual nominal wage..."
        
        * Calculate annual hours (weekly hours × 52 weeks)
        gen double annual_hours = hstrt * 52 if emptype == 3
        label var annual_hours "Annual hours worked (weekly hours × 52 weeks)"
        
        * Calculate annual nominal wage
        gen double annual_wage_nominal_lc = hourly_wage_lc * annual_hours if emptype == 3
        label var annual_wage_nominal_lc "Annual nominal wage in local currency"
        
        qui count if emptype == 3 & !missing(annual_wage_nominal_lc)
        if r(N) > 0 {
            qui sum annual_wage_nominal_lc if emptype == 3, detail
            noi di "  Annual nominal wage (local currency) - Salaried employees:"
            noi di "    Mean: " %12.0f r(mean) " | Median: " %12.0f r(p50)
            noi di "    Non-missing: " r(N)
        }
        else {
            noi di "  Note: No annual wage values calculated (no valid data)"
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.4 CREATE PPP CONVERSION FACTORS FOR WAGE
        **# ---------------------------------------------------------------------
        
        noi di "Step A.4: Creating PPP conversion factors..."
        
        * Create conversion factor using IMF CPI
        gen double factor_ppp21_wage = (cpi2021 / cpiwave) / (ppp2021 * conversion)
        label var factor_ppp21_wage "PPP factor for wage (IMF CPI)"
        
        * Create conversion factor using SEDLAC CPI
        gen double factor_ppp21_wage_sedlac = (ipc21_sedlac / ipc_sedlac) / (ppp2021 * conversion)
        label var factor_ppp21_wage_sedlac "PPP factor for wage (SEDLAC CPI)"
        
        qui count if emptype == 3 & !missing(factor_ppp21_wage)
        if r(N) > 0 {
            qui sum factor_ppp21_wage if emptype == 3, detail
            noi di "  PPP conversion factor (IMF CPI): Mean = " %8.6f r(mean)
            qui sum factor_ppp21_wage_sedlac if emptype == 3, detail
            noi di "  PPP conversion factor (SEDLAC CPI): Mean = " %8.6f r(mean)
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.5 CREATE WAGE IN USD 2021 PPP (IMF CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step A.5: Creating wage (USD 2021 PPP, IMF CPI)..."
        
        * Initialize wage variable (replace if exists)
        cap drop wage
        gen double wage = .
        label var wage "Annual wage, USD 2021 PPP (salaried, IMF CPI)"
        
        * Calculate wage only for salaried employees
        replace wage = annual_wage_nominal_lc * factor_ppp21_wage if emptype == 3
        
        * Add notes
        note wage: Annual wage of salaried employees (emptype==3) in USD 2021 PPP
        note wage: Formula: (hourly_wage_lc × hstrt × 52) × (cpi2021/cpiwave) / (ppp2021 × conversion)
        note wage: Uses IMF CPI data (cpiwave, cpi2021)
        note wage: Country: $current_country (ISO: $current_iso)
        note wage: Created on $S_DATE
        
        * Summary statistics
        qui count if emptype == 3 & !missing(wage)
        local n_wage_created = r(N)
        
        if `n_wage_created' > 0 {
            qui sum wage if emptype == 3, detail
            noi di "  Wage created for: `n_wage_created' salaried employees"
            noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
            noi di "    Min: " %12.2f r(min) " | Max: " %12.2f r(max)
        }
        else {
            noi di "  Note: No wage values created (no valid data for salaried employees)"
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.6 CREATE WAGE IN USD 2021 PPP (SEDLAC CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step A.6: Creating wage_sedlac (USD 2021 PPP, SEDLAC CPI)..."
        
        * Initialize wage_sedlac variable
        cap drop wage_sedlac
        gen double wage_sedlac = .
        label var wage_sedlac "Annual wage, USD 2021 PPP (salaried, SEDLAC CPI)"
        
        * Calculate wage_sedlac only for salaried employees
        replace wage_sedlac = annual_wage_nominal_lc * factor_ppp21_wage_sedlac if emptype == 3
        
        * Add notes
        note wage_sedlac: Annual wage of salaried employees (emptype==3) in USD 2021 PPP
        note wage_sedlac: Formula: (hourly_wage_lc × hstrt × 52) × (ipc21_sedlac/ipc_sedlac) / (ppp2021 × conversion)
        note wage_sedlac: Uses SEDLAC CPI data (ipc_sedlac, ipc21_sedlac)
        note wage_sedlac: Country: $current_country (ISO: $current_iso)
        note wage_sedlac: Created on $S_DATE
        
        qui count if emptype == 3 & !missing(wage_sedlac)
        local n_wage_sedlac_created = r(N)
        
        if `n_wage_sedlac_created' > 0 {
            qui sum wage_sedlac if emptype == 3, detail
            noi di "  wage_sedlac created for: `n_wage_sedlac_created' salaried employees"
            noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
        }
        else {
            noi di "  Note: No wage_sedlac values created (no valid data)"
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.7 COMPARE WAGE vs WAGE_SEDLAC
        **# ---------------------------------------------------------------------
        
        if `n_wage_created' > 0 & `n_wage_sedlac_created' > 0 {
            noi di "Step A.7: Comparing wage (IMF) vs wage_sedlac (SEDLAC)..."
            
            * Calculate difference
            gen double wage_diff_pct = ((wage - wage_sedlac) / wage_sedlac) * 100 if emptype == 3
            
            qui sum wage_diff_pct if emptype == 3, detail
            noi di "  Percentage difference ((wage - wage_sedlac)/wage_sedlac × 100):"
            noi di "    Mean: " %8.2f r(mean) "% | Median: " %8.2f r(p50) "%"
            
            qui corr wage wage_sedlac if emptype == 3
            noi di "  Correlation: " %6.4f r(rho)
            
            drop wage_diff_pct
            noi di ""
        }
        
        **# ---------------------------------------------------------------------
        **# A.8 CLEAN UP INTERMEDIATE WAGE VARIABLES
        **# ---------------------------------------------------------------------
        
        drop annual_hours annual_wage_nominal_lc factor_ppp21_wage factor_ppp21_wage_sedlac
        
    }
    
    **# =========================================================================
    **# PART B: EARNINGS CREATION FOR SELF-EMPLOYED AND EMPLOYERS
    **# =========================================================================
    
    noi di ""
    noi di "==========================================================================="
    noi di "PART B: CREATING EARNINGS VARIABLES FOR SELF-EMPLOYED AND EMPLOYERS"
    noi di "==========================================================================="
    noi di ""
    
    **# -------------------------------------------------------------------------
    **# B.1 VERIFY REQUIRED VARIABLES FOR EARNINGS
    **# -------------------------------------------------------------------------
    
    noi di "Step B.1: Verifying required variables for earnings..."
    
    * Check for required variables
    local required_vars_earnings "ila emptype cpiwave cpi2021 ppp2021 conversion ipc_sedlac ipc21_sedlac"
    local missing_vars ""
    
    foreach var of local required_vars_earnings {
        cap confirm variable `var'
        if _rc {
            local missing_vars "`missing_vars' `var'"
        }
    }
    
    if "`missing_vars'" != "" {
        noi di as error "  ERROR: Missing required variables for earnings:`missing_vars'"
        noi di as error "  Skipping earnings creation for this dataset."
        local skip_earnings = 1
    }
    else {
        noi di "  ✓ All required variables for earnings present"
        local skip_earnings = 0
    }
    noi di ""
    
    if `skip_earnings' == 0 {
        
        **# ---------------------------------------------------------------------
        **# B.2 IDENTIFY SELF-EMPLOYED AND EMPLOYERS
        **# ---------------------------------------------------------------------
        
        noi di "Step B.2: Identifying self-employed and employers..."
        
        * Count self-employed and employers
        qui count if emptype == 2
        local n_selfemployed = r(N)
        local pct_selfemployed = (`n_selfemployed' / `n_total') * 100
        
        qui count if emptype == 4
        local n_employers = r(N)
        local pct_employers = (`n_employers' / `n_total') * 100
        
        qui count if inlist(emptype, 2, 4)
        local n_earnings_target = r(N)
        local pct_earnings_target = (`n_earnings_target' / `n_total') * 100
        
        noi di "  Total observations: `n_total'"
        noi di "  Self-employed (emptype==2): `n_selfemployed' (" %5.2f `pct_selfemployed' "%)"
        noi di "  Employers (emptype==4): `n_employers' (" %5.2f `pct_employers' "%)"
        noi di "  Total target for earnings: `n_earnings_target' (" %5.2f `pct_earnings_target' "%)"
        
        * Check data availability
        qui count if inlist(emptype, 2, 4) & !missing(ila)
        local n_with_ila = r(N)
        
        if `n_earnings_target' > 0 {
            local pct_with_ila = (`n_with_ila' / `n_earnings_target') * 100
            noi di "  Self-employed/employers with ila data: `n_with_ila' (" %5.2f `pct_with_ila' "% of target)"
        }
        else {
            noi di "  Note: No self-employed or employers in this dataset"
        }
        
        * Show distribution of monthly labor income if data exists
        if `n_with_ila' > 0 {
            noi di "  Monthly labor income (ila) - Self-employed/employers:"
            qui sum ila if inlist(emptype, 2, 4), detail
            noi di "    Mean: " %12.0f r(mean) " | Median: " %12.0f r(p50) " | SD: " %12.0f r(sd)
            noi di "    Min: " %12.0f r(min) " | Max: " %12.0f r(max)
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.3 CREATE ANNUAL NOMINAL EARNINGS
        **# ---------------------------------------------------------------------
        
        noi di "Step B.3: Creating annual nominal earnings..."
        
        * Calculate annual nominal earnings (monthly × 12)
        gen double annual_earnings_nominal_lc = ila * 12 if inlist(emptype, 2, 4)
        label var annual_earnings_nominal_lc "Annual nominal earnings in local currency"
        
        qui count if inlist(emptype, 2, 4) & !missing(annual_earnings_nominal_lc)
        if r(N) > 0 {
            qui sum annual_earnings_nominal_lc if inlist(emptype, 2, 4), detail
            noi di "  Annual nominal earnings (local currency) - Self-employed/employers:"
            noi di "    Mean: " %12.0f r(mean) " | Median: " %12.0f r(p50)
            noi di "    Non-missing: " r(N)
        }
        else {
            noi di "  Note: No annual earnings values calculated (no valid data)"
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.4 CREATE PPP CONVERSION FACTORS FOR EARNINGS
        **# ---------------------------------------------------------------------
        
        noi di "Step B.4: Creating PPP conversion factors..."
        
        * Create conversion factor using IMF CPI
        gen double factor_ppp21_earnings = (cpi2021 / cpiwave) / (ppp2021 * conversion)
        label var factor_ppp21_earnings "PPP factor for earnings (IMF CPI)"
        
        * Create conversion factor using SEDLAC CPI
        gen double factor_ppp21_earnings_sedlac = (ipc21_sedlac / ipc_sedlac) / (ppp2021 * conversion)
        label var factor_ppp21_earnings_sedlac "PPP factor for earnings (SEDLAC CPI)"
        
        qui count if inlist(emptype, 2, 4) & !missing(factor_ppp21_earnings)
        if r(N) > 0 {
            qui sum factor_ppp21_earnings if inlist(emptype, 2, 4), detail
            noi di "  PPP conversion factor (IMF CPI): Mean = " %8.6f r(mean)
            qui sum factor_ppp21_earnings_sedlac if inlist(emptype, 2, 4), detail
            noi di "  PPP conversion factor (SEDLAC CPI): Mean = " %8.6f r(mean)
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.5 CREATE EARNINGS IN USD 2021 PPP (IMF CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step B.5: Creating earnings (USD 2021 PPP, IMF CPI)..."
        
        * Initialize earnings variable (replace if exists)
        cap drop earnings
        gen double earnings = .
        label var earnings "Annual earnings, USD 2021 PPP (self-employed/employers, IMF CPI)"
        
        * Calculate earnings only for self-employed and employers
        replace earnings = annual_earnings_nominal_lc * factor_ppp21_earnings if inlist(emptype, 2, 4)
        
        * Add notes
        note earnings: Annual labor earnings of self-employed (emptype==2) and employers (emptype==4) in USD 2021 PPP
        note earnings: Formula: (ila × 12) × (cpi2021/cpiwave) / (ppp2021 × conversion)
        note earnings: Uses IMF CPI data (cpiwave, cpi2021)
        note earnings: Country: $current_country (ISO: $current_iso)
        note earnings: Created on $S_DATE
        
        * Summary statistics
        qui count if inlist(emptype, 2, 4) & !missing(earnings)
        local n_earnings_created = r(N)
        
        if `n_earnings_created' > 0 {
            qui sum earnings if inlist(emptype, 2, 4), detail
            noi di "  Earnings created for: `n_earnings_created' self-employed/employers"
            noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
            noi di "    P25: " %12.2f r(p25) " | P75: " %12.2f r(p75)
            noi di "    Min: " %12.2f r(min) " | Max: " %12.2f r(max)
            
            * Check for extreme values
            qui count if inlist(emptype, 2, 4) & earnings < 1000 & !missing(earnings)
            if r(N) > 0 {
                noi di "    NOTE: " r(N) " self-employed/employers with annual earnings < $1,000"
            }
            qui count if inlist(emptype, 2, 4) & earnings > 100000 & !missing(earnings)
            if r(N) > 0 {
                noi di "    NOTE: " r(N) " self-employed/employers with annual earnings > $100,000"
            }
        }
        else {
            noi di "  Note: No earnings values created (no valid data for self-employed/employers)"
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.6 CREATE EARNINGS IN USD 2021 PPP (SEDLAC CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step B.6: Creating earnings_sedlac (USD 2021 PPP, SEDLAC CPI)..."
        
        * Initialize earnings_sedlac variable
        cap drop earnings_sedlac
        gen double earnings_sedlac = .
        label var earnings_sedlac "Annual earnings, USD 2021 PPP (self-employed/employers, SEDLAC CPI)"
        
        * Calculate earnings_sedlac only for self-employed and employers
        replace earnings_sedlac = annual_earnings_nominal_lc * factor_ppp21_earnings_sedlac if inlist(emptype, 2, 4)
        
        * Add notes
        note earnings_sedlac: Annual labor earnings of self-employed (emptype==2) and employers (emptype==4) in USD 2021 PPP
        note earnings_sedlac: Formula: (ila × 12) × (ipc21_sedlac/ipc_sedlac) / (ppp2021 × conversion)
        note earnings_sedlac: Uses SEDLAC CPI data (ipc_sedlac, ipc21_sedlac)
        note earnings_sedlac: Country: $current_country (ISO: $current_iso)
        note earnings_sedlac: Created on $S_DATE
        
        qui count if inlist(emptype, 2, 4) & !missing(earnings_sedlac)
        local n_earnings_sedlac_created = r(N)
        
        if `n_earnings_sedlac_created' > 0 {
            qui sum earnings_sedlac if inlist(emptype, 2, 4), detail
            noi di "  earnings_sedlac created for: `n_earnings_sedlac_created' self-employed/employers"
            noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
        }
        else {
            noi di "  Note: No earnings_sedlac values created (no valid data)"
        }
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.7 COMPARE EARNINGS vs EARNINGS_SEDLAC
        **# ---------------------------------------------------------------------
        
        if `n_earnings_created' > 0 & `n_earnings_sedlac_created' > 0 {
            noi di "Step B.7: Comparing earnings (IMF) vs earnings_sedlac (SEDLAC)..."
            
            * Calculate difference
            gen double earnings_diff_pct = ((earnings - earnings_sedlac) / earnings_sedlac) * 100 if inlist(emptype, 2, 4)
            
            qui sum earnings_diff_pct if inlist(emptype, 2, 4), detail
            noi di "  Percentage difference ((earnings - earnings_sedlac)/earnings_sedlac × 100):"
            noi di "    Mean: " %8.2f r(mean) "% | Median: " %8.2f r(p50) "%"
            
            qui corr earnings earnings_sedlac if inlist(emptype, 2, 4)
            noi di "  Correlation: " %6.4f r(rho)
            
            drop earnings_diff_pct
            noi di ""
        }
        
        **# ---------------------------------------------------------------------
        **# B.8 CLEAN UP INTERMEDIATE EARNINGS VARIABLES
        **# ---------------------------------------------------------------------
        
        drop annual_earnings_nominal_lc factor_ppp21_earnings factor_ppp21_earnings_sedlac
        
    }
    
	**# =========================================================================
    **# COUNTRY-SPECIFIC POST-PROCESSING: ARGENTINA
    **# =========================================================================
    
    * For Argentina: Use SEDLAC CPI as primary (global team preference)
    if "$current_iso" == "ARG" {
        noi di ""
        noi di "==========================================================================="
        noi di "APPLYING ARGENTINA-SPECIFIC VARIABLE ADJUSTMENTS"
        noi di "==========================================================================="
        noi di ""
        noi di "For ARG, global team uses SEDLAC CPI as primary measure."
        noi di "Renaming variables:"
        noi di "  • wage → wage_imf (alternative measure)"
        noi di "  • wage_sedlac → wage (primary measure)"
        noi di "  • earnings → earnings_imf (alternative measure)"
        noi di "  • earnings_sedlac → earnings (primary measure)"
        noi di ""
        
        * Rename IMF-based variables to _imf versions
        cap confirm variable wage
        if !_rc {
            rename wage wage_imf
            label var wage_imf "Annual wage, USD 2021 PPP (salaried, IMF CPI - alternative for ARG)"
            note wage_imf: Alternative measure for Argentina using IMF CPI
            note wage_imf: For ARG analysis, use 'wage' (SEDLAC-based) as primary measure
        }
        
        cap confirm variable earnings
        if !_rc {
            rename earnings earnings_imf
            label var earnings_imf "Annual earnings, USD 2021 PPP (self-emp/employers, IMF CPI - alternative for ARG)"
            note earnings_imf: Alternative measure for Argentina using IMF CPI
            note earnings_imf: For ARG analysis, use 'earnings' (SEDLAC-based) as primary measure
        }
        
        * Rename SEDLAC-based variables to primary versions
        cap confirm variable wage_sedlac
        if !_rc {
            gen wage=wage_sedlac
            label var wage "Annual wage, USD 2021 PPP (salaried, SEDLAC CPI - primary for ARG)"
            note wage: Primary measure for Argentina using SEDLAC CPI
            note wage: Global team standard for ARG. IMF-based alternative available as 'wage_imf'
        }
        
        cap confirm variable earnings_sedlac
        if !_rc {
            gen earnings=earnings_sedlac
            label var earnings "Annual earnings, USD 2021 PPP (self-emp/employers, SEDLAC CPI - primary for ARG)"
            note earnings: Primary measure for Argentina using SEDLAC CPI
            note earnings: Global team standard for ARG. IMF-based alternative available as 'earnings_imf'
        }
        
        noi di "  ✓ Variables renamed successfully"
        noi di ""
    }
	
    **# =========================================================================
    **# FINAL SUMMARY AND SAVE
    **# =========================================================================
    
    noi di ""
    noi di "==========================================================================="
    noi di "FINAL SUMMARY FOR THIS DATASET"
    noi di "==========================================================================="
    noi di ""
    
    * Verify variables are missing for inappropriate employment types
    noi di "Verification: Checking that variables are correctly assigned..."
    
    qui count if emptype != 3 & !missing(wage)
    if r(N) > 0 {
        noi di "  WARNING: " r(N) " non-salaried workers have wage values (should be missing)!"
    }
    else {
        noi di "  ✓ wage: Correctly assigned only to salaried (emptype==3)"
    }
    
    qui count if !inlist(emptype, 2, 4) & !missing(earnings)
    if r(N) > 0 {
        noi di "  WARNING: " r(N) " non-self-employed/employers have earnings values (should be missing)!"
    }
    else {
        noi di "  ✓ earnings: Correctly assigned only to self-employed/employers (emptype==2,4)"
    }
    noi di ""
    
    * Final statistics table
    noi di "  FINAL VARIABLE COVERAGE SUMMARY:"
    noi di "  " _dup(80) "-"
    noi di "  Variable            Employment Type    N Non-missing    Mean (USD)      Median (USD)"
    noi di "  " _dup(80) "-"
    
    * Wage statistics
    qui count if !missing(wage)
    if r(N) > 0 {
        local n_wage = r(N)
        qui sum wage, detail
        local mean_wage = r(mean)
        local med_wage = r(p50)
        noi di "  wage                Salaried (3)       " %10.0f `n_wage' "      " %12.2f `mean_wage' "    " %12.2f `med_wage'
        
        qui count if !missing(wage_sedlac)
        local n_wage_sedlac = r(N)
        qui sum wage_sedlac, detail
        local mean_wage_sedlac = r(mean)
        local med_wage_sedlac = r(p50)
        noi di "  wage_sedlac         Salaried (3)       " %10.0f `n_wage_sedlac' "      " %12.2f `mean_wage_sedlac' "    " %12.2f `med_wage_sedlac'
    }
    else {
        noi di "  wage                Salaried (3)            0          --              --"
        noi di "  wage_sedlac         Salaried (3)            0          --              --"
    }
    
    * Earnings statistics
    qui count if !missing(earnings)
    if r(N) > 0 {
        local n_earnings = r(N)
        qui sum earnings, detail
        local mean_earnings = r(mean)
        local med_earnings = r(p50)
        noi di "  earnings            Self-emp/Emp (2,4) " %10.0f `n_earnings' "      " %12.2f `mean_earnings' "    " %12.2f `med_earnings'
        
        qui count if !missing(earnings_sedlac)
        local n_earnings_sedlac = r(N)
        qui sum earnings_sedlac, detail
        local mean_earnings_sedlac = r(mean)
        local med_earnings_sedlac = r(p50)
        noi di "  earnings_sedlac     Self-emp/Emp (2,4) " %10.0f `n_earnings_sedlac' "      " %12.2f `mean_earnings_sedlac' "    " %12.2f `med_earnings_sedlac'
    }
    else {
        noi di "  earnings            Self-emp/Emp (2,4)      0          --              --"
        noi di "  earnings_sedlac     Self-emp/Emp (2,4)      0          --              --"
    }
    
    noi di "  " _dup(80) "-"
    noi di ""
    
    * Save updated dataset (overwrites original)
	compress
    save "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", replace
    noi di "  ✓ Dataset saved: 01_${current_iso}_`t0'-`t1'_panel.dta"
    noi di ""
    noi di "  " _dup(75) "-"
    noi di ""
    
    * Clear dataset completely to reset Stata between iterations
    clear
}

**# ==============================================================================
**# 3. FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "=== WAGE AND EARNINGS VARIABLE CREATION COMPLETED ==="
noi di "==============================================================================="
noi di ""
noi di "Country: $current_country (ISO: $current_iso)"
noi di "Number of panel datasets processed: `n_combos'"
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
noi di "Variables created:"
noi di ""
noi di "WAGE VARIABLES (Salaried employees, emptype==3):"
noi di "  • wage: Annual wage in USD 2021 PPP (using IMF CPI)"
noi di "  • wage_sedlac: Annual wage in USD 2021 PPP (using SEDLAC CPI)"
noi di "  Formula: (hourly_wage_lc × hstrt × 52) × CPI_ratio / (ppp2021 × conversion)"
noi di ""
noi di "EARNINGS VARIABLES (Self-employed & employers, emptype==2 and emptype==4):"
noi di "  • earnings: Annual earnings in USD 2021 PPP (using IMF CPI)"
noi di "  • earnings_sedlac: Annual earnings in USD 2021 PPP (using SEDLAC CPI)"
noi di "  Formula: (ila × 12) × CPI_ratio / (ppp2021 × conversion)"
noi di ""
noi di "Sample restrictions:"
noi di "  • wage/wage_sedlac: Non-missing ONLY for salaried employees (emptype==3)"
noi di "  • earnings/earnings_sedlac: Non-missing ONLY for self-employed & employers (emptype==2,4)"
noi di "  • All other employment types have missing values as expected"
noi di ""
noi di "==============================================================================="
noi di ""
