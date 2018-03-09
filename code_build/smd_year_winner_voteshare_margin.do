* Program Setup
version 15    			         	// Set Version number for backward compatibility
	// Essential to set version 15; otherwise the candidate's name in Japanese gets garbled.
set more off           			 	// Disable partitioned output
clear all							// Start with a clean slate
capture log close					// Close the log if accidentally still open

*args work_dir 						// Argument taken by this do file: See 16.4.1 of http://www.stata.com/manuals13/u16.pdf
*cd `work_dir'						// Set the working directory

* Table of Contents (the main function)
capture program drop main
program define main
	* Inputs
	local indata_asahi_todai "./input/data_asahi-todai/data/nameid_year_all.csv"
	local indata_election_results "./input/data_japanese-elections/data/lower_house_results.csv"
*	local indata_asahi_todai "../input/data_asahi-todai/data/nameid_year_all.csv"
*	local indata_election_results "../input/data_japanese-elections/data/lower_house_results.csv"
	* Process
	merge_data `indata_asahi_todai' `indata_election_results'
	gen_voteshare_margin
	gen_nameid
	clean_varnames
	* Output
	order ///
		smd_prefecture smd_number year winner      /// Keys
		voteshare_margin                           /// New variable
		smallgov party incumbent former_mp revival /// Variables inherited from input 1
		age terms_served vote voteshare            /// Variables inherited from input 2
		nameid_own nameid_opponent                 /// Foreign keys
		smd_prefecture_name name name_english      // For easing the browsing of data
	keep ///
		smd_prefecture-nameid_opponent
	sort ///
		smd_prefecture smd_number year winner
	capture mkdir ../build_temp
	save_output "./build_temp/smd_year_winner_voteshare_margin.dta"
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
	drop status // This variable is unreliable. 
	* Rename variables to avoid being overwritten during merging
	rename name name_english
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

capture program drop gen_voteshare_margin
program define gen_voteshare_margin
	tempvar winner_voteshare loser_voteshare
	egen `winner_voteshare' = max(voteshare), by(year smd_prefecture smd_number)
	egen `loser_voteshare'  = min(voteshare), by(year smd_prefecture smd_number)
	gen  voteshare_margin = `winner_voteshare' - `loser_voteshare' if winner == 1
	replace voteshare_margin = `loser_voteshare' - `winner_voteshare' if winner == 0
end

capture program drop gen_nameid
program define gen_nameid
	* Own name
	rename nameid nameid_own
	* Opponent's name
	tempvar nameid_winner nameid_loser nameid_winner_temp nameid_loser_temp
	gen `nameid_winner_temp' = nameid if winner == 1
	egen `nameid_winner' = max(`nameid_winner_temp'), by(year smd_prefecture smd_number)
	gen `nameid_loser_temp' = nameid if winner == 0
	egen `nameid_loser' = max(`nameid_loser_temp'), by(year smd_prefecture smd_number)
	egen nameid_opponent = max(`nameid_winner'), by(year smd_prefecture smd_number)
	replace nameid_opponent = `nameid_loser' if winner == 1
end

capture program drop clean_varnames
program define clean_varnames
	rename ku smd_prefecture_name
	rename previous terms_served
	lab var terms_served "# of terms served"
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


