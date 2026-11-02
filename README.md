# Global Geographic Analysis

![Power BI](https://img.shields.io/badge/Power%20BI-Dashboards-F2C811?logo=powerbi&logoColor=black)
![Power Query](https://img.shields.io/badge/Power%20Query-Data%20Cleaning-0F766E)
![Countries](https://img.shields.io/badge/Coverage-195%2B%20countries-2563EB)

Three interactive Power BI dashboards that compare 195+ countries on population, education and economy, built from a cleaned and validated dataset.

![Home page](images/home-page.png)

---

## Business Question

Governments, NGOs and analysts compare countries constantly, but the data sits in separate tables and is rarely clean. This project puts it in one place and answers three questions:

| Dashboard | Question |
|---|---|
| Global Population & Demographics | Where do people live, how will populations change, and how does life expectancy relate to age? |
| Education & Literacy | How literate is each country, how much does it invest in education, and where are the gaps by gender? |
| Employment & Economy | How do unemployment, inflation and income compare across countries and continents? |

---

## Dashboards

### Global Population & Demographics
![Population dashboard](images/population-dashboard.png)

- Total population: **8 bn**; average life expectancy: **74.24 years**
- Population by country with the 2050 projection (India and China lead, followed by the United States, Indonesia and Pakistan)
- Life expectancy against median age by country

### Education & Literacy
![Education dashboard](images/education-dashboard.png)

- Average literacy rate: **87.38%**; average education spending: **4.36% of GDP**
- Literacy map, top countries by education investment, and illiteracy rate by gender (highest in Chad, Afghanistan, Mali and the Central African Republic)

### Employment & Economy
![Economy dashboard](images/economy-dashboard.png)

- Average unemployment rate: **6.93%**
- Country table sorted by unemployment, with GDP per adult and literacy rate side by side (the top of the table includes Eswatini, South Africa and Palestine)
- Net worth map and inflation rate by country

Every dashboard has a continent and country slicer, and a navigation bar that links back to the home page.

---

## Data

- **Source:** [World Population Review](https://worldpopulationreview.com/)
- **Coverage:** 195+ countries, 10+ indicators (population and projections, life expectancy, median age, literacy by gender, education spending, GDP per adult, unemployment, inflation, net worth)
- **Collected:** <!-- VERIFY: README had two different dates (17/10/2025 collected, 2020-2022 "data current as of"). Keep the right one. -->

### Cleaning (Power Query)

<!-- VERIFY: keep only the steps you actually did. Delete the rest. -->
- Standardized country names so tables join correctly
- Handled missing values and documented the gaps
- Validated ranges (for example, literacy between 0 and 100%)
- Aggregated by continent for the slicers

---

## Tools

Power BI (DAX measures, slicers, bookmarks and page navigation) · Power Query · CSV

---

## Limitations

- A static snapshot, not a live feed
- Indicators come from different years depending on the country, so small gaps are expected
- The dashboards show relationships between indicators, not causes

---

## Repository Structure

```text
global-geographic-analysis/
├── images/            # dashboard screenshots
├── LICENSE
└── README.md
```
<!-- ADD: the .pbix file and the cleaned dataset if you can share them, then list them here. -->

---

## Author

**Abdallah Tarek**, Data Analyst
[LinkedIn](https://www.linkedin.com/in/abdallaatarekk) · [Portfolio](https://abdallahportfolio-phi-ten.vercel.app) · abdallahtarek.work@gmail.com
