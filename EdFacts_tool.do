clear 
set more off

/*
READ ME:

This program is written to compute the adjusted scores for one state, year, 
subject, and grade level at a time. If the user prefers to instead include all states 
in the analysis, take the following steps:

1. enter "all", on line 37. Line should read: local state = "all"
(This is for file naming)
2. remove fips=`state' from lines 60, 67, 95, 99, 153, 157, 162, 166, 172, 176, 182
(These are the lines of code that call data from the Urban Institute Data Portal.
 Removing it will allow the code to call all states.)
3. Place a * in front of line 394. Line should read: *keep if state == `state'

The tool uses EdFacts data from the Urban Institute Education Data Portal. The portal has 
EdFacts data from 2009 - 2016. The user can choose any year within this time 
period to run the analysis. 

The CRDC data used in this file is only available for 2011, 2013, and 2015. If the user
chooses a year without CRDC data available, the code will pull data from the closest
year of data. For example, if the user chooses 2010, the code will use CRDC data from
2011 to complete the analysis. 

*/

* DOWNLOAD educationdata package FROM PORTAL
ssc install libjson 
net install educationdata, replace from("https://urbaninstitute.github.io/education-data-package-stata/")


* CHOOSE PARAMETERS
local year =  2011 // enter year here 
local grade = 8 // enter grade here
local state =  4 // enter state FIPS code here (https://www.mcc.co.mercer.pa.us/dps/state_fips_code_listing.htm)
local sub = "math" // enter 'math' or 'read' here

/* SET FILE PATHS HERE 
*global data = ""  
*global out = "" 
*/

*************************************************************
********* ----------------------------------------- *********
********* ------- DOWNLOAD DATA FROM PORTAL ------- *********
********* ----------------------------------------- *********
*************************************************************

/* 
This section downloads required data from the Urban Institute Education Data Portal 
and saves .dta files to your data directory. It will take several minutes to run. 
*/

**********************************
**** Edfacts proficiency ****
**********************************

educationdata using "school edfacts assessments", sub(year=`year' grade_edfacts=`grade' fips=`state') clear
save "$data/assessments_`year'_ST`state'_G`grade'.dta", replace

*****************************
**** Clean CCD directory ****
*****************************

educationdata using "school ccd directory", csv sub(year=`year' fips=`state') clear 	
drop csa cbsa phone
			
	* format NCESSCH id
		tostring ncessch, replace format("%12.0f")
		replace ncessch = trim(ncessch)
		replace ncessch = "0" + ncessch if strlen(ncessch) == 11
		assert strlen(ncessch) == 12
		
	* make sample restrictions 
		* drop closed/inactive/future schools	
		drop if inlist(school_status,2,6,7)
		
		* keep only regular schools
		keep if school_type == 1
		
		* drop kg (or lower) only schools / adult schools
		drop if inlist(highest_grade_offered,-1,0,14,15)
	
* Save clean directory data
save "$data/CCD_directory_`year'_ST`state'_clean.dta", replace


*****************************
****** Enrollment Data ******
*****************************

* enrollment by gender
educationdata using "school ccd enrollment sex", csv sub(year=`year', fips=`state') clear
save "$data/CCD_enrollment_sex_`year'_ST`state'_G`grade'.dta", replace

* enrollment by race
educationdata using "school ccd enrollment race", csv sub(year=`year' fips=`state') clear
	drop year
	
	* collapse to total enrollment by grade by race (collapse gender)
		keep if sex == 99
		drop sex 
		drop if inlist(grade,-1,15) // ungraded, pre-k
		replace enrollment = 0 if enrollment < 0
	
	* format NCESSCH id
		tostring ncessch, replace format("%12.0f")
		replace ncessch = trim(ncessch)
		replace ncessch = "0" + ncessch if strlen(ncessch) == 11
		assert strlen(ncessch) == 12
		
	* reshape data wide by grade and race
		* wide: race
		ren enrollment enr_
		reshape wide enr_ , i(ncessch grade) j(race)

		* wide: grade
		if (`year' <= 1997) {
			ren (enr_1 enr_2 enr_3 enr_4                   enr_99) ///
				(white black hispa asian                   pop)
			reshape wide white black hispa asian                   pop, i(ncessch) j(grade) 	
		}	
		if (`year' >= 1998 & `year' <= 2007) {
			ren (enr_1 enr_2 enr_3 enr_4 enr_5             enr_99) ///
				(white black hispa asian amind             pop)
			reshape wide white black hispa asian amind             pop, i(ncessch) j(grade)
		}
		if (`year' >= 2008) {
			ren (enr_1 enr_2 enr_3 enr_4 enr_5 enr_6 enr_7 enr_99) ///
				(white black hispa asian amind othra twora pop)
			reshape wide white black hispa asian amind othra twora pop, i(ncessch) j(grade)
		}
			
* save clean enrollment data
save "$data/CCD_enrollment_graderace_`year'_ST`state'_clean.dta", replace

clear


*******************************
********** CRDC Data **********
*******************************

* CHOOSE PARAMETERS
local year =  2013 // enter year here 
local grade = 8 // enter grade here
local state =  56 // enter state FIPS code here (https://www.mcc.co.mercer.pa.us/dps/state_fips_code_listing.htm)
local sub = "math" // enter 'math' or 'read' here
if `year' < 2011 {
* OCR covariates 
educationdata using "school crdc enrollment disability sex", csv sub(year=2011, fips=`state') clear
save "$data/enrollment_k12_`year'_ST`state'.dta", replace

* AP/IB/Gifted Enrollment
educationdata using "school crdc ap-ib-enrollment race sex", csv sub(year=2011, fips=`state') clear
save "$data/apibenroll_`year'_ST`state'.dta" , replace
}
if `year' > 2015 {
* OCR covariates 
educationdata using "school crdc enrollment disability sex", csv sub(year=2015, fips=`state') clear
save "$data/enrollment_k12_`year'_ST`state'.dta", replace

* AP/IB/Gifted Enrollment
educationdata using "school crdc ap-ib-enrollment race sex", csv sub(year=2015, fips=`state') clear
save "$data/apibenroll_`year'_ST`state'.dta" , replace

}
if `year' > 2011 & `year' < 2015 {
* OCR covariates 
educationdata using "school crdc enrollment disability sex", csv sub(year=2013, fips=`state') clear
save "$data/enrollment_k12_`year'_ST`state'.dta", replace

* AP/IB/Gifted Enrollment
educationdata using "school crdc ap-ib-enrollment race sex", csv sub(year=2013, fips=`state') clear
save "$data/apibenroll_`year'_ST`state'.dta" , replace

}
if `year' == 2011 | `year' == 2013 | `year' == 2015 {
* OCR covariates 
educationdata using "school crdc enrollment disability sex", csv sub(year=`year', fips=`state') clear
save "$data/enrollment_k12_`year'_ST`state'.dta", replace

* AP/IB/Gifted Enrollment
educationdata using "school crdc ap-ib-enrollment race sex", csv sub(year=`year', fips=`state') clear
save "$data/apibenroll_`year'_ST`state'.dta" , replace

}


* --------------------------- *
* ------- ADJUSTMENTS ------- *
* --------------------------- *
	
* EdFacts Proficiency Rate
 use "$data/assessments_`year'_St`state'_G`grade'.dta" , clear 
 
 * keep school totals
	local cats race sex lep homeless migrant disability econ_disadvantaged
	foreach c of local cats {
		if mi("`con'") local con `c' == 99 
		else           local con `con' & `c' == 99
	}
	g tottag = (`con')
	keep if tottag == 1
	drop `cats' tottag
	
* get proficiency rate 
	g hasrange_read = read_test_pct_prof_low != read_test_pct_prof_high
	g hasrange_math = math_test_pct_prof_low  != math_test_pct_prof_high

	ren (read_test_pct_prof_midpt math_test_pct_prof_midpt) ///
		(profic_read profic_math) 
	replace profic_read = . if profic_read == -3
	replace profic_math = . if profic_math == -3
	
	ren (read_test_num_valid math_test_num_valid) ///
		(numvalid_read numvalid_math) 
		
	sum has* profic* 

* clean up and save 
	keep ncessch profic* numvalid* 
	save "$data/EdFacts_Proficiency_G`grade'_`year'_ST`state'.dta" , replace 
	
	* CCD 
	use "$data/CCD_enrollment_sex_`year'_ST`state'_G`grade'.dta", clear
	keep if race == 99 & grade == 99 
	drop if sex == 1
	drop race grade
	keep ncessch enrollment sex
	drop if enrollment <= 0 
	reshape wide enrollment, i(ncessch) j(sex) 
	g frac_female = enrollment2 / enrollment99
	replace frac_female = 1 if frac_female > 1 & !mi(frac_female) 
	save "$data/CCD_fracfemale_`year'_ST`state'.dta" , replace 

	* race
	use "$data/CCD_enrollment_graderace_`year'_ST`state'_clean.dta" , clear
	*drop school_id
	merge 1:1 ncessch using "$data/CCD_directory_`year'_ST`state'_clean.dta" 
		keep if _merge == 3
		drop _merge 

	g enroll = pop99 
	local races white black hispa asian amind othra twora
	foreach r of local races {
		g frac_`r' = `r'99 / enroll
	}

	egen enroll68 = rowtotal(pop6 pop7 pop8) , m 
	foreach r of local races {
		egen `r'68 = rowtotal(`r'6 `r'7 `r'8) , m 
		g frac_`r'68 = `r'68 / enroll68
	}

	egen enrollK5 = rowtotal(pop0 pop1 pop2 pop3 pop4 pop5), m

	replace free_or_reduced_price_lunch = . if inlist(free_or_reduced_price_lunch,-1,-2,-3)
	g frac_frl = free_or_reduced_price_lunch  / enroll 
	replace frac_frl = 1 if frac_frl > 1 & !mi(frac_frl) 

	* merge and save
	merge 1:1 ncessch using "$data/CCD_fracfemale_`year'_ST`state'.dta"
		keep if _merge == 3
		drop _merge 
	drop if mi(frac_fem)
	keep ncessch frac_* enroll* school_name lea_name leaid fips city_location state* county_code longitude latitude
	*drop *68
	sum frac_*
	save "$data/CCD_RacialCompFRL_`year'_ST`state'.dta" , replace

* OCR covariates (CRDC)
	use "$data/enrollment_k12_`year'_ST`state'.dta" , replace  
	drop year 

	* collapse by gender and race
	keep if sex == 99 
	drop sex 

	keep if race == 99
	drop race

	* compute fraction lep and disability 
	g tenr = enroll if disability == 99 & lep == 99
	bys ncessch: egen totenroll = mean(tenr) 

	g frac = enrollment / totenroll
	replace frac = 1 if frac > 1 & !mi(frac) 
	preserve 
		egen tags = tag(ncessch) 
		keep if tags == 1
		keep ncessch totenroll
		save "$data/OCR_totalk12enroll_`year'_ST`state'.dta" , replace 
	restore
	drop enroll tenr totenroll
	drop if disability == 99 & lep == 99 
	reshape wide frac lep , i(ncessch) j(disability) 
	isid ncessch 

	g frac_disab = frac1 + frac2
	replace frac_disab = 1 if frac_disab > 1 & !mi(frac_disab) 
	ren frac99 frac_lep

	* clean up and save 
	keep ncessch frac_* 
	save "$data/OCR_Disability&LEPrates_`year'_`state'.dta" , replace

	* gifted 
	use "$data/apibenroll_`year'_ST`state'.dta" , replace 
	keep if sex == 99 & race == 99 & disab == 99 & lep == 99
	drop year sex race disability lep

	merge 1:1 ncessch using "$data/OCR_totalk12enroll_`year'_ST`state'.dta", nogen 
	 
	g frac_gifted = enrl_gifted / totenroll
	replace frac_gifted = 1 if frac_gifted > 1 & !mi(frac_gifted) 

	keep ncessch frac_*
	save "$data/OCR_GTrates_`year'_ST`state'.dta" , replace

*** Merge all , save finalized file 
	* Ed Facts
	use  "$data/EdFacts_Proficiency_G`grade'_`year'_ST`state'.dta" , clear 
	* CCD 
	merge 1:1 ncessch using "$data/CCD_RacialCompFRL_`year'_ST`state'.dta" 
		keep if _merge == 3
		drop _merge
	* OCR
	merge 1:1 ncessch using "$data/OCR_Disability&LEPrates_`year'_`state'.dta"
		drop if _merge == 2
		drop _merge 
	merge 1:1 ncessch using "$data/OCR_GTrates_`year'_ST`state'.dta"
		drop if _merge == 2
		drop _merge
		
* cleanup and save
	g frac_raceoth = frac_amind + frac_othra + frac_twora
	drop frac_amind frac_othra frac_twora
	replace profic_math = profic_math / 100
	replace profic_read = profic_read / 100
	order ncessch school_name leaid lea_name fips city_location state_location county_code
	keep if !mi(profic_math) & !mi(profic_read) 

	replace state_location = "IL" if fips == 17
	
	*
	foreach v in lep gifted disab {
		g mi`v' = mi(frac_`v') 
		replace frac_`v' = 0 if mi`v'
	}

	* 
	save "$data/EdFacts_CCD_OCR_Proficiency_SchoolChars_G`grade'_`year'_ST`state'.dta" , replace

* compute state proficiency rates 
	use "$data/EdFacts_CCD_OCR_Proficiency_SchoolChars_G`grade'_`year'_ST`state'.dta" , clear
	replace state_location = "" if state_location == "-1"
	collapse (mean) profic_math profic_read (firstnm) state_location [w = enroll] , by(fips) 
	replace state_location = "IL" if fips == 17
	replace profic_math = round(profic_math,.01) 
	replace profic_read = round(profic_read,.01) 
	ren profic* proficiency* 
	order state
	outsheet using "$data/EdFacts_StateProficiencyRates_G`grade'_`year'.csv" , comma replace

	* load ed facts data 
	use "$data/EdFacts_CCD_OCR_Proficiency_SchoolChars_G`grade'_`year'_ST`state'.dta" , clear
	g level = `grade'
		
		* keep only appropriate schools
			drop if enroll68 == 0 & level == 8
			drop if enrollK5 == 0 & level == 4
			
		* ed facts agg adjustment 
			local covs frac_black frac_hispa frac_asian frac_raceoth frac_frl ///
				   frac_female frac_lep frac_disab milep midisab
				   
			reg profic_`sub' `covs'
			predict edfacts_profic_r , res
			
		* ed facts, micro (naep) adjustment (state-specific)
			* collect NAEP betas, place in locals
			preserve
				* read raw 
				import excel using "$data/P16_NAEPbetas_G`grade'_wFE_`sub'.xlsx" , clear first
				drop State
				ren stateab stabb
				ren _b_cons constant
				ren _b* *
				
				* keep state
				keep if state == `state'
				
				* collect betas
				local naepcovs black hispanic asian race_other frpl lep female sped constant
				foreach v of local naepcovs {
					qui sum `v'
					local bprofnaep_`v' = r(mean) 
				}
			restore
		
			* adjustment 
			g frac_sped = frac_disab
			ren (frac_frl frac_raceoth frac_hispa) (frac_frpl frac_race_other frac_hispanic) 
			di " "
			di "student level NAEP betas"
			g yhatnaep = `bprofnaep_constant'
			foreach v of local naepcovs {
			if ("`v'" != "constant") {
				replace yhatnaep = yhatnaep + frac_`v' * `bprofnaep_`v''
			}
			}
			replace yhatnaep = yhatnaep + _b[milep] * milep + _b[midisab] * midisab
			* Measure is defined here
			g edfacts_profic_rslnaep = profic_`sub' - yhatnaep
		
		*output
		rename yhatnaep expectedscore
		rename profic_`sub' actual_profic_`sub'
		rename edfacts_profic_rslnaep adjusted
		keep ncessch expectedscore actual_profic_`sub' adjusted
		
		outsheet using "$output/EdFacts_AdjProfic_G`grade'_`sub'_fips`state'_`year'.csv" , comma noq replace 
			
	///////////////////////////////////////////////////////



