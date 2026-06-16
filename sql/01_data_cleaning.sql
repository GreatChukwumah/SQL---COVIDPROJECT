--DATA INSPECTING AND CLEANING

SELECT *
FROM CovidData
ORDER BY COUNTRY_NAME

--checking for dupulicate country names by difference in case that could lead to duplicate records
SELECT DISTINCT COUNTRY_NAME 
FROM CovidData
ORDER BY COUNTRY_NAME

-- fishing out countries wrong characters
SELECT DISTINCT COUNTRY_NAME
FROM CovidData
WHERE COUNTRY_NAME LIKE '%[^A-Za-z -]%';

-- correcting/updating them

UPDATE CovidData
SET COUNTRY_NAME = 'BOLIVIA'
WHERE COUNTRY_NAME = 'BOLIVIA (PLURINATIONAL STATE OF)';

UPDATE CovidData
SET COUNTRY_NAME = 'VENEZUELA'
WHERE COUNTRY_NAME = 'Venezuela (Bolivarian Republic of)';

UPDATE CovidData
SET COUNTRY_NAME = 'CORT DIVOIRE'
WHERE COUNTRY_NAME = 'C??te dƒ??Ivoire';

UPDATE CovidData
SET COUNTRY_NAME = 'CURACAO'
WHERE COUNTRY_NAME = 'Cura??ao';

-- standardizing the cases

UPDATE CovidData
SET COUNTRY_NAME = UPPER(COUNTRY_NAME);

--checking for null values in relevant colume, results show row by row

SELECT *,
(
    CASE WHEN WHO_REGION IS NULL THEN 1 ELSE 0 END +
    CASE WHEN COUNTRY_NAME IS NULL THEN 1 ELSE 0 END +
    CASE WHEN COUNTRY_CODE IS NULL THEN 1 ELSE 0 END +
    CASE WHEN SEX IS NULL THEN 1 ELSE 0 END +
    CASE WHEN AGEGROUP IS NULL THEN 1 ELSE 0 END +
    CASE WHEN DAILY_CASES IS NULL THEN 1 ELSE 0 END +
    CASE WHEN DETAILED_CASES IS NULL THEN 1 ELSE 0 END
) AS NullCount
FROM CovidData;


--Checking for incompatible values in agegrouop column, haow many times they occur

SELECT AGEGROUP , COUNT(AGEGROUP) AS FREQUENCY
FROM CovidData
Group by AGEGROUP
ORDER BY AGEGROUP;
--seeing the number of times 14-0ct or 9-May occurs 7478 and 42052 respectively, it cannot just be a typographical error, Excel must have corrupted it where 9-May actually means 5-9, ps: 5-9 is actually missing

--bringing out the excel corrupted agegroups
SELECT DISTINCT AGEGROUP
FROM CovidData
WHERE AGEGROUP LIKE '%[A-Za-z]%'
AND  AGEGROUP NOT LIKE 'ALL';

--discovered all agegroups have a unique agegroup number to them, including the ones messed up with months by excel
SELECT AGEGROUP , AGEGROUP_NUM , COUNT(AGEGROUP) AS FREQUENCY
FROM CovidData
Group by AGEGROUP, AGEGROUP_NUM
ORDER BY AGEGROUP;

--but since the wrong-frormatted agegroups aren't a lot we can just change them here
UPDATE CovidData
SET AGEGROUP =
CASE
    WHEN AGEGROUP = '9-May' THEN '5-9'
    WHEN AGEGROUP = '14-May' THEN '10-14'
    WHEN AGEGROUP = '14-Oct' THEN '10-14'
    WHEN AGEGROUP = '19-Oct' THEN '10-19'
    WHEN AGEGROUP = '4-Feb' THEN '2-4'
    
    ELSE AGEGROUP
END;
