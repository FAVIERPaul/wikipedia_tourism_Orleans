# Methods and Results

# Empirical Setting and Transformation
The empirical analysis uses a daily venue-level panel linking attendance in Orleans cultural sites to French Wikipedia pageviews for the corresponding venue pages. The final estimation file contains 7,422 site-day observations, 6 venues, and 1,237 calendar dates from 2021-07-01 to 2024-11-18. Mean daily attendance is 133.48; 15.1 percent of site-days have zero attendance.
The outcome is y_it = log(1 + Attendance_it). The main Wikipedia variable is m_it = log(1 + Mobile pageviews_it), and desktop pageviews are transformed in the same way when used for prediction. This log(1 + x) transformation is necessary because Wikipedia traffic is a low-count variable: mean mobile pageviews are 4.22 and the median is 3. A level regression would translate one extra pageview into a fixed number of entries, which is not credible when pageviews are sparse and highly skewed. The log-log form keeps zero observations in the data and makes the coefficients elasticity-like for positive counts.
The low-count nature of the regressor also affects interpretation. A coefficient on log(1 + mobile pageviews) is not a literal elasticity at zero pageviews. It is best read as the change in log attendance associated with a proportional change in 1 + pageviews. At the sample median of three mobile pageviews, one additional mobile pageview increases log(1 + mobile pageviews) by log(5/4) = 0.223; using the preferred coefficient below, this corresponds to about 3.0 percent higher log attendance, all else equal.

# Main TWFE Timing Specification
The paper's preferred TWFE estimate is the day-0 coefficient from a distributed timing model that conditions on the full -30/+30 mobile-pageview profile and on attendance persistence.
The estimated equation is: y_it = sum_{k=-30}^{30} beta_k m_{i,t+k} + rho y_{i,t-1} + alpha_i + delta_t + eta_{i,ym(t)} + lambda_{i,dow(t)} + epsilon_it. Here alpha_i are venue fixed effects, delta_t are exact-date fixed effects, eta_{i,ym(t)} are venue-by-year-month fixed effects, and lambda_{i,dow(t)} are venue-by-day-of-week fixed effects. Negative k values are pageviews before the attendance date, k = 0 is same-day pageviews, and positive k values are pageviews after the attendance date.
Identification comes from within-venue deviations in same-day Wikipedia attention after removing permanent venue differences, shocks common to all venues on a date, venue-specific monthly patterns, venue-specific day-of-week patterns, the previous day's attendance, and the surrounding lead-lag pageview profile. This is a demanding specification: if the apparent relationship is only a slow moving attention trend or a calendar pattern, the coefficients away from day 0 should absorb it.
Inference uses Driscoll-Kraay standard errors with a 30-day bandwidth, indexed by date. The lead-lag figure and local timing table use Bonferroni simultaneous 95 percent confidence intervals across the 61 timing coefficients. This avoids interpreting isolated pointwise significant leads or lags as evidence when many timing coefficients are tested at once.

# RMSE Nowcasting Design
The prediction exercise is separate from identification. It asks whether Wikipedia pageviews improve short-run attendance nowcasts. Models are trained before the holdout period and evaluated on the last 180 calendar days of the panel, beginning on 2024-05-23. Predictions are evaluated on the attendance scale after transforming fitted log attendance back to entries.
The main forecast metric is RMSE = sqrt(N^{-1} sum_i,t (Attendance_it - Predicted attendance_it)^2). RMSE is appropriate when large mistakes are operationally costly, for example for staffing, security, ticketing, opening hours, or crowd management. It is less appropriate when the main failures come from closures, exceptional events, school holidays, weather shocks, or other one-off disruptions that are not predictable from the baseline covariates. Because RMSE heavily penalizes large misses, I also report MAE, log-RMSE, correlations, and rolling monthly validation.
A useful diagnostic is whether Wikipedia improves prediction in months or weekdays where the calendar baseline is weak. If day-of-week and month fixed effects already predict attendance well, pageviews should add little. If attendance is unusually high or low relative to its normal calendar pattern, same-day pageviews may help. Conversely, if attendance is driven by an unobserved closure or a private event, neither Wikipedia nor the calendar baseline should be expected to forecast it reliably.

# Preferred Result
The preferred DK lead-lag TWFE model estimates a day-0 mobile-pageview coefficient of 0.1355*** (0.0191). The simultaneous 95 percent confidence interval is [0.0716, 0.1994]. The model uses 7056 observations, has R2 = 0.908, and has within-R2 = 0.088. The high overall R2 mainly reflects the rich fixed effects and lagged attendance; the within-R2 is the more relevant measure of residual variation explained after fixed effects.
Econometrically, the coefficient says that a 1 percent increase in 1 + same-day mobile Wikipedia pageviews is associated with about a 0.136 percent increase in 1 + attendance, conditional on the fixed effects, lagged attendance, and the entire -30/+30 pageview profile. This is an association, not a causal effect: Wikipedia attention is interpreted as a high-frequency signal of public interest in the venue.
The timing pattern supports this interpretation. Day -1 is 0.0194, day 0 is 0.1355, and day +1 is 0.0412. In the full -30/+30 timing graph, day 0 is the only coefficient whose simultaneous DK confidence interval excludes zero. Thus the preferred result is a same-day signal, not a broad pattern of significant leads and lags.

| Model | Day-0 log mobile | Simultaneous 95% CI | R2 | Within R2 | N |
| --- | --- | --- | --- | --- | --- |
| Preferred DK lead-lag timing | 0.1355*** (0.0191) | [0.0716, 0.1994] | 0.908 | 0.088 | 7056 |

# Local Lead-Lag Window
The local timing table reports the DK estimates and Bonferroni simultaneous confidence intervals around the attendance date. All reported neighboring days have confidence intervals that include zero; only day 0 is statistically different from zero under the simultaneous correction.
| Relative day | Estimate | DK SE | Simult. CI low | Simult. CI high |
| --- | --- | --- | --- | --- |
| -5 | 0.0090 | 0.0220 | -0.0647 | 0.0827 |
| -4 | -0.0037 | 0.0194 | -0.0684 | 0.0611 |
| -3 | 0.0095 | 0.0208 | -0.0602 | 0.0792 |
| -2 | -0.0060 | 0.0214 | -0.0775 | 0.0654 |
| -1 | 0.0194 | 0.0174 | -0.0390 | 0.0778 |
| 0 | 0.1355 | 0.0191 | 0.0716 | 0.1994 |
| 1 | 0.0412 | 0.0222 | -0.0331 | 0.1155 |
| 2 | 0.0412 | 0.0176 | -0.0178 | 0.1002 |
| 3 | 0.0084 | 0.0209 | -0.0615 | 0.0783 |
| 4 | -0.0124 | 0.0189 | -0.0756 | 0.0508 |
| 5 | 0.0066 | 0.0193 | -0.0581 | 0.0713 |

# Lead-Lag Figure
The exported figure is title-free for insertion into the paper.

# Serial-Correlation Diagnostics
The large gap between simple timing regressions and the preferred lead-lag estimate is expected. Wikipedia pageviews are persistent, and attendance is also persistent. When each timing coefficient is estimated without the surrounding profile, leads and lags inherit the same slow-moving attention component and can look significant even when they do not identify the visit day. The preferred model forces each timing coefficient to compete with the rest of the -30/+30 profile and with lagged attendance.
Intermediate diagnostics confirm the direction of adjustment. The day-0 association is 0.3960 in a joint t-1/t/t+1 model, 0.2516 after adding lagged attendance and seven mobile-pageview lags, and 0.3390 when same-day mobile attention is first residualized on the previous week of mobile attention. These diagnostics show that serial dependence matters; the preferred 0.1355 estimate is the most conservative specification because it combines the full timing profile, lagged attendance, rich seasonality controls, and DK inference.

| Diagnostic model | Day-0 coefficient | Interpretation | R2 | Within R2 | N |
| --- | --- | --- | --- | --- | --- |
| Joint t-1/t/t+1 timing | 0.3960*** (0.0403) | Same-day association net of adjacent mobile days | 0.656 | 0.086 | 7410 |
| AR controls: lagged attendance + 7 mobile lags | 0.2516*** (0.0291) | Same-day association net of lagged attendance and previous-week mobile traffic | 0.744 | 0.315 | 7380 |
| Mobile innovation: residual from 7 mobile lags | 0.3390*** (0.0414) | Association with unpredictable same-day mobile attention | 0.633 | 0.020 | 7380 |

# Falsification Checks
The placebo exercises test whether the result is merely a common daily attention shock. When mobile pageviews are shuffled across venues within each date, the placebo distribution is centered at -0.0007 with a standard deviation of 0.0200; its 95th percentile is only 0.0329. This indicates that matching the correct venue to the correct Wikipedia page matters.
The rotated-site placebo is 0.1206*** (0.0363). This positive but smaller diagnostic suggests that part of the signal reflects general city-level attention, which is why the preferred specification absorbs exact-date shocks and venue-specific calendar seasonality. The falsification checks therefore support a site-specific interpretation, while also warning against a causal interpretation.

| Placebo diagnostic | Value |
| --- | --- |
| Within-date shuffle mean | -0.0007 |
| Within-date shuffle SD | 0.0200 |
| Within-date shuffle 95th percentile | 0.0329 |
| Rotated-site placebo coefficient | 0.1206*** (0.0363) |

# Nowcasting Results
In the terminal holdout, the best model on the attendance scale is Same-day log mobile + log desktop. It has RMSE = 220.36, MAE = 103.92, log-RMSE = 1.194, and correlation = 0.499. The calendar and city-pageview benchmark has RMSE = 223.11. The gain is 2.76 entries, or 1.2 percent of the benchmark RMSE.
In rolling monthly validation, Same-day log mobile + log desktop again has the lowest average attendance-scale RMSE: 202.74, compared with 207.87 for the calendar benchmark. The average gain is 5.12 entries, or 2.5 percent. The same-day mobile plus desktop model wins 4 of the six validation months, while the lagged mobile plus desktop model wins 2 months.
The ranking depends slightly on the loss function. On log-RMSE in rolling validation, the best model is Same-day log mobile with mean log-RMSE = 1.176. This means Wikipedia pageviews add useful predictive information, but the improvement is modest. In practical terms, Wikipedia is most useful as an operational alert for unusually high or low demand; it should not be used as the only attendance forecast.

| Holdout model | RMSE | MAE | Log RMSE | Correlation | N |
| --- | --- | --- | --- | --- | --- |
| Same-day log mobile + log desktop | 220.36 | 103.92 | 1.194 | 0.499 | 1080 |
| Lagged log mobile + log desktop | 220.55 | 104.11 | 1.202 | 0.490 | 1080 |
| Same-day log mobile | 222.11 | 104.61 | 1.188 | 0.493 | 1080 |
| Calendar + city controls | 223.11 | 104.32 | 1.230 | 0.462 | 1080 |

| Rolling model | Mean RMSE | Mean MAE | Mean log RMSE | Mean correlation |
| --- | --- | --- | --- | --- |
| Same-day log mobile + log desktop | 202.74 | 100.07 | 1.181 | 0.559 |
| Same-day log mobile | 204.08 | 100.49 | 1.176 | 0.554 |
| Lagged log mobile + log desktop | 204.30 | 100.40 | 1.188 | 0.539 |
| Calendar + city controls | 207.87 | 101.10 | 1.209 | 0.516 |

# Interpretation
The final interpretation is that Wikipedia pageviews are a contemporaneous attention signal for attendance. The preferred coefficient is 0.1355, not a large level effect and not a causal impact of Wikipedia browsing on visits. The timing evidence is concentrated on day 0 after DK inference and simultaneous correction. The prediction results show modest but real nowcasting value, especially when attendance deviates from its ordinary calendar pattern.
For the paper, the defensible claim is therefore narrow and precise: after controlling for venue fixed effects, exact-date fixed effects, venue-specific seasonality, lagged attendance, and the full lead-lag pageview profile, same-day mobile Wikipedia attention is positively associated with same-day attendance. The evidence supports Wikipedia pageviews as a real-time signal, not as a standalone forecasting system and not as a causal treatment.
