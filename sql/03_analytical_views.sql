/* COVID-19 SQL PROJECT
   Analytical Views for Power BI Integration
   Base object: vw_covid_analysis (or fact_covid_weekly joined to dims) */
 
 
/* 1. GLOBAL SUMMARY BY COUNTRY
Foundation view: total cases, deaths, and Case Fatality Rate (CFR)
per country. CFR = deaths / cases, expressed as a percentage. */
 
----CREATE VIEW vw_01_country_summary AS
--SELECT
--    WHO_REGION,
--    COUNTRY_NAME,
--   COUNTRY_CODE,
--    SUM(f.DAILY_CASES)        AS total_cases,
--    SUM(f.DAILY_CASES_DEATHS) AS total_deaths,
--    CASE 
--        WHEN SUM(DAILY_CASES) = 0 THEN NULL
--        ELSE ROUND(CAST(SUM(DAILY_CASES_DEATHS) AS FLOAT) 
--                   / SUM(DAILY_CASES) * 100, 2)
--    END AS case_fatality_rate_pct
--FROM  fact_covid_weekly f
--JOIN dim_country dc ON f.country_key = dc.country_key
--JOIN dim_age da ON f.age_key = da.age_key
--JOIN dim_sex ds ON f.sex_key = ds.sex_key 
--WHERE SEX = 'All' AND AGEGROUP = 'All'
--GROUP BY WHO_REGION, COUNTRY_NAME, COUNTRY_CODE
--ORDER BY case_fatality_rate_pct DESC;
-- I'm using SEX = 'All' AND AGEGROUP = 'All' to avoid double-counting.
-- The dataset stores both a single "All/All" summary row AND
-- disaggregated rows (by age/sex) for the same country/week.
-- Summing everything would count each case multiple times.

 
--It will be more effitient to create a view so we dont have to do so many joins. And thats where our base object comes in:

CREATE VIEW vw_covid_analysis AS
SELECT
    dc.WHO_REGION,
    dc.COUNTRY_NAME,
    dc.COUNTRY_CODE,
    dd.ISO_START_DATE,
    dd.ISO_YEAR,
    dd.ISO_WEEK,
    da.AGEGROUP,
    da.AGEGROUP_NUM,
    ds.SEX,
    f.DAILY_CASES,
    f.DAILY_CASES_DEATHS,
    f.DETAILED_CASES,
    f.DETAILED_CASES_DEATHS,
    f.DETAILED_CASES_CONFIRMED,
    f.DETAILED_CASES_DEATHS_CONFIRMED,
    f.DETAILED_CASES_PROBABLE,
    f.DETAILED_CASES_DEATHS_PROBABLE,
    f.DETAILED_CASES_HOSPITALISED,
    f.DETAILED_CASES_HW,
    f.DETAILED_CASES_DEATHS_HW,
    f.DETAILED_CASES_DISCHARGED,
    f.PERSONS_TESTED,
    f.PERSONS_TESTED_PCR
FROM fact_covid_weekly f
JOIN dim_country dc ON f.country_key = dc.country_key
JOIN dim_date    dd ON f.date_key    = dd.date_key
JOIN dim_age     da ON f.age_key     = da.age_key
JOIN dim_sex     ds ON f.sex_key     = ds.sex_key;

--now we can create it more efficiently

CREATE VIEW vw_01_country_summary AS
SELECT
    WHO_REGION,
    COUNTRY_NAME,
    COUNTRY_CODE,
    SUM(DAILY_CASES) AS total_cases,
    SUM(DAILY_CASES_DEATHS) AS total_deaths,
    CASE
        WHEN SUM(DAILY_CASES) = 0 THEN NULL
        ELSE ROUND(
            CAST(SUM(DAILY_CASES_DEATHS) AS FLOAT)
            / SUM(DAILY_CASES) * 100,
            2
        )
    END AS case_fatality_rate_pct
FROM vw_covid_analysis
GROUP BY
    WHO_REGION,
    COUNTRY_NAME,
    COUNTRY_CODE;

--2. WEEKLY TREND PER COUNTRY

CREATE VIEW vw_02_weekly_trend AS
SELECT
    COUNTRY_NAME,
    WHO_REGION,
    ISO_YEAR,
    ISO_WEEK,
    ISO_START_DATE,
    SUM(DAILY_CASES)        AS weekly_cases,
    SUM(DAILY_CASES_DEATHS) AS weekly_deaths
FROM vw_covid_analysis
WHERE SEX = 'All' AND AGEGROUP = 'All'
GROUP BY COUNTRY_NAME, WHO_REGION, DAILY_CASES, ISO_YEAR, ISO_WEEK, ISO_START_DATE

/*
- This is the grain (level of detail) most other time-based queries wil build on: one row per country per week.
- In Power BI, ISO_START_DATE becomes the X-axis of your line charts
*/

--3. ROLLING 4-WEEK AVERAGE OF CASES
CREATE VIEW vw_rolling_4w_average_cases AS
SELECT
    COUNTRY_NAME,
    WHO_REGION,
    ISO_YEAR,
    ISO_WEEK,
    weekly_cases,
    ROUND(
        AVG(weekly_cases) OVER (
            PARTITION BY COUNTRY_NAME 
            ORDER BY ISO_START_DATE
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 1
    ) AS rolling_4wk_avg_cases
FROM vw_02_weekly_trend;

--4. WEEK-OVER-WEEK GROWTH RATE
--   % change in weekly cases vs the previous week — flags accelerating or decelerating trends.

CREATE VIEW vw_04_wow_growth AS
SELECT
    COUNTRY_NAME,
    ISO_YEAR,
    ISO_WEEK,
    ISO_START_DATE,
    weekly_cases,
    LAG(weekly_cases) OVER (
        PARTITION BY COUNTRY_NAME ORDER BY ISO_START_DATE
    ) AS prior_week_cases,
    CASE 
        WHEN LAG(weekly_cases) OVER (
                 PARTITION BY COUNTRY_NAME ORDER BY ISO_START_DATE
             ) IS NULL 
             OR LAG(weekly_cases) OVER (
                 PARTITION BY COUNTRY_NAME ORDER BY ISO_START_DATE
             ) = 0 
        THEN NULL
        ELSE ROUND(
            (CAST(weekly_cases AS FLOAT) 
             - LAG(weekly_cases) OVER (
                   PARTITION BY COUNTRY_NAME ORDER BY ISO_START_DATE
               )) 
            / LAG(weekly_cases) OVER (
                  PARTITION BY COUNTRY_NAME ORDER BY ISO_START_DATE
              ) * 100, 1)
    END AS wow_growth_pct
FROM vw_02_weekly_trend;

--  5. PEAK WEEK PER COUNTRY

SELECT *
FROM (
    SELECT
        COUNTRY_NAME,
        ISO_YEAR,
        ISO_WEEK,
        ISO_START_DATE,
        weekly_cases,
        weekly_deaths,
        RANK() OVER (
            PARTITION BY COUNTRY_NAME ORDER BY weekly_cases DESC
        ) AS case_rank
    FROM vw_02_weekly_trend
) ranked
WHERE case_rank = 1;


-- 6. CASE FATALITY RATE (CFR) BY AGE GROUP

CREATE VIEW vw_06_cfr_by_age AS
SELECT
    AGEGROUP,
    AGEGROUP_NUM,
    SUM(DETAILED_CASES_CONFIRMED)        AS total_confirmed_cases,
    SUM(DETAILED_CASES_DEATHS_CONFIRMED) AS total_confirmed_deaths,
    CASE 
        WHEN SUM(DETAILED_CASES_CONFIRMED) = 0 THEN NULL
        ELSE ROUND(
            CAST(SUM(DETAILED_CASES_DEATHS_CONFIRMED) AS FLOAT) 
            / SUM(DETAILED_CASES_CONFIRMED) * 100, 2)
    END AS cfr_pct
FROM vw_covid_analysis
WHERE AGEGROUP <> 'All' AND SEX = 'All'
GROUP BY AGEGROUP, AGEGROUP_NUM
--ORDER BY cfr_pct DESC;  ...CANT CREATE A VIEW HAVING ORDER BY IN IT BUT THAT SHOULD SHOW YOU THE AGE GROUP THAT DIED MOST FROM COVID

  --7. HEALTHCARE WORKER (HW) IMPACT
  /*What % of all cases/deaths were among healthcare workers —
   an important equity/occupational-risk metric.*/

CREATE VIEW vw_07_hw_impact AS
SELECT
    COUNTRY_NAME,
    WHO_REGION,
    SUM(DETAILED_CASES_CONFIRMED)        AS total_cases,
    SUM(DETAILED_CASES_HW)               AS hw_cases,
    SUM(DETAILED_CASES_DEATHS_CONFIRMED) AS total_deaths,
    SUM(DETAILED_CASES_DEATHS_HW)        AS hw_deaths,
    CASE 
        WHEN SUM(DETAILED_CASES_CONFIRMED) = 0 THEN NULL
        ELSE ROUND(CAST(SUM(DETAILED_CASES_HW) AS FLOAT) 
                   / SUM(DETAILED_CASES_CONFIRMED) * 100, 2)
    END AS hw_share_of_cases_pct,
    CASE 
        WHEN SUM(DETAILED_CASES_DEATHS_CONFIRMED) = 0 THEN NULL
        ELSE ROUND(CAST(SUM(DETAILED_CASES_DEATHS_HW) AS FLOAT) 
                   / SUM(DETAILED_CASES_DEATHS_CONFIRMED) * 100, 2)
    END AS hw_share_of_deaths_pct
FROM vw_covid_analysis
WHERE SEX = 'All' AND AGEGROUP = 'All'
GROUP BY COUNTRY_NAME, WHO_REGION

--SELECT COUNTRY_NAME, DETAILED_CASES_CONFIRMED, DETAILED_CASES_DEATHS, DETAILED_CASES_HOSPITALISED, DETAILED_CASES_DISCHARGED
--FROM vw_covid_analysis
--WHERE DETAILED_CASES_HOSPITALISED <> 0

--  8. HOSPITALIZATION RATE BY AGE GROUP

CREATE VIEW vw_08_hospitalization_by_age AS
SELECT
    AGEGROUP,
    AGEGROUP_NUM,
    SUM(DETAILED_CASES_CONFIRMED)     AS total_confirmed_cases,
    SUM(DETAILED_CASES_HOSPITALISED)  AS total_hospitalised,
    CASE 
        WHEN SUM(DETAILED_CASES_CONFIRMED) = 0 THEN NULL
        ELSE ROUND(CAST(SUM(DETAILED_CASES_HOSPITALISED) AS FLOAT) 
                   / SUM(DETAILED_CASES_CONFIRMED) * 100, 2)
    END AS hospitalization_rate_pct
FROM vw_covid_analysis
WHERE AGEGROUP <> 'All' AND SEX = 'All'
GROUP BY AGEGROUP, AGEGROUP_NUM;



--9. TESTING POSITIVITY RATE
  
CREATE VIEW vw_09_positivity_rate AS
SELECT
    COUNTRY_NAME,
    WHO_REGION,
    ISO_YEAR,
    ISO_WEEK,
    ISO_START_DATE,
    SUM(DETAILED_CASES_CONFIRMED) AS confirmed_cases,
    SUM(PERSONS_TESTED_PCR)       AS pcr_tests,
    CASE 
        WHEN SUM(PERSONS_TESTED_PCR) = 0 THEN NULL
        ELSE ROUND(CAST(SUM(DETAILED_CASES_CONFIRMED) AS FLOAT) 
                   / SUM(PERSONS_TESTED_PCR) * 100, 2)
    END AS positivity_rate_pct
FROM vw_covid_analysis
WHERE SEX = 'All' AND AGEGROUP = 'All'
GROUP BY COUNTRY_NAME, WHO_REGION, ISO_YEAR, ISO_WEEK, ISO_START_DATE;

--10. REGIONAL COMPARISON (WHO_REGION LEVEL)

CREATE VIEW vw_10_regional_summary AS
SELECT
    WHO_REGION,
    COUNT(DISTINCT COUNTRY_NAME) AS countries_reporting,
    SUM(DAILY_CASES)             AS total_cases,
    SUM(DAILY_CASES_DEATHS)      AS total_deaths,
    CASE 
        WHEN SUM(DAILY_CASES) = 0 THEN NULL
        ELSE ROUND(CAST(SUM(DAILY_CASES_DEATHS) AS FLOAT) 
                   / SUM(DAILY_CASES) * 100, 2)
    END AS cfr_pct
FROM vw_covid_analysis
WHERE SEX = 'All' AND AGEGROUP = 'All'
GROUP BY WHO_REGION;

--  11. SEX-BASED COMPARISON

CREATE VIEW vw_11_sex_comparison AS
SELECT
    SEX,
    SUM(DETAILED_CASES_CONFIRMED)        AS total_cases,
    SUM(DETAILED_CASES_DEATHS_CONFIRMED) AS total_deaths,
    CASE 
        WHEN SUM(DETAILED_CASES_CONFIRMED) = 0 THEN NULL
        ELSE ROUND(CAST(SUM(DETAILED_CASES_DEATHS_CONFIRMED) AS FLOAT) 
                   / SUM(DETAILED_CASES_CONFIRMED) * 100, 2)
    END AS cfr_pct
FROM vw_covid_analysis
WHERE SEX <> 'All' AND AGEGROUP = 'All'
GROUP BY SEX;

--   12. TOP 10 COUNTRIES BY TOTAL DEATHS

CREATE VIEW vw_12_top10_deaths AS
SELECT TOP 10 COUNTRY_NAME, WHO_REGION, SUM(DAILY_CASES_DEATHS) total_deaths
FROM vw_covid_analysis
WHERE SEX = 'All' AND AGEGROUP = 'All'
GROUP BY COUNTRY_NAME, WHO_REGION
ORDER BY total_deaths DESC

--13.  DATA QUALITY AUDIT
/* This will Flag rows with logical inconsistencies — deaths exceeding
   cases, mismatched confirmed+probable totals, and missing core
   fields. Mirrors "Profile Completeness Scoring" concepts. */
CREATE VIEW vw_13_data_quality_audit AS
SELECT
    COUNTRY_NAME,
    ISO_YEAR,
    ISO_WEEK,
    SEX,
    AGEGROUP,
    DAILY_CASES,
    DAILY_CASES_DEATHS,
    DETAILED_CASES_CONFIRMED,
    DETAILED_CASES_PROBABLE,
    DETAILED_CASES,
 
    -- FLAG 1: deaths exceed cases — logically impossible
    CASE 
        WHEN DAILY_CASES_DEATHS > DAILY_CASES THEN 1 ELSE 0 
    END AS flag_deaths_exceed_cases,
 
    -- FLAG 2: confirmed + probable should roughly equal the
    -- detailed total — large mismatches suggest reporting issues
    CASE 
        WHEN DETAILED_CASES IS NOT NULL 
             AND (ISNULL(DETAILED_CASES_CONFIRMED,0) 
                  + ISNULL(DETAILED_CASES_PROBABLE,0)) 
                 <> DETAILED_CASES 
        THEN 1 ELSE 0 
    END AS flag_confirmed_probable_mismatch,
 
    -- FLAG 3: core identifying fields missing
    CASE 
        WHEN COUNTRY_CODE IS NULL 
             OR ISO_START_DATE IS NULL 
             OR SEX IS NULL 
             OR AGEGROUP IS NULL 
        THEN 1 ELSE 0 
    END AS flag_missing_core_fields,
 
    -- COMPLETENESS SCORE: % of "expected" optional metrics that
    -- are actually populated for this row (out of 5 key fields)
    ROUND(
        (
            CASE WHEN DETAILED_CASES_HOSPITALISED IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN DETAILED_CASES_HW           IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN PERSONS_TESTED_PCR           IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN DETAILED_CASES_DISCHARGED    IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN DETAILED_CASES_DEATHS_HW     IS NOT NULL THEN 1 ELSE 0 END
        ) * 100.0 / 5, 1
    ) AS row_completeness_score_pct
 
FROM vw_covid_analysis;


--14. YEAR-OVER-YEAR COMPARISON

CREATE VIEW vw_14_yoy_comparison AS
SELECT
    COUNTRY_NAME,
    WHO_REGION,
    ISO_YEAR,
    SUM(DAILY_CASES)        AS total_cases,
    SUM(DAILY_CASES_DEATHS) AS total_deaths,
    LAG(SUM(DAILY_CASES)) OVER (
        PARTITION BY COUNTRY_NAME ORDER BY ISO_YEAR
    ) AS prior_year_cases,
    CASE 
        WHEN LAG(SUM(DAILY_CASES)) OVER (
                 PARTITION BY COUNTRY_NAME ORDER BY ISO_YEAR
             ) IS NULL 
             OR LAG(SUM(DAILY_CASES)) OVER (
                 PARTITION BY COUNTRY_NAME ORDER BY ISO_YEAR
             ) = 0
        THEN NULL
        ELSE ROUND(
            (CAST(SUM(DAILY_CASES) AS FLOAT) 
             - LAG(SUM(DAILY_CASES)) OVER (
                   PARTITION BY COUNTRY_NAME ORDER BY ISO_YEAR
               ))
            / LAG(SUM(DAILY_CASES)) OVER (
                  PARTITION BY COUNTRY_NAME ORDER BY ISO_YEAR
              ) * 100, 1)
    END AS yoy_growth_pct
FROM vw_covid_analysis
WHERE SEX = 'All' AND AGEGROUP = 'All'
GROUP BY COUNTRY_NAME, WHO_REGION, ISO_YEAR;

--   15. CUMULATIVE CASES OVER TIME

CREATE VIEW vw_15_cumulative_cases AS
SELECT
    COUNTRY_NAME,
    ISO_YEAR,
    ISO_WEEK,
    ISO_START_DATE,
    weekly_cases,
    weekly_deaths,
    SUM(weekly_cases) OVER (
        PARTITION BY COUNTRY_NAME 
        ORDER BY ISO_START_DATE
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_cases,
    SUM(weekly_deaths) OVER (
        PARTITION BY COUNTRY_NAME 
        ORDER BY ISO_START_DATE
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_deaths
FROM vw_02_weekly_trend;


--16. DISAGREGATE DATA (AGE x SEX COMPLETENESS / COVERAGE BY COUNTRY)

CREATE VIEW vw_16_country_reporting_completeness AS
SELECT
    COUNTRY_NAME,
    WHO_REGION,
    COUNT(*) AS total_rows,
    SUM(
        CASE WHEN AGEGROUP <> 'All' OR SEX <> 'All' THEN 1 ELSE 0 END
    ) AS rows_with_some_breakdown,
    ROUND(
        SUM(
            CASE WHEN AGEGROUP <> 'All' OR SEX <> 'All' THEN 1 ELSE 0 END
        ) * 100.0 / COUNT(*), 1
    ) AS pct_with_some_breakdown
FROM vw_covid_analysis
GROUP BY COUNTRY_NAME, WHO_REGION
ORDER BY pct_with_some_breakdown DESC;


--17. REPORTING GAP: ALL vs SUM OF DISAGGREGATED ROWS

CREATE VIEW vw_17_reporting_gap AS

WITH topline AS (
    -- The official "All/All" total per country-week
    SELECT
        COUNTRY_NAME,
        WHO_REGION,
        ISO_YEAR,
        ISO_WEEK,
        ISO_START_DATE,
        SUM(DAILY_CASES)        AS topline_cases,
        SUM(DAILY_CASES_DEATHS) AS topline_deaths
    FROM vw_covid_analysis
    WHERE SEX = 'All' AND AGEGROUP = 'All'
    GROUP BY COUNTRY_NAME, WHO_REGION, ISO_YEAR, ISO_WEEK, ISO_START_DATE
),

disaggregated AS (
    -- Sum of all age-group breakdown rows (using SEX='All' to avoid
    -- double-counting age x sex combinations — same logic as view #6)
    SELECT
        COUNTRY_NAME,
        ISO_YEAR,
        ISO_WEEK,
        ISO_START_DATE,
        SUM(DAILY_CASES)        AS disagg_cases,
        SUM(DAILY_CASES_DEATHS) AS disagg_deaths
    FROM vw_covid_analysis
    WHERE SEX = 'All' AND AGEGROUP <> 'All'
    GROUP BY COUNTRY_NAME, ISO_YEAR, ISO_WEEK, ISO_START_DATE
)

SELECT
    t.COUNTRY_NAME,
    t.WHO_REGION,
    t.ISO_YEAR,
    t.ISO_WEEK,
    t.ISO_START_DATE,
    t.topline_cases,
    ISNULL(d.disagg_cases, 0)  AS disaggregated_cases,
    t.topline_cases - ISNULL(d.disagg_cases, 0) AS case_reporting_gap,
    t.topline_deaths,
    ISNULL(d.disagg_deaths, 0) AS disaggregated_deaths,
    t.topline_deaths - ISNULL(d.disagg_deaths, 0) AS death_reporting_gap,
    CASE 
        WHEN t.topline_cases = 0 THEN NULL
        ELSE ROUND(
            (t.topline_cases - ISNULL(d.disagg_cases, 0)) * 100.0 
            / t.topline_cases, 1)
    END AS case_gap_pct
FROM topline t
LEFT JOIN disaggregated d
    ON t.COUNTRY_NAME = d.COUNTRY_NAME
    AND t.ISO_YEAR = d.ISO_YEAR
    AND t.ISO_WEEK = d.ISO_WEEK
    AND t.ISO_START_DATE = d.ISO_START_DATE;
