# COVID-19 Global Surveillance — SQL & Power BI Portfolio Project
**Author:** Great Chukwumah

---

## Project Overview

This project demonstrates end-to-end Business Intelligence and data engineering skills using real-world epidemiological data from the World Health Organization (WHO). Starting from a raw CSV export, the project covers data cleaning, dimensional modelling, analytical SQL view development, and Power BI dashboard design — mirroring the full workflow of a professional BI/Data Analyst role.

---

## Data Source

**Dataset:** `A_COMBINED_WEEK_SEX_AGEGROUP_PUBLIC`  
**Provider:** World Health Organization (WHO)  
**URL:** https://data.who.int/dashboards/covid19/deaths  
**Grain:** Weekly COVID-19 case and death counts, disaggregated by country, ISO week, age group, and sex  
**Coverage:** Global — all WHO regions (AFR, AMR, EMR, EUR, SEAR, WPR)

---

## Skills Demonstrated

- **Data Cleaning & Profiling** — Identifying and correcting encoding errors, Excel date-corruption in categorical fields (e.g. `9-May` → `5-9`), and non-standard country name formats using SQL `UPDATE` and `CASE` statements
- **Dimensional Modelling** — Designing and implementing a Star Schema (fact + 4 dimension tables) in SQL Server, with surrogate keys and foreign key relationships, optimised for Power BI's VertiPaq engine
- **Advanced SQL** — 17 analytical views covering window functions (`LAG`, `RANK`, `SUM OVER`), CTEs, conditional aggregation, rolling averages, cumulative totals, year-over-year growth, and data quality auditing
- **Data Quality & Governance** — Multi-rule audit framework flagging logical inconsistencies (deaths exceeding cases, confirmed/probable mismatches, missing core fields), row-level completeness scoring, and a reporting gap analysis quantifying where country-level demographic breakdowns fail to reconcile with official topline totals
- **Power BI** — Dashboard development across 5 thematic pages, connecting directly to SQL Server views, with DAX measures for KPIs, rates, and rankings
- **Git / Version Control** — Project managed and published via GitHub

---

## Repository Structure

```
covid-bi-portfolio/
│
├── README.md                        ← You are here
│
├── sql/
│   ├── 01_data_cleaning.sql         ← Inspection, standardisation, and correction of raw data
│   ├── 02_star_schema.sql           ← Dimension and fact table creation + population
│   └── 03_analytical_views.sql      ← All 17 analytical views with inline documentation
│
└── powerbi/
    └── covid_dashboard.pbix         ← Power BI Desktop file (open with free Power BI Desktop)
```

---

## Star Schema Design

```
                    ┌─────────────┐
                    │  dim_date   │
                    │─────────────│
                    │ date_key PK │
                    │ ISO_START.. │
                    │ ISO_YEAR    │
                    │ ISO_WEEK    │
                    └──────┬──────┘
                           │
┌─────────────┐    ┌───────┴──────────┐    ┌─────────────┐
│ dim_country │    │ fact_covid_weekly │    │   dim_age   │
│─────────────│    │──────────────────│    │─────────────│
│country_key  ├────│ case_key    PK   ├────│ age_key  PK │
│COUNTRY_CODE │    │ country_key FK   │    │ AGEGROUP    │
│COUNTRY_NAME │    │ date_key    FK   │    │ AGEGROUP_NUM│
│WHO_REGION   │    │ age_key     FK   │    └─────────────┘
└─────────────┘    │ sex_key     FK   │
                   │ DAILY_CASES      │    ┌─────────────┐
                   │ DAILY_CASES_D..  │    │   dim_sex   │
                   │ DETAILED_CASES.. ├────│─────────────│
                   │ PERSONS_TESTED.. │    │ sex_key  PK │
                   └──────────────────┘    │ SEX         │
                                           └─────────────┘
```

---

## Analytical Views Summary

| View | Name | Key Concepts |
|------|------|-------------|
| 01 | Country Summary | Aggregation, Case Fatality Rate (CFR), FLOAT casting |
| 02 | Weekly Trend | Time-series grain, GROUP BY, aliasing |
| 03 | Rolling 4-Week Average | `AVG() OVER`, sliding window, `ROWS BETWEEN` |
| 04 | Week-over-Week Growth | `LAG()`, % change, NULL guarding |
| 05 | Peak Week per Country | `RANK() OVER`, subquery wrap-and-filter pattern |
| 06 | CFR by Age Group | Disaggregated rows, `AGEGROUP_NUM` sort order |
| 07 | Healthcare Worker Impact | Multiple ratios, NULL-to-zero handling |
| 08 | Hospitalization Rate by Age | Rate pattern, age-level disaggregation |
| 09 | Testing Positivity Rate | PCR testing metric, WHO surveillance standard |
| 10 | Regional Summary | Higher-grain rollup, `COUNT(DISTINCT)` |
| 11 | Sex-Based Comparison | Demographic disaggregation, filter symmetry |
| 12 | Top 10 Countries by Deaths | `TOP N`, `ORDER BY` aggregate |
| 13 | Data Quality Audit | Multi-rule flagging, `ISNULL`, completeness scoring |
| 14 | Year-over-Year Comparison | `LAG()` on aggregates, YoY growth rate |
| 15 | Cumulative Cases | `SUM() OVER`, `UNBOUNDED PRECEDING`, running total |
| 16 | Country Reporting Completeness | Conditional aggregation, OR disaggregation logic |
| 17 | Reporting Gap Analysis | CTEs, `LEFT JOIN`, topline vs breakdown reconciliation |

---

## Key Analytical Findings

- **Double-counting risk identified and resolved:** The dataset contains both topline (`SEX='All', AGEGROUP='All'`) summary rows AND disaggregated breakdown rows for the same country-week. All aggregate views apply consistent `WHERE` filters to prevent inflated totals.
- **Excel date-corruption caught in age group column:** Values like `9-May` and `14-Oct` were identified as Excel auto-formatting corrupting `5-9` and `10-14` age group labels. Corrected via `UPDATE ... CASE` statements before modelling.
- **Reporting gap quantified (View 17):** For many country-weeks, the sum of demographic breakdown rows does not equal the official topline total — reflecting different reporting pipelines per data source. This is flagged and measured as a `case_gap_pct` metric, providing a data reliability signal per country.
- **Completeness scoring framework (View 13 & 16):** Each row is scored on field-level completeness across 5 optional metrics, and each country is scored on the proportion of records providing demographic breakdowns — directly analogous to Profile Completeness Scoring in CRM data governance contexts.

---

## Power BI Dashboard Pages

| Page | Views Used | Purpose |
|------|-----------|---------|
| Executive Overview | #1, #10 | KPI cards, regional summary, top-line totals |
| Trends & Signals | #2, #3, #4, #5, #15 | Time-series, rolling averages, growth rates, peak detection |
| Demographics | #6, #8, #11 | Age/sex breakdowns for CFR, hospitalisation, case distribution |
| Reporting & Operations | #7, #9, #12 | Healthcare worker impact, positivity rate, country leaderboard |
| Data Quality & Governance | #13, #16, #17 | Completeness scores, audit flags, reporting gap analysis |

---

## How to Run This Project

### SQL (SQL Server)
1. Import `A_COMBINED_WEEK_SEX_AGEGROUP_PUBLIC.csv` into a table named `CovidData`
2. Run `01_data_cleaning.sql` to standardise and correct raw data
3. Run `02_star_schema.sql` to build dimension and fact tables
4. Run `03_analytical_views.sql` to create all 17 analytical views

### Power BI
1. Download and install [Power BI Desktop](https://powerbi.microsoft.com/desktop/) (free)
2. Open `covid_dashboard.pbix`
3. Update the SQL Server connection string to point to your local instance (Home → Transform Data → Data Source Settings)

---

## Contact

**Great Chukwumah**  
Available for Data Analyst / BI Analyst roles
