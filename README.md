# Replication Package — Wikipedia Pageviews and Cultural Site Attendance

> **Does online attention translate into real-world visits?**  
> This repository contains the full replication package for a study estimating
> the causal effect of French Wikipedia pageviews on daily attendance at six
> cultural sites in Orléans, France (July 2021 – November 2024).

---

## Key Results

The main specification is a distributed two-way fixed-effects (TWFE)
timing model with Driscoll-Kraay (bandwidth = 30 days) standard errors.

| Wikipedia signal | Coefficient | SE | Significance |
|---|---|---|---|
| log(1 + mobile pageviews) | 0.516 | 0.057 | *** |
| log(1 + mobile) + log(1 + desktop) | 0.499 / 0.143 | 0.054 / 0.040 | *** / *** |

Sample: **7,422 site-day observations**, 6 venues, 1,237 calendar dates.  
Zero-attendance share: 15.1 %. Mean daily attendance: 133.5 visitors.

---

## Repository Structure

```text
replication-matter/
├── analysis/
│   ├── attendance_wikipedia_twfe.Rmd   # full TWFE report (exploratory)
│   ├── loglog_clean_report.Rmd         # clean log-log report
│   ├── run_loglog_only_analysis.R      # main estimation entry-point
│   ├── export_loglog_figures.R         # export publication figures
│   └── compile_clean_report.R          # knit HTML report
├── data/
│   ├── raw/
│   │   └── frequentation-par-heure.csv # raw hourly attendance (source data)
│   ├── references/
│   │   └── wikipedia_pages.md          # Wikipedia URLs for each venue
│   └── derived/                        # built by Python pipeline
│       ├── daily_place_attendance_*.xlsx
│       ├── wikipedia_pageviews_fr_*.xlsx
│       └── merged_attendance_wikipedia_fr_*.xlsx
├── outputs/
│   ├── figures/                        # publication-quality PNG/PDF figures
│   ├── results/
│   │   └── loglog_analysis_results.json
│   └── paper/
│       └── methods_and_results_paper.md
├── scripts/
│   ├── build_daily_place_attendance.py # step 1 – aggregate hourly → daily
│   ├── fetch_wikipedia_pageviews_fr.py # step 2 – fetch Wikipedia API data
│   └── merge_attendance_and_wikipedia.py # step 3 – merge both datasets
├── requirements.txt
└── README.md
```

---

## Setup

### Python dependencies

```bash
pip install -r requirements.txt
```

Requires Python ≥ 3.9. Key packages: `pandas`, `requests`, `openpyxl`.

### R dependencies

Install the following R packages once:

```r
install.packages(c("readxl", "dplyr", "tidyr", "fixest",
                   "jsonlite", "ggplot2", "knitr", "rmarkdown"))
```

---

## Reproduction

### Step 1 — Build the data

Run the Python pipeline from the project root. Each script writes its output
to `data/derived/`.

```bash
python scripts/build_daily_place_attendance.py
python scripts/fetch_wikipedia_pageviews_fr.py
python scripts/merge_attendance_and_wikipedia.py
```

> **Note:** `fetch_wikipedia_pageviews_fr.py` queries the Wikimedia REST API
> (no authentication required). An internet connection is needed.

The raw source file must be placed at:

```
data/raw/frequentation-par-heure.csv
```

### Step 2 — Run the main estimation

```bash
Rscript analysis/run_loglog_only_analysis.R
```

Writes `outputs/results/loglog_analysis_results.json`.

### Step 3 — Export figures

```bash
Rscript analysis/export_loglog_figures.R
```

Writes PNG and PDF files to `outputs/figures/`.

### Step 4 — Compile the HTML report

```bash
Rscript analysis/compile_clean_report.R
```

Writes `outputs/html/loglog_clean_report.html`.

---

## Empirical Specification

### Baseline TWFE

$$y_{it} = \beta\, x_{it} + \rho\, y_{i,t-1} + \alpha_i + \delta_t + \eta_{i,\text{ym}(t)} + \lambda_{i,\text{dow}(t)} + \varepsilon_{it}$$

### Distributed Timing

$$y_{it} = \sum_{k=-30}^{30} \beta_k\, x_{i,t+k} + \rho\, y_{i,t-1} + \alpha_i + \delta_t + \eta_{i,\text{ym}(t)} + \lambda_{i,\text{dow}(t)} + \varepsilon_{it}$$

| Symbol | Definition |
|---|---|
| $y_{it}$ | $\log(1 + \text{Attendance}_{it})$ |
| $x_{it}$ | $\log(1 + \text{Mobile pageviews}_{it})$ |
| $\alpha_i$ | Venue fixed effects |
| $\delta_t$ | Exact-date fixed effects |
| $\eta_{i,\text{ym}(t)}$ | Venue × year-month fixed effects |
| $\lambda_{i,\text{dow}(t)}$ | Venue × day-of-week fixed effects |

Inference: Driscoll-Kraay standard errors (bandwidth = 30 days).  
Simultaneous 95 % confidence intervals via Bonferroni correction.

---

## Data Sources

| Dataset | Source | Coverage |
|---|---|---|
| Hourly attendance | City of Orléans open data | Jul 2021 – Nov 2024 |
| Wikipedia pageviews | [Wikimedia REST API](https://wikimedia.org/api/rest_v1/) | Jul 2021 – Nov 2024 |

### Tracked venues

| Venue | Wikipedia article |
|---|---|
| Hôtel Groslot | [fr.wikipedia.org](https://fr.wikipedia.org/wiki/H%C3%B4tel_Groslot) |
| Maison de Jeanne d'Arc | [fr.wikipedia.org](https://fr.wikipedia.org/wiki/Maison_de_Jeanne_d%27Arc_%C3%A0_Orl%C3%A9ans) |
| Musée des Beaux-Arts d'Orléans | [fr.wikipedia.org](https://fr.wikipedia.org/wiki/Mus%C3%A9e_des_Beaux-Arts_d%27Orl%C3%A9ans) |
| Musée historique et archéologique de l'Orléanais | [fr.wikipedia.org](https://fr.wikipedia.org/wiki/Mus%C3%A9e_historique_et_arch%C3%A9ologique_de_l%27Orl%C3%A9anais) |
| Muséum d'Orléans | [fr.wikipedia.org](https://fr.wikipedia.org/wiki/Mus%C3%A9um_d%27Orl%C3%A9ans_pour_la_biodiversit%C3%A9_et_l%27environnement) |
| Parc floral de la Source | [fr.wikipedia.org](https://fr.wikipedia.org/wiki/Parc_floral_de_la_Source) |

---

## Notes

- `Ville d'Orlean` is kept with the project spelling used in
  `data/references/wikipedia_pages.md` and the pipeline code; it serves as a
  city-level control and is excluded from the final venue-level merge.
- The derived workbooks bundled in `data/derived/` are pre-built snapshots
  included for convenience. Re-running the Python pipeline will regenerate them.
- All estimation output (JSON, figures, HTML report) can be fully reconstructed
  by following the four reproduction steps above.
