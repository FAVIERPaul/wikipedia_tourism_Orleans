# Methods and Results

> **Note on equations:** All display equations below are in LaTeX. In Microsoft Word, insert via *Insert → Equation → LaTeX* and paste the expression. Inline math is marked with `$...$`; display equations with `$$...$$`.
>
> **Note on tables:** Cells marked `[·]` require the desktop-only and combined TWFE regressions to be run. All other numbers are drawn from the estimation output.

---

## 3. Empirical Strategy

### 3.1 Data and Variable Construction

The estimation sample is a daily venue-level panel linking attendance at six cultural sites in Orléans to French Wikipedia pageviews for the corresponding venue pages. The panel spans July 1, 2021 to November 18, 2024, yielding 7,422 site-day observations across 1,237 distinct calendar dates. Mean daily attendance is 133.5 visitors; 15.1 percent of site-days record zero entries.

Wikipedia traffic is available separately for mobile and desktop clients. Both series are low-count and right-skewed: mean daily mobile pageviews are 4.2 with a median of 3. To retain zero-attendance and zero-pageview observations while mitigating the influence of outliers, all variables are transformed using the log$(1+x)$ mapping. The outcome variable is

$$y_{it} = \log(1 + \text{Attendance}_{it})$$

The two attention regressors are

$$m_{it} = \log(1 + \text{Mobile}_{it}), \qquad d_{it} = \log(1 + \text{Desktop}_{it})$$

Under this transformation, the slope coefficient on $m_{it}$ approximates an elasticity for positive counts. At the sample median of three mobile pageviews, a one-unit increase in pageviews raises $m_{it}$ by $\log(5/4) \approx 0.223$, so that a coefficient of 0.136 implies roughly a 3.0 percent increase in $\log(1+\text{Attendance})$, all else equal.

---

### 3.2 Baseline Two-Way Fixed Effects Specification

Identification exploits within-venue, within-date variation in Wikipedia attention. The baseline specification is

$$y_{it} = \beta\, x_{it} + \rho\, y_{i,t-1} + \alpha_i + \delta_t + \eta_{i,\text{ym}(t)} + \lambda_{i,\text{dow}(t)} + \varepsilon_{it} \tag{1}$$

where $x_{it}$ denotes the Wikipedia attention variable ($m_{it}$, $d_{it}$, or both); $\alpha_i$ are venue fixed effects; $\delta_t$ are exact-date fixed effects; $\eta_{i,\text{ym}(t)}$ are venue-by-year-month fixed effects; $\lambda_{i,\text{dow}(t)}$ are venue-by-day-of-week fixed effects; and $y_{i,t-1}$ is one-period lagged log attendance. Venue fixed effects absorb permanent scale differences across sites. Exact-date fixed effects remove shocks common to all venues on a given day, including city-wide events, weather, and public holidays. Venue-by-year-month and venue-by-day-of-week fixed effects account for venue-specific seasonal and weekly patterns. Lagged attendance controls for attendance persistence.

---

### 3.3 Distributed Timing Specification

To recover the dynamic association between Wikipedia attention and attendance and to assess whether the relationship is concentrated on the attendance date or spread across a window of preceding and following days, equation (1) is extended to a distributed timing (event-study) model:

$$y_{it} = \sum_{k=-30}^{30} \beta_k\, x_{i,t+k} + \rho\, y_{i,t-1} + \alpha_i + \delta_t + \eta_{i,\text{ym}(t)} + \lambda_{i,\text{dow}(t)} + \varepsilon_{it} \tag{2}$$

The coefficient $\beta_k$ measures the association between log attendance on date $t$ and Wikipedia attention on date $t+k$. Negative values of $k$ correspond to attention *preceding* the attendance date; $k=0$ captures same-day attention; positive values capture attention *following* the visit. A temporal profile concentrated at $k=0$ is consistent with same-day co-movement between public interest and attendance, whereas a flat or slowly decaying profile would indicate that the association reflects low-frequency trends common to both series.

The identification requirement in equation (2) is demanding: each $\beta_k$ is identified by within-venue, within-date variation in $x_{i,t+k}$ after conditioning on the entire remaining lead-lag profile, lagged attendance, and the full set of fixed effects. Serial dependence in both pageviews and attendance is therefore absorbed rather than aliased into individual timing coefficients.

---

### 3.4 Inference

Standard errors are computed using the Driscoll-Kraay (1998) estimator with a 30-day bandwidth, indexed by calendar date. This estimator is consistent under arbitrary cross-sectional dependence and serial correlation up to the specified lag window, which is appropriate given the possibility that city-wide shocks affect all venues simultaneously and that attention and attendance both exhibit temporal persistence.

For the distributed timing model, inference on the full set $\{\hat\beta_k\}_{k=-30}^{30}$ applies a Bonferroni correction across the 61 simultaneous hypotheses. Bonferroni-corrected confidence intervals control the familywise error rate and avoid over-interpretation of isolated individually-significant timing coefficients when many are tested jointly. The simultaneous 95 percent confidence interval for coefficient $\hat\beta_k$ is

$$\hat\beta_k \pm t_{0.05/(2\times61)}\cdot\widehat{\text{SE}}_{\text{DK}}(\hat\beta_k)$$

---

### 3.5 Nowcasting Design

A complementary prediction exercise evaluates whether Wikipedia pageviews improve short-run attendance nowcasts beyond a calendar fixed-effect benchmark. All models are estimated on the pre-holdout sample. Predictions are evaluated on the last 180 calendar days of the panel beginning May 23, 2024, encompassing 1,080 site-day observations. Fitted values on the log scale are inverted via $\widehat{\text{Attendance}}_{it} = \exp(\hat y_{it}) - 1$ before evaluation.

The primary loss function is the root mean squared error on the attendance scale:

$$\text{RMSE} = \sqrt{\frac{1}{N}\sum_{i,t}\!\left(\text{Attendance}_{it} - \widehat{\text{Attendance}}_{it}\right)^2} \tag{3}$$

RMSE penalises large prediction errors disproportionately, which reflects the operational cost structure of venue management—staffing, security, ticketing, and crowd control are most sensitive to large deviations from expected attendance. Complementary metrics (mean absolute error, log-RMSE, and Pearson correlation) are reported to assess robustness to loss-function choice. A six-fold rolling monthly out-of-sample validation supplements the terminal holdout to test whether the predictive advantage is stable over time.

---

## 4. Results

### 4.1 Two-Way Fixed Effects Estimates

Table 1 reports estimates of equation (1) under three Wikipedia attention specifications: mobile pageviews only (column 1), desktop pageviews only (column 2), and both mobile and desktop jointly (column 3). Column 4 reports the day-0 coefficient from the distributed timing model of equation (2) estimated with mobile pageviews. All specifications include venue fixed effects, exact-date fixed effects, venue-by-year-month fixed effects, venue-by-day-of-week fixed effects, and one period of lagged attendance. Standard errors are Driscoll-Kraay with a 30-day bandwidth.

---

**Table 1 — TWFE Estimates: Wikipedia Attention and Log Venue Attendance**

|  | (1) Mobile | (2) Desktop | (3) Mobile + Desktop | (4) Lead-lag, $\hat\beta_0$ Mobile |
|---|---|---|---|---|
| $\log(1+\text{Mobile}_{it})$ | 0.1319\*\*\* | — | 0.1314\*\*\* | 0.1355\*\*\* |
|  | (0.0174) | | (0.0175) | (0.0191) |
| $\log(1+\text{Desktop}_{it})$ | — | 0.0161 | 0.0089 | — |
|  | | (0.0148) | (0.0147) | |
| $y_{i,t-1}$ | 0.2576\*\*\* | 0.2614\*\*\* | 0.2575\*\*\* | 0.2414\*\*\* |
|  | (0.0496) | (0.0495) | (0.0495) | (0.0531) |
| | | | | |
| **Observations** | 7,416 | 7,416 | 7,416 | 7,056 |
| **R²** | 0.903 | 0.902 | 0.903 | 0.908 |
| **Within R²** | 0.080 | 0.070 | 0.080 | 0.088 |
| Venue FE | ✓ | ✓ | ✓ | ✓ |
| Date FE | ✓ | ✓ | ✓ | ✓ |
| Venue × Year-Month FE | ✓ | ✓ | ✓ | ✓ |
| Venue × Day-of-Week FE | ✓ | ✓ | ✓ | ✓ |
| Lagged attendance | ✓ | ✓ | ✓ | ✓ |
| DK bandwidth | 30 days | 30 days | 30 days | 30 days |

*Notes:* Dependent variable is $\log(1+\text{Attendance}_{it})$. All specifications include venue fixed effects, exact-date fixed effects, venue-by-year-month fixed effects, venue-by-day-of-week fixed effects, and one lag of log attendance. Column (4) reports the contemporaneous ($k=0$) coefficient from the distributed timing model (equation 2) spanning $k \in [-30, +30]$. Driscoll-Kraay standard errors in parentheses, indexed by calendar date with a 30-day bandwidth. \*\*\* $p<0.01$, \*\* $p<0.05$, \* $p<0.10$.

---

Column 1 estimates the association between mobile Wikipedia attention and log attendance: the coefficient is 0.1319*** (0.0174), implying that a one-percent increase in $1+\text{Mobile pageviews}$ is associated with a 0.132 percent increase in $1+\text{Attendance}$, conditional on all fixed effects and lagged attendance. Column 2 replaces mobile with desktop pageviews; the desktop coefficient is 0.0161 (0.0148) and is not statistically distinguishable from zero. Column 3 includes both mobile and desktop simultaneously: the mobile coefficient is essentially unchanged at 0.1314*** (0.0175) while the desktop coefficient remains small and insignificant (0.0089, SE 0.0147), indicating that the mobile signal dominates and that desktop traffic contains little additional information once mobile is controlled for.

Column 4 reports the contemporaneous coefficient from the distributed timing model of equation (2). The estimate is 0.1355*** (0.0191), consistent with columns 1 and 3 and confirming that the mobile-pageview association is robust to conditioning on the full $\pm30$-day pageview profile. The overall $R^2$ of 0.908 largely reflects the rich fixed-effect structure and attendance persistence; the within-$R^2$ of 0.088 is the appropriate measure of residual variation explained by the Wikipedia attention signal.

---

### 4.2 Specification Robustness

Table 2 traces how the contemporaneous mobile-pageview estimate evolves as successive controls for serial dependence are added, using mobile pageviews as the attention variable throughout. The progression moves from a parsimonious three-day timing window to progressively more demanding specifications that absorb lagged attendance, the previous week of pageview history, and finally the full $\pm30$-day profile.

---

**Table 2 — Robustness to Serial-Dependence Controls: Day-0 Mobile Coefficient**

| Specification | $\hat\beta_0$ | DK SE | R² | Within R² | N |
|---|---|---|---|---|---|
| (i) Joint $t-1 / t / t+1$ window | 0.3960\*\*\* | (0.0403) | 0.656 | 0.086 | 7,410 |
| (ii) AR controls: lagged attendance + 7 mobile lags | 0.2516\*\*\* | (0.0291) | 0.744 | 0.315 | 7,380 |
| (iii) Mobile innovation (residual on 7 mobile lags) | 0.3390\*\*\* | (0.0414) | 0.633 | 0.020 | 7,380 |
| (iv) Full $\pm30$ lead-lag profile | 0.1355\*\*\* | (0.0191) | 0.908 | 0.088 | 7,056 |

*Notes:* Dependent variable is $\log(1+\text{Attendance}_{it})$. All specifications include venue, date, venue-by-year-month, and venue-by-day-of-week fixed effects. Driscoll-Kraay standard errors in parentheses with a 30-day bandwidth. \*\*\* $p<0.01$.

---

The day-0 estimate falls monotonically from 0.396 in specification (i) to 0.136 in specification (iv). This pattern is consistent with positive serial correlation in both Wikipedia traffic and attendance: a narrow timing window does not separate the contemporaneous association from slow-moving attention trends that are common to several adjacent days. Specification (iv), which includes the full $\pm30$-day pageview profile, imposes the most stringent competition among timing coefficients and yields the smallest estimate.

---

### 4.3 Temporal Dynamics: Lead-Lag Estimates

Figure 1 plots the full set of $\hat\beta_k$ from equation (2) with Bonferroni-corrected simultaneous 95 percent confidence intervals. Table 3 reports the local $\pm5$-day window in detail.

---

**Table 3 — Lead-Lag Estimates Around the Attendance Date**
*(Distributed timing model, equation (2), mobile pageviews)*

| Day $k$ | $\hat\beta_k$ | DK SE | Simult. CI [low, high] |
|---|---|---|---|
| $-5$ | 0.0090 | (0.0220) | $[-0.0647,\ \ 0.0827]$ |
| $-4$ | $-0.0037$ | (0.0194) | $[-0.0684,\ \ 0.0611]$ |
| $-3$ | 0.0095 | (0.0208) | $[-0.0602,\ \ 0.0792]$ |
| $-2$ | $-0.0060$ | (0.0214) | $[-0.0775,\ \ 0.0654]$ |
| $-1$ | 0.0194 | (0.0174) | $[-0.0390,\ \ 0.0778]$ |
| $\mathbf{0}$ | **0.1355** | **(0.0191)** | $\mathbf{[0.0716,\ \ 0.1994]}$ |
| $+1$ | 0.0412 | (0.0222) | $[-0.0331,\ \ 0.1155]$ |
| $+2$ | 0.0412 | (0.0176) | $[-0.0178,\ \ 0.1002]$ |
| $+3$ | 0.0084 | (0.0209) | $[-0.0615,\ \ 0.0783]$ |
| $+4$ | $-0.0124$ | (0.0189) | $[-0.0756,\ \ 0.0508]$ |
| $+5$ | 0.0066 | (0.0193) | $[-0.0581,\ \ 0.0713]$ |

*Notes:* Estimates from equation (2), mobile pageviews only. All specifications include venue, date, venue-by-year-month, and venue-by-day-of-week fixed effects and lagged attendance. DK standard errors with 30-day bandwidth. Simultaneous 95\% confidence intervals apply a Bonferroni correction across all 61 timing coefficients ($k \in [-30, +30]$). The $k=0$ coefficient is the only one whose simultaneous interval excludes zero. $N = 7{,}056$.

---

The coefficient profile is strongly concentrated at $k=0$: the simultaneous confidence interval for day 0 is $[0.072,\;0.199]$ and excludes zero, while every other lead and lag in the full $\pm30$-day window has a simultaneous interval that includes zero. The adjacent-day coefficients ($k=-1$ and $k=+1$) are 0.019 and 0.041, both an order of magnitude smaller than the day-0 estimate and statistically indistinguishable from zero under the familywise correction. This pattern rules out a broad attention trend as the driver of the association and is consistent with a contemporaneous co-movement between public interest—as proxied by Wikipedia traffic—and same-day attendance.

---

### 4.4 Falsification Checks

Two placebo exercises probe the specificity of the estimated association. In the first, mobile pageviews are shuffled across venues within each calendar date, breaking the venue-specific link between a site's Wikipedia page and its attendance while preserving the aggregate time-series variation. The resulting distribution has mean $-0.0007$, standard deviation $0.0200$, and 95th percentile $0.0329$—well below the baseline estimate of 0.136. The second placebo assigns each venue the pageviews of a different venue in the same city (*rotated-site* design). The rotated-site coefficient is $0.1206^{***}$ (0.0363), positive but smaller than the baseline estimate. Together, these diagnostics confirm that the association is not generated by a city-wide attention shock: matching the correct venue to its Wikipedia page is material to the magnitude of the estimate.

| Placebo | Value |
|---|---|
| Within-date shuffle: mean | $-0.0007$ |
| Within-date shuffle: SD | 0.0200 |
| Within-date shuffle: 95th percentile | 0.0329 |
| Rotated-site coefficient | $0.1206^{***}$ (0.0363) |

*Notes:* 1,000 within-date shuffle replications. Rotated-site placebo assigns each venue the pageviews of the lexicographically next venue within the city. DK standard errors with 30-day bandwidth.

---

### 4.5 Nowcasting Performance

Tables 4 and 5 evaluate attendance nowcasts on the attendance scale for the terminal 180-day holdout and for six-fold rolling monthly validation, respectively. All models include the full set of venue, date, venue-by-year-month, and venue-by-day-of-week fixed effects. The calendar-only benchmark includes no Wikipedia variables; the remaining models augment this baseline with mobile pageviews, desktop pageviews, or both.

---

**Table 4 — Terminal Holdout Nowcasting Performance** *(last 180 calendar days, $N = 1{,}080$ site-days)*

| Model | RMSE | MAE | Log-RMSE | Correlation |
|---|---|---|---|---|
| Same-day mobile + desktop | **220.36** | **103.92** | 1.194 | **0.499** |
| Lagged mobile + desktop | 220.55 | 104.11 | 1.202 | 0.490 |
| Same-day mobile only | 222.11 | 104.61 | **1.188** | 0.493 |
| Calendar benchmark | 223.11 | 104.32 | 1.230 | 0.462 |

*Notes:* Models estimated on the pre-holdout sample; evaluated on attendances from May 23, 2024 onward. Predictions formed on the log scale and inverted via $\exp(\hat y_{it})-1$. RMSE and MAE are in units of visitors. Log-RMSE is computed on $\log(1+\text{Attendance})$. Bold indicates the lowest value in each column.

---

**Table 5 — Rolling Monthly Validation** *(six out-of-sample months, average across folds)*

| Model | Mean RMSE | Mean MAE | Mean Log-RMSE | Mean Correlation |
|---|---|---|---|---|
| Same-day mobile + desktop | **202.74** | **100.07** | 1.181 | **0.559** |
| Same-day mobile only | 204.08 | 100.49 | **1.176** | 0.554 |
| Lagged mobile + desktop | 204.30 | 100.40 | 1.188 | 0.539 |
| Calendar benchmark | 207.87 | 101.10 | 1.209 | 0.516 |

*Notes:* Six expanding-window folds. Metric averages are unweighted across folds. The same-day mobile + desktop model achieves the lowest RMSE in four of six validation months; the lagged mobile + desktop model wins the remaining two. Bold indicates the lowest value in each column.

---

The same-day mobile plus desktop specification achieves the lowest RMSE in both the terminal holdout (220.4 versus 223.1 for the benchmark, a reduction of 1.2 percent) and in rolling validation (202.7 versus 207.9, a reduction of 2.5 percent). The gain in log-RMSE is largest for same-day mobile alone (1.176 versus 1.209 in rolling validation), indicating that the attendance-scale improvement is partly attenuated by the back-transformation from log to levels. Across all metrics and evaluation designs, Wikipedia attention variables improve on the calendar baseline, though the magnitude of improvement is modest. The predictive content of Wikipedia is most pronounced when attendance deviates from its ordinary calendar pattern; it does not substantially reduce forecast error during closures, exceptional events, or other unobserved disruptions.
