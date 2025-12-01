/*====================================================================
Project: Creating Annual Wage and Earnings Variables for Harmonized LAC Panel Datasets
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/12/01
Last modification: 	2025/12/01
====================================================================
PURPOSE: This script creates annual wage and earnings variables in USD 2021 PPP
         using different income measures by employment type. Creates two versions
         of each (IMF CPI and SEDLAC CPI) for comparison purposes.

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
**# 0. SETUP AND PATHS
**# ==============================================================================

global wdir "C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team"
global output_data "$wdir\Dta\PER"

* Country-specific settings (must match previous scripts)
global current_country "Peru"
global current_iso "PER"

* Define year combinations (must match previous scripts)
if "$current_country" == "Peru" {
    local combo1 "2019 2021"
    local combo2 "2021 2022"
    local combo3 "2022 2023"
    local combo4 "2019 2023"
    local n_combos = 4
}

noi di ""
noi di "=== CREATING ANNUAL WAGE AND EARNINGS VARIABLES ==="
noi di "Country: $current_country (ISO: $current_iso)"
noi di ""

**# ==============================================================================
**# 1. LOOP THROUGH PANEL DATASETS
**# ==============================================================================

forvalues i = 1/`n_combos' {
    
    * Parse the year combination
    tokenize `combo`i''
    local t0 = `1'
    local t1 = `2'
    
    noi di "=========================================================================="
    noi di "Processing: 01_${current_iso}_`t0'-`t1'_panel.dta"
    noi di "=========================================================================="
    noi di ""
    
    * Load panel dataset
    use "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", clear
    
    * Store original number of observations
    local n_total = _N
    
    **# =========================================================================
    **# PART A: WAGE CREATION FOR SALARIED EMPLOYEES (emptype==3)
    **# =========================================================================
    
    noi di "=========================================================================="
    noi di "PART A: CREATING WAGE VARIABLES FOR SALARIED EMPLOYEES"
    noi di "=========================================================================="
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
        noi di "  ERROR: Missing required variables for wage:`missing_vars'"
        noi di "  Skipping wage creation for this dataset."
        local skip_wage = 1
    }
    else {
        noi di "  All required variables for wage present: OK"
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
        local pct_with_data = (`n_with_wage_hours' / `n_salaried') * 100
        
        noi di "  Salaried with wage & hours data: `n_with_wage_hours' (" %5.2f `pct_with_data' "% of salaried)"
        
        * Show distribution of hours for salaried employees
        noi di "  Hours worked per week (hstrt) - Salaried employees:"
        qui sum hstrt if emptype == 3, detail
        noi di "    Mean: " %6.2f r(mean) " | Median: " %6.2f r(p50) " | SD: " %6.2f r(sd)
        noi di "    Min: " %6.2f r(min) " | Max: " %6.2f r(max)
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
        
        qui sum annual_wage_nominal_lc if emptype == 3, detail
        noi di "  Annual nominal wage (local currency) - Salaried employees:"
        noi di "    Mean: " %12.0f r(mean) " | Median: " %12.0f r(p50)
        noi di "    Non-missing: " r(N)
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
        
        qui sum factor_ppp21_wage if emptype == 3, detail
        noi di "  PPP conversion factor (IMF CPI): Mean = " %8.6f r(mean)
        qui sum factor_ppp21_wage_sedlac if emptype == 3, detail
        noi di "  PPP conversion factor (SEDLAC CPI): Mean = " %8.6f r(mean)
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.5 CREATE WAGE IN USD 2021 PPP (IMF CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step A.5: Creating wage (USD 2021 PPP, IMF CPI)..."
        
        * Initialize wage variable (replace placeholder)
        cap drop wage
        gen double wage = .
        label var wage "Annual wage, USD 2021 PPP (salaried, IMF CPI)"
        
        * Calculate wage only for salaried employees
        replace wage = annual_wage_nominal_lc * factor_ppp21_wage if emptype == 3
        
        * Add notes
        note wage: Annual wage of salaried employees (emptype==3) in USD 2021 PPP
        note wage: Formula: (hourly_wage_lc × hstrt × 52) × (cpi2021/cpiwave) / (ppp2021 × conversion)
        note wage: Uses IMF CPI data (cpiwave, cpi2021)
        note wage: Created on $S_DATE
        
        * Summary statistics
        qui count if emptype == 3 & !missing(wage)
        local n_wage_created = r(N)
        
        qui sum wage if emptype == 3, detail
        noi di "  Wage created for: `n_wage_created' salaried employees"
        noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
        noi di "    Min: " %12.2f r(min) " | Max: " %12.2f r(max)
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
        note wage_sedlac: Created on $S_DATE
        
        qui count if emptype == 3 & !missing(wage_sedlac)
        local n_wage_sedlac_created = r(N)
        
        qui sum wage_sedlac if emptype == 3, detail
        noi di "  wage_sedlac created for: `n_wage_sedlac_created' salaried employees"
        noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# A.7 COMPARE WAGE vs WAGE_SEDLAC
        **# ---------------------------------------------------------------------
        
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
        
        **# ---------------------------------------------------------------------
        **# A.8 CLEAN UP INTERMEDIATE WAGE VARIABLES
        **# ---------------------------------------------------------------------
        
        drop annual_hours annual_wage_nominal_lc factor_ppp21_wage factor_ppp21_wage_sedlac
        
    }
    
    **# =========================================================================
    **# PART B: EARNINGS CREATION FOR SELF-EMPLOYED AND EMPLOYERS
    **# =========================================================================
    
    noi di ""
    noi di "=========================================================================="
    noi di "PART B: CREATING EARNINGS VARIABLES FOR SELF-EMPLOYED AND EMPLOYERS"
    noi di "=========================================================================="
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
        noi di "  ERROR: Missing required variables for earnings:`missing_vars'"
        noi di "  Skipping earnings creation for this dataset."
        local skip_earnings = 1
    }
    else {
        noi di "  All required variables for earnings present: OK"
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
        local pct_with_ila = (`n_with_ila' / `n_earnings_target') * 100
        
        noi di "  Self-employed/employers with ila data: `n_with_ila' (" %5.2f `pct_with_ila' "% of target)"
        
        * Show distribution of monthly labor income
        noi di "  Monthly labor income (ila) - Self-employed/employers:"
        qui sum ila if inlist(emptype, 2, 4), detail
        noi di "    Mean: " %12.0f r(mean) " | Median: " %12.0f r(p50) " | SD: " %12.0f r(sd)
        noi di "    Min: " %12.0f r(min) " | Max: " %12.0f r(max)
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.3 CREATE ANNUAL NOMINAL EARNINGS
        **# ---------------------------------------------------------------------
        
        noi di "Step B.3: Creating annual nominal earnings..."
        
        * Calculate annual nominal earnings (monthly × 12)
        gen double annual_earnings_nominal_lc = ila * 12 if inlist(emptype, 2, 4)
        label var annual_earnings_nominal_lc "Annual nominal earnings in local currency"
        
        qui sum annual_earnings_nominal_lc if inlist(emptype, 2, 4), detail
        noi di "  Annual nominal earnings (local currency) - Self-employed/employers:"
        noi di "    Mean: " %12.0f r(mean) " | Median: " %12.0f r(p50)
        noi di "    Non-missing: " r(N)
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
        
        qui sum factor_ppp21_earnings if inlist(emptype, 2, 4), detail
        noi di "  PPP conversion factor (IMF CPI): Mean = " %8.6f r(mean)
        qui sum factor_ppp21_earnings_sedlac if inlist(emptype, 2, 4), detail
        noi di "  PPP conversion factor (SEDLAC CPI): Mean = " %8.6f r(mean)
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.5 CREATE EARNINGS IN USD 2021 PPP (IMF CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step B.5: Creating earnings (USD 2021 PPP, IMF CPI)..."
        
        * Initialize earnings variable (replace placeholder)
        cap drop earnings
        gen double earnings = .
        label var earnings "Annual earnings, USD 2021 PPP (self-employed/employers, IMF CPI)"
        
        * Calculate earnings only for self-employed and employers
        replace earnings = annual_earnings_nominal_lc * factor_ppp21_earnings if inlist(emptype, 2, 4)
        
        * Add notes
        note earnings: Annual labor earnings of self-employed (emptype==2) and employers (emptype==4) in USD 2021 PPP
        note earnings: Formula: (ila × 12) × (cpi2021/cpiwave) / (ppp2021 × conversion)
        note earnings: Uses IMF CPI data (cpiwave, cpi2021)
        note earnings: Created on $S_DATE
        
        * Summary statistics
        qui count if inlist(emptype, 2, 4) & !missing(earnings)
        local n_earnings_created = r(N)
        
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
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.6 CREATE EARNINGS IN USD 2021 PPP (SEDLAC CPI)
        **# ---------------------------------------------------------------------
        
        noi di "Step B.6: Creating earnings_sedlac (USD 2021 PPP, SEDLAC CPI)..."
        
        * Initialize earnings_sedlac variable
        gen double earnings_sedlac = .
        label var earnings_sedlac "Annual earnings, USD 2021 PPP (self-employed/employers, SEDLAC CPI)"
        
        * Calculate earnings_sedlac only for self-employed and employers
        replace earnings_sedlac = annual_earnings_nominal_lc * factor_ppp21_earnings_sedlac if inlist(emptype, 2, 4)
        
        * Add notes
        note earnings_sedlac: Annual labor earnings of self-employed (emptype==2) and employers (emptype==4) in USD 2021 PPP
        note earnings_sedlac: Formula: (ila × 12) × (ipc21_sedlac/ipc_sedlac) / (ppp2021 × conversion)
        note earnings_sedlac: Uses SEDLAC CPI data (ipc_sedlac, ipc21_sedlac)
        note earnings_sedlac: Created on $S_DATE
        
        qui count if inlist(emptype, 2, 4) & !missing(earnings_sedlac)
        local n_earnings_sedlac_created = r(N)
        
        qui sum earnings_sedlac if inlist(emptype, 2, 4), detail
        noi di "  earnings_sedlac created for: `n_earnings_sedlac_created' self-employed/employers"
        noi di "    Mean: " %12.2f r(mean) " | Median: " %12.2f r(p50)
        noi di ""
        
        **# ---------------------------------------------------------------------
        **# B.7 COMPARE EARNINGS vs EARNINGS_SEDLAC
        **# ---------------------------------------------------------------------
        
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
        
        **# ---------------------------------------------------------------------
        **# B.8 CLEAN UP INTERMEDIATE EARNINGS VARIABLES
        **# ---------------------------------------------------------------------
        
        drop annual_earnings_nominal_lc factor_ppp21_earnings factor_ppp21_earnings_sedlac
        
    }
    
    **# =========================================================================
    **# FINAL SUMMARY AND SAVE
    **# =========================================================================
    
    noi di ""
    noi di "=========================================================================="
    noi di "FINAL SUMMARY FOR THIS DATASET"
    noi di "=========================================================================="
    noi di ""
    
    * Verify variables are missing for inappropriate employment types
    noi di "Verification: Checking that variables are correctly assigned..."
    
    qui count if emptype != 3 & !missing(wage)
    if r(N) > 0 {
        noi di "  WARNING: " r(N) " non-salaried workers have wage values (should be missing)!"
    }
    else {
        noi di "  wage: Correctly assigned only to salaried (emptype==3) - OK"
    }
    
    qui count if !inlist(emptype, 2, 4) & !missing(earnings)
    if r(N) > 0 {
        noi di "  WARNING: " r(N) " non-self-employed/employers have earnings values (should be missing)!"
    }
    else {
        noi di "  earnings: Correctly assigned only to self-employed/employers (emptype==2,4) - OK"
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
    
    noi di "  " _dup(80) "-"
    noi di ""
    
    * Save updated dataset (overwrites original)
    save "$output_data/01_${current_iso}_`t0'-`t1'_panel.dta", replace
    noi di "  Dataset saved: 01_${current_iso}_`t0'-`t1'_panel.dta"
    noi di ""
    noi di ""
}

**# ==============================================================================
**# 2. FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "=========================================================================="
noi di "=== WAGE AND EARNINGS VARIABLE CREATION COMPLETED ==="
noi di "=========================================================================="
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
    noi di "  - 01_${current_iso}_`t0'-`t1'_panel.dta"
}
noi di ""
noi di "Variables created:"
noi di ""
noi di "WAGE VARIABLES (Salaried employees, emptype==3):"
noi di "  - wage: Annual wage in USD 2021 PPP (using IMF CPI)"
noi di "  - wage_sedlac: Annual wage in USD 2021 PPP (using SEDLAC CPI)"
noi di "  Formula: (hourly_wage_lc × hstrt × 52) × CPI_ratio / (ppp2021 × conversion)"
noi di ""
noi di "EARNINGS VARIABLES (Self-employed & employers, emptype==2 and emptype==4):"
noi di "  - earnings: Annual earnings in USD 2021 PPP (using IMF CPI)"
noi di "  - earnings_sedlac: Annual earnings in USD 2021 PPP (using SEDLAC CPI)"
noi di "  Formula: (ila × 12) × CPI_ratio / (ppp2021 × conversion)"
noi di ""
noi di "Sample restrictions:"
noi di "  - wage/wage_sedlac: Non-missing ONLY for salaried employees (emptype==3)"
noi di "  - earnings/earnings_sedlac: Non-missing ONLY for self-employed & employers (emptype==2,4)"
noi di "  - All other employment types have missing values as expected"
noi di ""
noi di "=========================================================================="
noi di ""