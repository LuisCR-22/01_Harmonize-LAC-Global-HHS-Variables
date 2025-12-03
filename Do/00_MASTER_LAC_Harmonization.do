/*====================================================================
Project: LAC Panel Data Harmonization - MASTER FILE
Author:	Luis Castellanos (lcastellanosrodr@worldbank.org)
Team:	Stats Team - World Bank	
Creation Date:		2025/12/03
Last modification: 	2025/12/03
====================================================================
PURPOSE: Master script that runs the complete harmonization pipeline
         for LAC household survey panel data. Runs three scripts in sequence:
         1. Harmonization to global standards
         2. CPI data merge
         3. Wage and earnings variable creation

USAGE: 
1. Set country_selection macro below
2. Run this master file
3. All three scripts will execute automatically in correct order

COUNTRY OPTIONS: "PER", "ARG", "BRA", "DOM", "SLV"
*=================================================================*/

clear all
set more off

**# ==============================================================================
**# USER CONFIGURATION - SET COUNTRY HERE
**# ==============================================================================

***********************************************
*** CHANGE THIS MACRO TO SELECT COUNTRY   ***
***********************************************
global country_selection "PER"  
* Options: "ARG" (Argentina), "BRA" (Brazil), "DOM" (Dominican Republic), "PER" (Peru), or "SLV" (El Salvador)
***********************************************

**# ==============================================================================
**# VALIDATE COUNTRY SELECTION
**# ==============================================================================

* Check if valid country selected
if !inlist("$country_selection", "PER", "ARG", "BRA", "DOM", "SLV") {
    noi di as error "==============================================================================="
    noi di as error "ERROR: Invalid country_selection"
    noi di as error "==============================================================================="
    noi di as error "Current value: $country_selection"
    noi di as error "Valid options: PER, ARG, BRA, DOM, SLV"
    noi di as error "==============================================================================="
    exit 198
}

**# ==============================================================================
**# SET FILE PATHS
**# ==============================================================================

* Base directory where do-files are located
global dofile_dir "C:\Users\wb593225\Github\01_Harmonize-LAC-Global-HHS-Variables\Do"

* Check if directory exists
cap cd "$dofile_dir"
if _rc {
    noi di as error "==============================================================================="
    noi di as error "ERROR: Do-file directory not found!"
    noi di as error "==============================================================================="
    noi di as error "Expected path: $dofile_dir"
    noi di as error "Please verify the directory exists and update the path if needed."
    noi di as error "==============================================================================="
    exit 601
}

**# ==============================================================================
**# DISPLAY MASTER FILE HEADER
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "=== LAC PANEL DATA HARMONIZATION - MASTER EXECUTION ==="
noi di "==============================================================================="
noi di "Country Selected: $country_selection"
noi di "Start Time: " c(current_time) " on " c(current_date)
noi di ""
noi di "This master file will execute the following scripts in sequence:"
noi di "  1. Harmonization to global standards"
noi di "  2. CPI data merge (IMF and SEDLAC)"
noi di "  3. Wage and earnings variable creation"
noi di ""
noi di "Do-file directory: $dofile_dir"
noi di "==============================================================================="
noi di ""

**# ==============================================================================
**# SCRIPT 1: HARMONIZATION TO GLOBAL STANDARDS
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "STEP 1 OF 3: RUNNING HARMONIZATION SCRIPT"
noi di "==============================================================================="
noi di "Script: 01_ARG_BRA_DOM_PER_SLV_Harmonized.do"
noi di "Purpose: Harmonize panel data to global team variable naming conventions"
noi di "==============================================================================="
noi di ""

* Check if file exists
cap confirm file "$dofile_dir/01_ARG_BRA_DOM_PER_SLV_Harmonized.do"
if _rc {
    noi di as error "ERROR: Harmonization script not found!"
    noi di as error "Expected: $dofile_dir/01_ARG_BRA_DOM_PER_SLV_Harmonized.do"
    exit 601
}

* Run harmonization script
do "$dofile_dir/01_ARG_BRA_DOM_PER_SLV_Harmonized.do"

noi di ""
noi di "✓ STEP 1 COMPLETED: Harmonization finished successfully"
noi di ""

**# ==============================================================================
**# SCRIPT 2: CPI DATA MERGE
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "STEP 2 OF 3: RUNNING CPI MERGE SCRIPT"
noi di "==============================================================================="
noi di "Script: 02_ARG_BRA_DOM_PER_SLV_CPI_2019-2023.do"
noi di "Purpose: Merge IMF CPI data (cpiwave and cpi2021) to harmonized panels"
noi di "==============================================================================="
noi di ""

* Check if file exists
cap confirm file "$dofile_dir/02_ARG_BRA_DOM_PER_SLV_CPI_2019-2023.do"
if _rc {
    noi di as error "ERROR: CPI merge script not found!"
    noi di as error "Expected: $dofile_dir/02_ARG_BRA_DOM_PER_SLV_CPI_2019-2023.do"
    exit 601
}

* Run CPI merge script
do "$dofile_dir/02_ARG_BRA_DOM_PER_SLV_CPI_2019-2023.do"

noi di ""
noi di "✓ STEP 2 COMPLETED: CPI data merged successfully"
noi di ""

**# ==============================================================================
**# SCRIPT 3: WAGE AND EARNINGS CREATION
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "STEP 3 OF 3: RUNNING WAGE AND EARNINGS SCRIPT"
noi di "==============================================================================="
noi di "Script: 03_ARG_BRA_DOM_PER_SLV_wage_2019-2023.do"
noi di "Purpose: Create annual wage and earnings variables in USD 2021 PPP"
noi di "==============================================================================="
noi di ""

* Check if file exists
cap confirm file "$dofile_dir/03_ARG_BRA_DOM_PER_SLV_wage_2019-2023.do"
if _rc {
    noi di as error "ERROR: Wage/earnings script not found!"
    noi di as error "Expected: $dofile_dir/03_ARG_BRA_DOM_PER_SLV_wage_2019-2023.do"
    exit 601
}

* Run wage and earnings script
do "$dofile_dir/03_ARG_BRA_DOM_PER_SLV_wage_2019-2023.do"

noi di ""
noi di "✓ STEP 3 COMPLETED: Wage and earnings variables created successfully"
noi di ""

**# ==============================================================================
**# FINAL SUMMARY
**# ==============================================================================

noi di ""
noi di "==============================================================================="
noi di "=== MASTER EXECUTION COMPLETED SUCCESSFULLY ==="
noi di "==============================================================================="
noi di "Country: $country_selection"
noi di "End Time: " c(current_time) " on " c(current_date)
noi di ""
noi di "All three scripts executed successfully:"
noi di "  ✓ Step 1: Harmonization to global standards"
noi di "  ✓ Step 2: CPI data merge (IMF and SEDLAC)"
noi di "  ✓ Step 3: Wage and earnings variable creation"
noi di ""
noi di "Output datasets created in:"
if "$country_selection" == "PER" {
    noi di "  C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\PER"
}
else if "$country_selection" == "ARG" {
    noi di "  C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\ARG"
}
else if "$country_selection" == "BRA" {
    noi di "  C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\BRA"
}
else if "$country_selection" == "DOM" {
    noi di "  C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\DOM"
}
else if "$country_selection" == "SLV" {
    noi di "  C:\Users\wb593225\OneDrive - WBG\Desktop\Shared\FY2026\03_Global_team\Dta\SLV"
}
noi di ""
noi di "All panel datasets now include:"
noi di "  • Harmonized variable names (global team standards)"
noi di "  • CPI variables (cpiwave, cpi2021)"
noi di "  • Annual wage variables (USD 2021 PPP, salaried employees)"
noi di "  • Annual earnings variables (USD 2021 PPP, self-employed/employers)"
noi di ""
noi di "To process a different country, change the country_selection macro"
noi di "at the top of this master file and run again."
noi di "==============================================================================="
noi di ""
