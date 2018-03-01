* Program Setup
version 13    			         	// Set Version number for backward compatibility
set more off           			 	// Disable partitioned output
clear all							// Start with a clean slate
capture log close					// Close the log if accidentally still open

*args work_dir 						// Argument taken by this do file: See 16.4.1 of http://www.stata.com/manuals13/u16.pdf
*cd `work_dir'						// Set the working directory

* Table of Contents (the main function)
capture program drop main
program define main
	* Inputs
	local indata_asahi_todai "../input/data_asahi-todai/data/nameid_year_all.csv"
	local indata_election_results "../input/data_japanese-elections/data/lower_house_results.csv"
	* Process
	merge_data `indata_asahi_todai' `indata_election_results'
	
	* Output
*	capture mkdir ../build_temp
*	save_output "../build_temp/district_year_reelect.dta"
end

* Subfunctions that appear within the main function
capture program drop merge_data
program define merge_data
	args candidates election_results
	* Clean up election results data
	import delimited `election_results', clear
	* Drop election results that won't be matched with Asahi-Todai data
	keep if year == 2003 | year == 2005 | year == 2009 | year == 2012 | year == 2014
	* Drop unnecessary variables
	drop party mag exp exppv ldp dpj poh
	* Keep only the winner and the runner-up
	keep if rank == 1 | rank == 2
	gen winner = rank == 1
	* Prepare for merging
	rename prefecture_code smd_prefecture
	rename kun smd_number
	rename party_code party 	
	* Temporarily save
	tempfile results
	save `results', replace
	* Work on the candidate data
	import delimited `candidates', encoding(utf8) clear
	* Keep Lower House election candidates only
	keep if year == 2003 | year == 2005 | year == 2009 | year == 2012 | year == 2014
	* Keep SMD candidates only
	drop if smd_prefecture == .
	* Drop multiple independent / small party candidates who weren't ranked 1st or 2nd
	tempvar group one sum to_be_dropped
	egen `group' = group(year smd_prefecture smd_number party winner)
	gen `one' = 1
	egen `sum' = total(`one'), by(`group')
	gen `to_be_dropped' = party == 97 | party == 99 if `sum' > 1 // Missing for districts with only `one' independent candidate
	replace `to_be_dropped' = 0 if winner == 1 // Independents who won
	replace `to_be_dropped' = 0 if year == 2003 & id == 41  // Hokuto Yokoyama (runner-up)
	replace `to_be_dropped' = 0 if year == 2003 & id == 361  // Hajime Yatagawa (runner-up)
	replace `to_be_dropped' = 0 if year == 2003 & id == 455 // Masayuki Fujishima (runner-up)
	replace `to_be_dropped' = 0 if year == 2003 & id == 695 // Ma`sum'i Ogawa (runner-up)
	replace `to_be_dropped' = 0 if year == 2003 & id == 817 // Hiroshi Hiraguchi (runner-up)
	replace `to_be_dropped' = 0 if year == 2005 & id == 808 // Takafumi Horie (runner-up)
	replace `to_be_dropped' = 0 if year == 2009 & id == 48  // Jun Tsushima (runner-up)
	replace `to_be_dropped' = 0 if year == 2009 & id == 520  // Yoshihiko Aimoto (runner-up)
	replace `to_be_dropped' = 0 if year == 2009 & id == 1100  // Nariaki Nakayama (runner-up)
	replace `to_be_dropped' = 0 if year == 2012 & id == 284  // Toshikazu Morita (runner-up)
	replace `to_be_dropped' = 0 if year == 2012 & id == 1202  // Shintaro Okumura (runner-up)
	replace `to_be_dropped' = 0 if year == 2014 & id == 104  // Juichi Abe (runner-up)
	drop if `to_be_dropped' == 1
	* Merge
	merge 1:1 year smd_prefecture smd_number party winner using `results', assert(match master) keep(match) // Using data should not be left alone
	unit_test
end

capture program drop unit_test
program define unit_test
	tempvar group one count
	egen `group' = group(year smd_prefecture smd_number)
	gen `one' = 1
	egen `count' = total(`one'), by(`group')
	assert `count' == 2 if _merge == 3
	drop _merge
end

capture program drop save_output
program define save_output
	args filename
	display "Saving disk space"
	compress
	display "Saving as Stata data"
	save `filename', replace
end

* Internal functions that appear within the subfunctions

* Execute the whole script
*log using "./log/*.log", replace // Keep the log
set trace on						// Trace the execution of the program line by line
main
set trace off						// Turn off the tracing

* Closing commands
*log close							// Close the log
*exit, STATA clear					// Exit Stata 


