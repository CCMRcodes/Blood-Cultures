/* Project: Rishi CDA */

/* Pulling blood culture data for HAPPI Rishi CDA analytic cohort using two different CDW sources:
- Micro tables
- CPRS tables */

/* Author: Jennifer Cano */
/* Date Created: 2/28/23 */


use /*database name*/
go

--Created dflt copy of the HAPPI cohort in Blood Cultures_20230403.sas saved in 
--'path name'

/*How many unique hosps and pts in cohort? */
select count(distinct unique_hosp_count_id)
from dflt.happi_20132018_20230403_JC --1,100,996

select count(distinct patienticn)
from dflt.happi_20132018_20230403_JC --618,746

/*/*/*/*/*/* 1) Pull from Micro tables  */*/*/*/*/*/

--what are admit min and max dates?
select min(new_admitdate3), max(new_dischargedate3)
from dflt.happi_20132018_20230403_JC
--2013-01-02	2020-01-03


--see what the possible values of 'topography' are so that we can filter only by blood cultures
select distinct topography
from Cdwwork.Dim.Topography
order by Topography
--there are 17303 different values 

select distinct topography
from Cdwwork.Dim.Topography
--where topography like '%PLAS%'
where topography like '%BLD%' or topography  like '%BLOOD%'
--where topography like '%SERUM%'
order by Topography

--Per PI 2/28/23, we want to include BLOOD, PLASMA, and SERUM

/*Microbiology table*/

drop table if exists #BloodPositive_micro
SELECT DISTINCT 
	Coh.*, A.SpecimenTakenDateTime, CAST(A.SpecimenTakenDateTime AS DATE) AS SpecimenTakenDate,
	A.MicrobiologySID, A.TopographySID, B.Topography, A.CollectionSampleSID, C.CollectionSample, C.DefaultTopography, c.LabSection
INTO #BloodPositive_micro 
FROM dflt.happi_20132018_20230403_JC AS Coh
INNER JOIN Src.Micro_Microbiology AS A
	ON Coh.PatientSID = A.PatientSID
INNER JOIN Cdwwork.Dim.Topography AS B
	ON A.TopographySID = B.TopographySID
LEFT JOIN Cdwwork.Dim.CollectionSample C
	ON A.CollectionSampleSID=C.CollectionSampleSID
WHERE A.SpecimenTakenDateTime >= CONVERT(DATETIME2(0), coh.ed_arrival_date_dayprior) and 
	A.SpecimenTakenDateTime <= CONVERT(DATETIME2(0), coh.new_dischargedate3) and 
	(b.topography like '%PLAS%' or b.topography like '%BLD%' or b.topography  like '%BLOOD%' or b.topography like '%SERUM%')
--1,473,729 unique values

--how many unique hosps with blood culture?
select count(distinct unique_hosp_count_id)
from #BloodPositive_micro
where specimentakendate is not null -- 538,507 (1,100,996 total - 49%)

select count(distinct MicrobiologySID)
from #BloodPositive_micro --1472101

select distinct topography
from #BloodPositive_micro

/*MicroOrderedTest table*/
drop table if exists #BloodPositive_microorder
SELECT DISTINCT 
	Coh.*, A.SpecimenTakenDateTime, CAST(A.SpecimenTakenDateTime AS DATE) AS SpecimenTakenDate,
	A.MicrobiologySID, A.TopographySID, B.Topography, A.CollectionSampleSID, A.CPRSOrderSID, A.OrderedLabChemTestSID,
	C.CollectionSample, C.DefaultTopography, c.LabSection
INTO #BloodPositive_microorder
FROM dflt.happi_20132018_20230403_JC AS Coh
INNER JOIN Src.Micro_MicroOrderedTest AS A
	ON Coh.PatientSID = A.PatientSID
INNER JOIN Cdwwork.Dim.Topography AS B
	ON A.TopographySID = B.TopographySID
LEFT JOIN Cdwwork.Dim.CollectionSample C
	ON A.CollectionSampleSID=C.CollectionSampleSID
WHERE A.SpecimenTakenDateTime >= CONVERT(DATETIME2(0), coh.ed_arrival_date_dayprior) and 
	A.SpecimenTakenDateTime <= CONVERT(DATETIME2(0), coh.new_dischargedate3) and 
	(b.topography like '%PLAS%' or b.topography like '%BLD%' or b.topography  like '%BLOOD%' or b.topography like '%SERUM%')
--1438580 


--which sids are in both tables 
drop table if exists #msid
select distinct a.microbiologysid
into #msid
from #BloodPositive_micro a
inner join #BloodPositive_microorder b
on a.microbiologysid = b.microbiologysid --1412734 (96% of SIDs in Microbiology table)

--which are not in micrordered table
drop table if exists #msid_nomatch
select a.microbiologysid
into #msid_nomatch
from #BloodPositive_micro a
left join #BloodPositive_microorder b
on a.microbiologysid = b.microbiologysid
where b.microbiologysid is null --59383


/*/*/*/*/*/* 2) Pull from CPRS Table  */*/*/*/*/*/

--Pulled CPRS Orders in Micro.MicroOrderedTest above in table #BloodPositive_microorder

--how many have distinct CPRSOrderSID
select count(distinct CPRSOrderSID)
from #BloodPositive_microorder --1398011; 1438580 non unique (same as total rows of data set)

--Merge in the OrderableItemName to see what names appear
drop table if exists #CPRS_MicroOrderedTest
select distinct a.*, b.OrderableItemName, b.OrderableItemCode, b.OrderableItemSID,
	b.PackageName, d.OrderText
into #CPRS_MicroOrderedTest
from #BloodPositive_microorder a
left join Src.CPRSOrder_OrderedItem c
	on a.CPRSOrderSID = c.CPRSOrderSID
left join [CDWWork].[Dim].[OrderableItem] b
	on c.OrderableItemSID=b.OrderableItemSID
left join Src.CPRSOrder_OrderAction d
	on a.CPRSOrderSID = d.CPRSOrderSID --1440274

select top 100 * from #CPRS_MicroOrderedTest

select count(distinct CPRSOrderSID)
from #CPRS_MicroOrderedTest

select count(CPRSOrderSID)
from #CPRS_MicroOrderedTest--none missing

select distinct OrderableItemName from #CPRS_MicroOrderedTest order by OrderableItemName 
select distinct PackageName from #CPRS_MicroOrderedTest order by PackageName
select distinct topography from #CPRS_MicroOrderedTest order by topography

-- 3/21/23 sent PI list of topography values to make sure there aren't any we don't want to keep 

--PI wants to know how many pts had blood culture on day 1, 2, 3 and explore by facility. Will do this in SAS 
-- in Blood Cultures_20230403.sas saved in 
--'path name'

--save as dflt table
select * 
into dflt.HAPPI_BC_CPRS_Micro_JC_20230403
from #CPRS_MicroOrderedTest --1343381

--how many unique hosps with blood culture?
select count(distinct unique_hosp_count_id)
from dflt.HAPPI_BC_CPRS_Micro_JC_20230403
where specimentakendate is not null -- 519,688 (1,100,996 total - 47%)

select top 5 * from dflt.HAPPI_BC_CPRS_Micro_JC_20230403

--print topography alongside collectionsample to send to PI
select distinct collectionsample, topography
from dflt.HAPPI_BC_CPRS_Micro_JC_20230403
order by topography

--print values of orderableitemname to send to PI
select distinct OrderableItemName
from dflt.HAPPI_BC_CPRS_Micro_JC_20230403
order by OrderableItemName 







