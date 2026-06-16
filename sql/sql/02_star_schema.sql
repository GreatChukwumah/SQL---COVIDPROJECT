--CREATING A DATA WAREHOUSE(STAR SCHEMA)

--Dimensions#

--country
CREATE TABLE dim_country (
    country_key     INT IDENTITY(1,1) PRIMARY KEY,
    COUNTRY_CODE    NVARCHAR(10),
    COUNTRY_NAME    NVARCHAR(100),
    WHO_REGION      NVARCHAR(50)
);

INSERT INTO dim_country (COUNTRY_CODE, COUNTRY_NAME, WHO_REGION)
SELECT DISTINCT COUNTRY_CODE, COUNTRY_NAME, WHO_REGION
FROM CovidData
WHERE COUNTRY_CODE IS NOT NULL;

--date
CREATE TABLE dim_date (
    date_key        INT IDENTITY(1,1) PRIMARY KEY,
    ISO_START_DATE  DATE,
    ISO_YEAR        INT,
    ISO_WEEK        INT
);

INSERT INTO dim_date (ISO_START_DATE, ISO_YEAR, ISO_WEEK)
SELECT DISTINCT 
    CAST(ISO_START_DATE AS DATE),
    CAST(ISO_YEAR AS INT),
    CAST(ISO_WEEK AS INT)
FROM CovidData
WHERE ISO_START_DATE IS NOT NULL;

--age
CREATE TABLE dim_age (
    age_key         INT IDENTITY(1,1) PRIMARY KEY,
    AGEGROUP        NVARCHAR(20),
    AGEGROUP_NUM    INT
);

INSERT INTO dim_age (AGEGROUP, AGEGROUP_NUM)
SELECT DISTINCT AGEGROUP, CAST(AGEGROUP_NUM AS INT)
FROM CovidData
WHERE AGEGROUP IS NOT NULL;

--sex
CREATE TABLE dim_sex (
    sex_key         INT IDENTITY(1,1) PRIMARY KEY,
    SEX             NVARCHAR(20)
);

INSERT INTO dim_sex (SEX)
SELECT DISTINCT SEX
FROM CovidData
WHERE SEX IS NOT NULL;

--Measures##
--Fact Table

CREATE TABLE fact_covid_weekly (
    case_key                        INT IDENTITY(1,1) PRIMARY KEY,
    country_key                     INT FOREIGN KEY REFERENCES dim_country(country_key),
    date_key                        INT FOREIGN KEY REFERENCES dim_date(date_key),
    age_key                         INT FOREIGN KEY REFERENCES dim_age(age_key),
    sex_key                         INT FOREIGN KEY REFERENCES dim_sex(sex_key),
    DAILY_CASES                     INT,
    DAILY_CASES_DEATHS              INT,
    DETAILED_CASES                  INT,
    DETAILED_CASES_DEATHS           INT,
    DETAILED_CASES_CONFIRMED        INT,
    DETAILED_CASES_DEATHS_CONFIRMED INT,
    DETAILED_CASES_PROBABLE         INT,
    DETAILED_CASES_DEATHS_PROBABLE  INT,
    DETAILED_CASES_HOSPITALISED     INT,
    DETAILED_CASES_HW               INT,
    DETAILED_CASES_DEATHS_HW        INT,
    DETAILED_CASES_DISCHARGED       INT,
    PERSONS_TESTED                  INT,
    PERSONS_TESTED_PCR              INT
);



INSERT INTO fact_covid_weekly (
    country_key, date_key, age_key, sex_key,
    DAILY_CASES, DAILY_CASES_DEATHS,
    DETAILED_CASES, DETAILED_CASES_DEATHS,
    DETAILED_CASES_CONFIRMED, DETAILED_CASES_DEATHS_CONFIRMED,
    DETAILED_CASES_PROBABLE, DETAILED_CASES_DEATHS_PROBABLE,
    DETAILED_CASES_HOSPITALISED, DETAILED_CASES_HW,
    DETAILED_CASES_DEATHS_HW, DETAILED_CASES_DISCHARGED,
    PERSONS_TESTED, PERSONS_TESTED_PCR
)
SELECT
    dc.country_key,
    dd.date_key,
    da.age_key,
    ds.sex_key,
    TRY_CAST(c.DAILY_CASES                     AS INT),
    TRY_CAST(c.DAILY_CASES_DEATHS              AS INT),
    TRY_CAST(c.DETAILED_CASES                  AS INT),
    TRY_CAST(c.DETAILED_CASES_DEATHS           AS INT),
    TRY_CAST(c.DETAILED_CASES_CONFIRMED        AS INT),
    TRY_CAST(c.DETAILED_CASES_DEATHS_CONFIRMED AS INT),
    TRY_CAST(c.DETAILED_CASES_PROBABLE         AS INT),
    TRY_CAST(c.DETAILED_CASES_DEATHS_PROBABLE  AS INT),
    TRY_CAST(c.DETAILED_CASES_HOSPITALISED     AS INT),
    TRY_CAST(c.DETAILED_CASES_HW               AS INT),
    TRY_CAST(c.DETAILED_CASES_DEATHS_HW        AS INT),
    TRY_CAST(c.DETAILED_CASES_DISCHARGED       AS INT),
    TRY_CAST(c.PERSONS_TESTED                  AS INT),
    TRY_CAST(c.PERSONS_TESTED_PCR              AS INT)
FROM CovidData c
JOIN dim_country dc ON c.COUNTRY_CODE = dc.COUNTRY_CODE
JOIN dim_date    dd ON CAST(c.ISO_START_DATE AS DATE) = dd.ISO_START_DATE
JOIN dim_age     da ON c.AGEGROUP = da.AGEGROUP
JOIN dim_sex     ds ON c.SEX = ds.SEX;


SELECT COUNT(*) FROM fact_covid_weekly;
SELECT COUNT(*) FROM CovidData;

SELECT COUNT(*)
FROM fact_covid_weekly f
LEFT JOIN dim_country dc 
ON f.country_key = dc.country_key
WHERE dc.country_key IS NULL 

--By my observation of the data, I discovered that many times, male + female doesn't always equal 'All' and 70-74 + 75-79 doesn't always 70-79 in value.
--So my queries would be working around these to see if I can get tangible insight
