/*-------------------------------------------------------------------------------
# Name:			01a_TransactionCount
# Purpose:		Process Foreign Assistance data for visualization in AGOL
# Author:		Tim Essam, Ph.D.
# Created:		22/01/2014
# Copyright:	USAID GeoCenter
# License:		<Tim Essam Consulting/OakStream Systems, LLC>
# Ado(s):		confirmdir, mvfiles, fs, tab3way, confirmdir, mvfiles, fs
# Dependencies: none
#-------------------------------------------------------------------------------
*/

* Open the full FAD and view contents
clear
capture log close
log using "$pathlog/02_TransactionCount.log", replace

* Check if data have been downloaded, if not download and open
cd "$pathin"
local Required_file Full_ForeignAssistanceData_Transaction
foreach x of local Required_file { 
	 capture findfile `x'.zip
		if _rc==601 {
			copy http://www.foreignassistance.gov/web/Documents/Full_ForeignAssistanceData_Transaction.zip $pathin/Full_ForeignAssistanceData_Transaction.zip, replace 
			unzipfile $pathin/Full_ForeignAssistanceData_Transaction.zip, replace
			* Create an exit conditions based on whether or not file is found.
			*if _rc==601 exit = 1
		}
		else disp in yellow "`x' already downloaded and unzipped to Pathin folder." 
		}
*end

* Import the Planned data (may have to change the cellrange)
set excelxlsxlargefile on
import excel "$pathin\Full_ForeignAssistanceData_Transaction.xlsx"
set more off

* Replace variable names with strings from first row
foreach var of varlist * {
  label variable `var' "`=`var'[1]'"
  replace `var'="" if _n==1
  destring `var', replace
}
*end

*Create variable names from variable labels
foreach var of varlist _all {
        local label : variable label `var'
        local new_name = lower(strtoname("`label'"))
        rename `var' `new_name'
}
*end

drop in 1
isid id
compress

* Filter on USAID & FY2013
keep if agency=="USAID"
keep if fy==2013

* Save a copy so you don't have to go through long excel open each time
save "$pathout/transactions.dta", replace

keep if disbursed_amount!=0
ren organizational unit organizational_unit

* Count the number of non-zero transactions by 
collapse (count) disbursed_amount , by(organizational_unit)
clonevar Country = organizational_unit

replace Country = "Bosnia and Herzegovina" if Country == "Bosnia-Hercegovina"
replace Country = "China" if Country == "China, People's Republic"
replace Country = "Taiwan" if Country == "China, Republic of (Taiwan)"
replace Country = "Kyrgyzstan" if Country == "Kyrgyz Republic"
replace Country = "Democratic Republic of the Congo" if Country == "Congo, Democratic Republic of"
replace Country = "Republic of the Congo" if Country == "Congo, Republic of"
replace Country = "The Gambia" if Country == "Gambia, The"
replace Country = "North Korea" if Country == "Korea, North"
replace Country = "South Korea" if Country == "Korea, Republic of"
replace Country = "Federated States of Micronesia" if Country == "Micronesia"
replace Country = "Moldova" if Country == "Moldovia"
replace Country = "Sudan" if Country == "North Sudan"
replace Country = "Palau" if Country == "Palau Islands"
replace Country = "Somoa" if Country == "Western Samoa"
replace Country = "West Bank-Gaza" if Country=="West Bank and Gaza"
replace Country = "South Korea" if Country=="Korea, South"
replace Country = "Syria" if Country=="Syrian Arab Republic"
replace Country = "Barbados" if Country=="Barbados and Eastern Caribbean"
drop if regexm(Country, "(USAID|Region|Worldwide)")
replace Country = upper(Country)

save "$pathout/transactionsCounts.dta", replace

