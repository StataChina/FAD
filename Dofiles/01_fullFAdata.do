/*-------------------------------------------------------------------------------
# Name:			01_fullFAdata
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
log using "$pathlog/FullFAD.log", replace
import excel "$pathin\Full_ForeignAssistanceData.xlsx", sheet("Planned") cellrange(A3:H19752) firstrow
g type = "Planned"
destring FiscalYear, replace

*Keep only USAID/DOS streams
keep if regexm(AgencyName, "(DOS and USAID)")==1
save "$pathout\FullPlanned.dta", replace

*************
* Obligated *
*************
clear
import excel "$pathin\Full_ForeignAssistanceData.xlsx", sheet("Obligated") cellrange(A3:J19752) firstrow
g type = "Obligated"

* Keep only USAID funded entries
keep if regexm(AgencyName, "(USAID)")==1

* Create a unique ID for each observation
egen id = group(FiscalYear QTR AccountName OperatingUnit BenefitingCountry Category Sector)
sort id FiscalYear

* Clean up missing information
replace Category="Multi-Sector" if Category==""

* Collapse everything down to FY status
egen fyAmount = total(Amount), by(FiscalYear  AccountName OperatingUnit BenefitingCountry Category Sector)

* Verify collapse by looking at OperatingUnit=="Armenia" & Sector=="Civil Society" & FiscalYear==2009
clist Amount  if OperatingUnit=="Armenia" & Sector=="Civil Society" & FiscalYear==2009, noo

* Collapse information down to FY
collapse (sum) Amount (mean) fyAmount, by(FiscalYear  AccountName OperatingUnit BenefitingCountry Category Sector type AgencyName)
g diff = Amount- fyAmount
sum diff, d

save "$pathout\FullObligated.dta", replace
clear

*********
* Spent *
*********

import excel "$pathin\Full_ForeignAssistanceData.xlsx", sheet("Spent") cellrange(A3:J62540) firstrow clear
g type = "Spent"
keep if regexm(AgencyName, "(USAID)")==1

* Clean up missing information
replace Category="Multi-Sector" if Category==""

* Create a unique ID for each observation
egen id = group(FiscalYear QTR AccountName OperatingUnit BenefitingCountry Category Sector)
sort id FiscalYear


* Collapse everything down to FY status
egen fyAmount = total(Amount), by(FiscalYear  AccountName OperatingUnit BenefitingCountry Category Sector)

* Verify collapse by looking at OperatingUnit=="Armenia" & Sector=="Civil Society" & FiscalYear==2009
table OperatingUnit Sector if OperatingUnit=="Armenia" & Sector=="Civil Society" & FiscalYear==2009, c(sum Amount mean fyAmount) row col

* Collapse information down to FY
collapse (sum) Amount (mean) fyAmount, by(FiscalYear  AccountName OperatingUnit BenefitingCountry Category Sector type AgencyName)
g diff = Amount- fyAmount
sum diff, d

save "$pathout\FullSpent.dta", replace

append using "$pathout/FullObligated.dta"
compress
*append using "$pathout/FullPlanned.dta"

encode type, gen(fundType)
la var type "Foreign assistance type"
la var fundType "encoded Foreign assistance type"

save "$pathout/FADcombined.dta", replace

/* First consider spent data */
*******************************

use "$pathout/FullSpent.dta", clear

*Print a list of Operating units covered save in log folder
cd "$pathlog"
file open myfile using "$pathlog/BeneficiaryList.txt", write replace
qui levelsof OperatingUnit, local(levels)
foreach x of local levels {
	file write myfile %133s "`x'" _tab _n
	}
file close myfile

* Create variables for AGOL mapping exercise
mdesc

* First, look at the possibility of duplicates
drop if Amount==0

*Combination of FY AN OU C & S provide unique identifer
isid FiscalYear AccountName OperatingUnit BenefitingCountry Category Sector


* Calculate aggregates overtime, and by sector overtime
egen TotalSpent = total(Amount), by(OperatingUnit)
egen TotalSectorSpent = total(Amount), by(Category OperatingUnit)
g TotalSectorShare = (TotalSectorSpent/TotalSpent)

* Now, totals and shares by country, by fiscal year
egen AnnualSpent = total(Amount), by(OperatingUnit FiscalYear)
egen AnnualSectorSpent = total(Amount), by(Category OperatingUnit FiscalYear)
g AnnualSectorShare = AnnualSectorSpent/AnnualSpent
sort FiscalYear

* label variables
la var TotalSpent "Total spending for all FYs"
la var TotalSectorSpent "Total sectoral spending for all FYs"
la var TotalSectorShare "Sectoral Share of total spending for all FYs"
la var AnnualSpent "Total annual spending by operating unit"
la var AnnualSectorSpent "Total sectoral annual spending by operating unit"
la var AnnualSectorShare "Total sectoral annual share by operating unit"

* preserve
collapse (mean) TotalSpent TotalSectorSpent TotalSectorShare AnnualSpent AnnualSectorSpent AnnualSectorShare, by(FiscalYear OperatingUnit Category)
encode OperatingUnit, gen(country)

* Create a sector rank variable
egen sectRank = rank(AnnualSectorSpent), by(FiscalYear Category) f

egen cyid = group(OperatingUnit Category FiscalYear)
xtset cyid FiscalYear

* Generate percent change for each Category
encode Category, gen(sector)

set more off
g pctChange=.
g pctChange2=.
levelsof country, local(place)
levelsof sector, local(levels)
foreach x of local place {
	foreach y of local levels {
			replace pctChange=(AnnualSectorSpent[_n]-AnnualSectorSpent[_n-1])/AnnualSectorSpent[_n-1] if country[_n]==`x' & sector[_n]==`y' & sector[_n]==sector[_n-1]
			replace pctChange2=(AnnualSectorSpent[_n]-AnnualSectorSpent[_n-1])/AnnualSectorSpent[_n-1] if country[_n]==`x' & sector[_n]==`y' & sector[_n]==sector[_n-1] & AnnualSectorSpent[_n-1]>0
		}	
	}
*end

la var pctChange "Year-to-year percentage change in spending by sector"
la var pctChange2 "Year-to-year percentage change in spending by sector only for positive spending"

*Double-check that all shares sum to 1
egen shareValidate = total(AnnualSectorShare), by(OperatingUnit FiscalYear)

*At the Global scale what does the Breakdown look like by sector, by year?
egen WorldAnnualSpent = total(AnnualSpent), by(FiscalYear)
egen WorldAnnualSpentSector = total(AnnualSpent), by(Category FiscalYear)
g WorldAnnualSectorShare =WorldAnnualSpentSector/WorldAnnualSpent

la var WorldAnnualSpent "Total aggregate spending by FY"
la var WorldAnnualSpentSector "Total sectoral aggregate spending by FY"
la var WorldAnnualSectorShare "Total sectoral aggregate share by FY"
compress
g Aidtype = "Spent"
la var Aidtype "Type of assistance"

save "$pathout\AnnualSpent.dta", replace

************************************************
/* Create similar analysis for Disbursed funds */
*********************************************** 

use "$pathout/FullObligated.dta", clear
* Keep only USAID spending
*No USAID spending reported for FY2013

keep if AgencyName=="USAID"
destring FiscalYear, replace
la var type "Type of foreign aid"

* Create variables for AGOL mapping exercise
mdesc

* First, look at the possibility of duplicates
drop if Amount==0
bysort FiscalYear AccountName OperatingUnit Category Sector: gen count=_n
tab count
*Combination of FY AN OU C & S provide unique identifer

* Calculate aggregates overtime, and by sector overtime
egen TotalSpent = total(Amount), by(OperatingUnit)
egen TotalSectorSpent = total(Amount), by(Category OperatingUnit)
g TotalSectorShare = (TotalSectorSpent/TotalSpent)

*Now, totals and shares by country, by fiscal year
egen AnnualSpent = total(Amount), by(OperatingUnit FiscalYear)
egen AnnualSectorSpent = total(Amount), by(Category OperatingUnit FiscalYear)
g AnnualSectorShare = AnnualSectorSpent/AnnualSpent
sort FiscalYear

*label variables
la var TotalSpent "Total obligations for all FYs"
la var TotalSectorSpent "Total sectoral obligations for all FYs"
la var TotalSectorShare "Sectoral Share of total obligations for all FYs"
la var AnnualSpent "Total annual obligations by operating unit"
la var AnnualSectorSpent "Total sectoral annual obligations by operating unit"
la var AnnualSectorShare "Total sectoral annual obligations share by operating unit"

*preserve
collapse (mean) TotalSpent TotalSectorSpent TotalSectorShare AnnualSpent AnnualSectorSpent AnnualSectorShare, by(FiscalYear OperatingUnit Category)
encode OperatingUnit, gen(country)
egen cyid = group(OperatingUnit Category FiscalYear)
xtset cyid FiscalYear
*Generate percent change for each Category
encode Category, gen(sector)

set more off
g pctChange=.
g pctChange2=.
levelsof country, local(place)
levelsof sector, local(levels)
foreach x of local place {
	foreach y of local levels {
			replace pctChange=(AnnualSectorSpent[_n]-AnnualSectorSpent[_n-1])/AnnualSectorSpent[_n-1] if country[_n]==`x' & sector[_n]==`y' & sector[_n]==sector[_n-1]
			replace pctChange2=(AnnualSectorSpent[_n]-AnnualSectorSpent[_n-1])/AnnualSectorSpent[_n-1] if country[_n]==`x' & sector[_n]==`y' & sector[_n]==sector[_n-1] & AnnualSectorSpent[_n-1]>0
		}	
	}
*end

la var pctChange "Year-to-year percentage change in aid by sector"
la var pctChange2 "Year-to-year percentage change in aid by sector only for positive spending"

*Double-check that all shares sum to 1
egen shareValidate = total(AnnualSectorShare), by(OperatingUnit FiscalYear)

*At the Global scale what does the Breakdown look like by sector, by year?
egen WorldAnnualSpent = total(AnnualSpent), by(FiscalYear)
egen WorldAnnualSpentSector = total(AnnualSpent), by(Category FiscalYear)
g WorldAnnualSectorShare =WorldAnnualSpentSector/WorldAnnualSpent

la var WorldAnnualSpent "Total aggregate aid by FY"
la var WorldAnnualSpentSector "Total sectoral aggregate aid by FY"
la var WorldAnnualSectorShare "Total sectoral aggregate aid share by FY"
compress
drop shareValidate
g Aidtype = "Obligated"
la var Aidtype "Type of foreign assistance"
save "$pathout\AnnualObligated.dta", replace

** End data processing, now merge datasets
append using "$pathout\AnnualSpent.dta"

*Remove USAID offices
drop if regexm(OperatingUnit, "USAID")
drop if regexm(OperatingUnit, "Regional")

replace OperatingUnit = "West Bank-Gaza" if OperatingUnit=="West Bank and Gaza"
replace OperatingUnit = "Republic of the Congo" if OperatingUnit == "Republic of Congo"
replace OperatingUnit = "Kyrgystan" if OperatingUnit == "Kyrgyz Republic"
replace OperatingUnit = "Democratic Republic of the Congo" if OperatingUnit == "Democratic Republic of Congo"

g byte SudanTag = (OperatingUnit == "Sudan, Pre-2011 Election")
la var SudanTag "Tag for Pre-2011"
drop shareValidate
save "$pathout\AnnualSpentAndObligated.dta", replace
****

export excel "$pathxls/ForeignAssistanceDashboard.xls", firstrow(variables) replace

*Questions for Kim
* How do we resolve negative obligations and spending?
* How should we code Sudan, Pre-2011
* To make data easier to work w/, recommend adding in a column of ISO_Alpha 3 country codes
* OR standardizing the country names across databases.

*save merged data


