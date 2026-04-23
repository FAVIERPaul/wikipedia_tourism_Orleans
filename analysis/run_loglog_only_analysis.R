library(readxl)
library(dplyr)
library(tidyr)
library(fixest)
library(jsonlite)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

find_latest_file <- function(directory, pattern) {
  files <- list.files(directory, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) {
    stop(sprintf("No file found in '%s' matching '%s'.", directory, pattern), call. = FALSE)
  }
  files[which.max(file.info(files)$mtime)]
}

fmt_num <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(x, format = "f", digits = digits, big.mark = ","))
}

fmt_pct <- function(x, digits = 1) {
  paste0(fmt_num(100 * x, digits = digits), "%")
}

stars <- function(p) {
  ifelse(is.na(p), "", ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", ""))))
}

dk_vcov <- DK(30) ~ date

format_term <- function(model, term, vcov = dk_vcov, digits = 4) {
  ct <- fixest::coeftable(model, vcov = vcov)
  if (!term %in% rownames(ct)) {
    return("")
  }
  paste0(fmt_num(ct[term, 1], digits), stars(ct[term, 4]), " (", fmt_num(ct[term, 2], digits), ")")
}

fit_value <- function(model, type) {
  out <- tryCatch(suppressWarnings(as.numeric(fixest::fitstat(model, type)))[1], error = function(e) NA_real_)
  out
}

safe_cor <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 2 || stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) {
    return(NA_real_)
  }
  stats::cor(x[ok], y[ok])
}

winsorize_vec <- function(x, probs = c(0.01, 0.99)) {
  bounds <- stats::quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  pmin(pmax(x, bounds[1]), bounds[2])
}

score_predictions <- function(actual, pred_entries, actual_log, pred_log) {
  ok_entries <- is.finite(actual) & is.finite(pred_entries)
  ok_log <- is.finite(actual_log) & is.finite(pred_log)
  data.frame(
    n = sum(ok_entries),
    rmse_entries = sqrt(mean((actual[ok_entries] - pred_entries[ok_entries])^2)),
    mae_entries = mean(abs(actual[ok_entries] - pred_entries[ok_entries])),
    rmse_log = sqrt(mean((actual_log[ok_log] - pred_log[ok_log])^2)),
    correlation_entries = safe_cor(actual[ok_entries], pred_entries[ok_entries])
  )
}

lead_lag_name <- function(prefix, relative_day) {
  if (relative_day < 0) {
    paste0(prefix, "_m", abs(relative_day))
  } else if (relative_day > 0) {
    paste0(prefix, "_p", relative_day)
  } else {
    paste0(prefix, "_0")
  }
}

lead_lag_terms <- function(prefix, window) {
  vapply(seq(-window, window), function(k) lead_lag_name(prefix, k), character(1))
}

add_lead_lag_columns <- function(df, var, window, prefix) {
  out <- df |>
    arrange(lieu, date) |>
    group_by(lieu)

  for (k in seq(-window, window)) {
    nm <- lead_lag_name(prefix, k)
    out <- out |>
      mutate(
        !!nm := if (k < 0) {
          dplyr::lag(.data[[var]], abs(k))
        } else if (k > 0) {
          dplyr::lead(.data[[var]], k)
        } else {
          .data[[var]]
        }
      )
  }

  out |> ungroup()
}

extract_terms <- function(model, terms, vcov = dk_vcov) {
  ct <- fixest::coeftable(model, vcov = vcov)
  ci <- suppressWarnings(confint(model, vcov = vcov))
  data.frame(
    term = terms,
    estimate = ifelse(terms %in% rownames(ct), ct[terms, 1], NA_real_),
    std_error = ifelse(terms %in% rownames(ct), ct[terms, 2], NA_real_),
    conf_low = ifelse(terms %in% rownames(ci), ci[terms, 1], NA_real_),
    conf_high = ifelse(terms %in% rownames(ci), ci[terms, 2], NA_real_)
  )
}

load_loglog_data <- function(root = ".", city_label = "Ville d'Orlean") {
  derived_dir <- file.path(root, "data", "derived")
  merged_path <- find_latest_file(derived_dir, "^merged_attendance_wikipedia_fr_.*\\.xlsx$")
  wiki_path <- find_latest_file(derived_dir, "^wikipedia_pageviews_fr_.*\\.xlsx$")

  merged <- readxl::read_excel(merged_path, sheet = "merged") |>
    mutate(date = as.Date(jour, format = "%d/%m/%Y"))

  wiki <- readxl::read_excel(wiki_path, sheet = "daily_pageviews") |>
    mutate(date = as.Date(jour, format = "%d/%m/%Y"))

  city_daily <- wiki |>
    filter(lieu == city_label) |>
    transmute(
      date,
      city_mobile = pv_user_mobile,
      city_desktop = pv_user_desktop,
      city_all_access = pv_user_all_access
    )

  day_labels <- c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")

  df <- merged |>
    transmute(
      date,
      lieu,
      nombre_entrees,
      pv_user_mobile,
      pv_user_desktop,
      pv_user_all_access
    ) |>
    left_join(city_daily, by = "date") |>
    arrange(lieu, date) |>
    mutate(
      dow = factor(
        day_labels[as.POSIXlt(date)$wday + 1],
        levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
      ),
      month = factor(month.abb[as.POSIXlt(date)$mon + 1], levels = month.abb),
      year_month = factor(format(date, "%Y-%m")),
      trend_index = as.integer(date - min(date)) + 1L,
      log_entrees = log1p(nombre_entrees),
      log_mobile = log1p(pv_user_mobile),
      log_desktop = log1p(pv_user_desktop),
      log_city_mobile = log1p(city_mobile),
      log_city_desktop = log1p(city_desktop),
      log_mobile_winsor = log1p(winsorize_vec(pv_user_mobile))
    ) |>
    group_by(lieu) |>
    mutate(
      log_mobile_lag1 = lag(log_mobile, 1),
      log_mobile_lead1 = lead(log_mobile, 1),
      log_desktop_lag1 = lag(log_desktop, 1),
      log_desktop_lead1 = lead(log_desktop, 1)
    ) |>
    ungroup() |>
    arrange(date, lieu)

  list(df = df, merged_path = merged_path, wiki_path = wiki_path)
}

fit_nowcast_models_log <- function(train_df) {
  list(
    calendar = stats::lm(
      log_entrees ~ lieu + dow + month + lieu:trend_index + log_city_mobile + log_city_desktop,
      data = train_df
    ),
    lag_only = stats::lm(
      log_entrees ~ lieu + dow + month + lieu:trend_index + log_city_mobile + log_city_desktop +
        log_mobile_lag1 + log_desktop_lag1,
      data = train_df |> filter(!is.na(log_mobile_lag1), !is.na(log_desktop_lag1))
    ),
    same_day_mobile = stats::lm(
      log_entrees ~ lieu + dow + month + lieu:trend_index + log_city_mobile + log_city_desktop +
        log_mobile,
      data = train_df
    ),
    same_day_mobile_desktop = stats::lm(
      log_entrees ~ lieu + dow + month + lieu:trend_index + log_city_mobile + log_city_desktop +
        log_mobile + log_desktop,
      data = train_df
    )
  )
}

predict_log_models <- function(models, new_df) {
  pred_log <- data.frame(
    pred_log_calendar = as.numeric(stats::predict(models$calendar, newdata = new_df)),
    pred_log_lag_only = as.numeric(stats::predict(models$lag_only, newdata = new_df)),
    pred_log_same_day_mobile = as.numeric(stats::predict(models$same_day_mobile, newdata = new_df)),
    pred_log_same_day_mobile_desktop = as.numeric(stats::predict(models$same_day_mobile_desktop, newdata = new_df))
  )
  pred_entries <- as.data.frame(lapply(pred_log, function(x) pmax(0, expm1(x))))
  names(pred_entries) <- sub("^pred_log_", "pred_", names(pred_log))
  cbind(pred_log, pred_entries)
}

score_nowcast_log <- function(test_df, predictions) {
  bind_rows(
    score_predictions(test_df$nombre_entrees, predictions$pred_calendar, test_df$log_entrees, predictions$pred_log_calendar) |>
      mutate(model = "Calendar + city controls"),
    score_predictions(test_df$nombre_entrees, predictions$pred_lag_only, test_df$log_entrees, predictions$pred_log_lag_only) |>
      mutate(model = "Lagged log mobile + log desktop"),
    score_predictions(test_df$nombre_entrees, predictions$pred_same_day_mobile, test_df$log_entrees, predictions$pred_log_same_day_mobile) |>
      mutate(model = "Same-day log mobile"),
    score_predictions(test_df$nombre_entrees, predictions$pred_same_day_mobile_desktop, test_df$log_entrees, predictions$pred_log_same_day_mobile_desktop) |>
      mutate(model = "Same-day log mobile + log desktop")
  ) |>
    arrange(rmse_entries)
}

run_monthly_nowcast_log <- function(df, n_test_months = 6) {
  month_start <- as.Date(paste0(format(df$date, "%Y-%m"), "-01"))
  test_months <- utils::tail(sort(unique(month_start)), n_test_months)

  detail <- lapply(test_months, function(current_month) {
    next_month <- seq(current_month, by = "month", length.out = 2)[2]
    train_df <- df |> filter(date < current_month)
    test_df <- df |> filter(date >= current_month, date < next_month)
    models <- fit_nowcast_models_log(train_df)
    predictions <- predict_log_models(models, test_df)
    score_nowcast_log(test_df, predictions) |>
      mutate(test_month = format(current_month, "%Y-%m")) |>
      select(test_month, everything())
  }) |>
    bind_rows()

  summary <- detail |>
    group_by(model) |>
    summarise(
      mean_rmse_entries = mean(rmse_entries, na.rm = TRUE),
      mean_mae_entries = mean(mae_entries, na.rm = TRUE),
      mean_rmse_log = mean(rmse_log, na.rm = TRUE),
      mean_correlation_entries = mean(correlation_entries, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(mean_rmse_entries)

  list(detail = detail, summary = summary)
}

project_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = FALSE)
paths <- load_loglog_data(project_root)
df <- paths$df
df <- df |>
  arrange(lieu, date) |>
  group_by(lieu) |>
  mutate(
    log_entrees_lag1 = lag(log_entrees, 1),
    log_mobile_lag2 = lag(log_mobile, 2),
    log_mobile_lag3 = lag(log_mobile, 3),
    log_mobile_lag4 = lag(log_mobile, 4),
    log_mobile_lag5 = lag(log_mobile, 5),
    log_mobile_lag6 = lag(log_mobile, 6),
    log_mobile_lag7 = lag(log_mobile, 7)
  ) |>
  ungroup()

sample_start <- min(df$date)
sample_end <- max(df$date)
n_obs <- nrow(df)
n_places <- n_distinct(df$lieu)
n_dates <- n_distinct(df$date)
zero_share <- mean(df$nombre_entrees == 0)

m_log_mobile <- feols(
  log_entrees ~ log_mobile | lieu + date,
  data = df,
  panel.id = ~ lieu + date
)

m_log_mobile_desktop <- feols(
  log_entrees ~ log_mobile + log_desktop | lieu + date,
  data = df,
  panel.id = ~ lieu + date
)

m_full_mobile <- feols(
  log_entrees ~ log_mobile + log_entrees_lag1 | lieu + date + lieu^year_month + lieu^dow,
  data = df |> filter(!is.na(log_entrees_lag1)),
  panel.id = ~ lieu + date
)

m_full_desktop <- feols(
  log_entrees ~ log_desktop + log_entrees_lag1 | lieu + date + lieu^year_month + lieu^dow,
  data = df |> filter(!is.na(log_entrees_lag1)),
  panel.id = ~ lieu + date
)

m_full_mobile_desktop <- feols(
  log_entrees ~ log_mobile + log_desktop + log_entrees_lag1 | lieu + date + lieu^year_month + lieu^dow,
  data = df |> filter(!is.na(log_entrees_lag1)),
  panel.id = ~ lieu + date
)

m_log_trends <- feols(
  log_entrees ~ log_mobile + log_desktop | lieu + date + lieu[trend_index],
  data = df,
  panel.id = ~ lieu + date
)

m_log_positive <- feols(
  log_entrees ~ log_mobile + log_desktop | lieu + date,
  data = df |> filter(nombre_entrees > 0),
  panel.id = ~ lieu + date
)

m_log_city <- feols(
  log_entrees ~ log_mobile + log_desktop + log_city_mobile + log_city_desktop |
    lieu + year_month + dow + lieu[trend_index],
  data = df,
  panel.id = ~ lieu + date
)

m_log_winsor <- feols(
  log_entrees ~ log_mobile_winsor + log_desktop | lieu + date,
  data = df,
  panel.id = ~ lieu + date
)

m_log_lag <- feols(
  log_entrees ~ log_mobile_lag1 | lieu + date,
  data = df |> filter(!is.na(log_mobile_lag1)),
  panel.id = ~ lieu + date
)

m_log_lead <- feols(
  log_entrees ~ log_mobile_lead1 | lieu + date,
  data = df |> filter(!is.na(log_mobile_lead1)),
  panel.id = ~ lieu + date
)

m_log_timing <- feols(
  log_entrees ~ log_mobile + log_mobile_lag1 + log_mobile_lead1 | lieu + date,
  data = df |> filter(!is.na(log_mobile_lag1), !is.na(log_mobile_lead1)),
  panel.id = ~ lieu + date
)

ar_df <- df |>
  filter(
    !is.na(log_entrees_lag1),
    !is.na(log_mobile_lag1),
    !is.na(log_mobile_lag2),
    !is.na(log_mobile_lag3),
    !is.na(log_mobile_lag4),
    !is.na(log_mobile_lag5),
    !is.na(log_mobile_lag6),
    !is.na(log_mobile_lag7)
  )

m_log_ar_controls <- feols(
  log_entrees ~ log_mobile + log_entrees_lag1 + log_mobile_lag1 + log_mobile_lag2 +
    log_mobile_lag3 + log_mobile_lag4 + log_mobile_lag5 + log_mobile_lag6 + log_mobile_lag7 |
    lieu + date,
  data = ar_df,
  panel.id = ~ lieu + date
)

m_mobile_innovation <- feols(
  log_mobile ~ log_mobile_lag1 + log_mobile_lag2 + log_mobile_lag3 + log_mobile_lag4 +
    log_mobile_lag5 + log_mobile_lag6 + log_mobile_lag7 | lieu + date,
  data = ar_df,
  panel.id = ~ lieu + date
)

innovation_df <- ar_df |>
  mutate(log_mobile_innovation = as.numeric(resid(m_mobile_innovation)))

m_log_mobile_innovation <- feols(
  log_entrees ~ log_mobile_innovation | lieu + date,
  data = innovation_df,
  panel.id = ~ lieu + date
)

set.seed(123)
placebo_draws <- 200
placebo_shuffle <- numeric(placebo_draws)
for (b in seq_len(placebo_draws)) {
  placebo_df <- df |>
    group_by(date) |>
    mutate(log_mobile_placebo = sample(log_mobile, size = n(), replace = FALSE)) |>
    ungroup()
  placebo_model <- feols(
    log_entrees ~ log_mobile_placebo | lieu + date,
    data = placebo_df,
    panel.id = ~ lieu + date
  )
  placebo_shuffle[b] <- coef(placebo_model)[["log_mobile_placebo"]]
}

places <- sort(unique(df$lieu))
rotated_places <- stats::setNames(c(places[-1], places[1]), places)
rotation_lookup <- data.frame(
  lieu = names(rotated_places),
  rotated_lieu = unname(rotated_places),
  stringsAsFactors = FALSE
)
rotated_source <- df |>
  select(date, rotated_lieu = lieu, log_mobile_rotated = log_mobile)
rotated_df <- df |>
  left_join(rotation_lookup, by = "lieu") |>
  left_join(rotated_source, by = c("date", "rotated_lieu"))
m_log_rotated <- feols(
  log_entrees ~ log_mobile_rotated | lieu + date,
  data = rotated_df,
  panel.id = ~ lieu + date
)

window <- 30
ll_terms <- lead_lag_terms("log_mobile", window)
df_ll <- add_lead_lag_columns(df, "log_mobile", window, "log_mobile")
lead_lag_df <- bind_rows(lapply(seq(-window, window), function(k) {
  term <- lead_lag_name("log_mobile", k)
  model_df <- df_ll |>
    filter(!is.na(.data[[term]]))
  model <- feols(
    as.formula(paste("log_entrees ~", term, "| lieu + date")),
    data = model_df,
    panel.id = ~ lieu + date
  )
  ct <- fixest::coeftable(model, vcov = dk_vcov)
  ci <- suppressWarnings(confint(model, vcov = dk_vcov))
  data.frame(
    term = term,
    estimate = ct[term, 1],
    std_error = ct[term, 2],
    conf_low = ci[term, 1],
    conf_high = ci[term, 2],
    relative_day = k
  )
}))

ll_joint_model <- feols(
  as.formula(paste("log_entrees ~", paste(ll_terms, collapse = " + "), "| lieu + date")),
  data = df_ll,
  panel.id = ~ lieu + date
)

lead_lag_joint_df <- extract_terms(ll_joint_model, ll_terms) |>
  mutate(relative_day = seq(-window, window))

ll_ar_model <- feols(
  as.formula(paste(
    "log_entrees ~",
    paste(ll_terms, collapse = " + "),
    "+ log_entrees_lag1 | lieu + date + lieu^year_month + lieu^dow"
  )),
  data = df_ll |> filter(!is.na(log_entrees_lag1)),
  panel.id = ~ lieu + date
)

lead_lag_ar_df <- extract_terms(ll_ar_model, ll_terms) |>
  mutate(relative_day = seq(-window, window))

lead_lag_ar_ct <- fixest::coeftable(ll_ar_model, vcov = dk_vcov)
lead_lag_ar_crit <- stats::qnorm(1 - 0.05 / (2 * length(ll_terms)))
lead_lag_ar_df <- data.frame(
  term = ll_terms,
  estimate = lead_lag_ar_ct[ll_terms, 1],
  std_error = lead_lag_ar_ct[ll_terms, 2],
  conf_low_pointwise = lead_lag_ar_ct[ll_terms, 1] - stats::qnorm(0.975) * lead_lag_ar_ct[ll_terms, 2],
  conf_high_pointwise = lead_lag_ar_ct[ll_terms, 1] + stats::qnorm(0.975) * lead_lag_ar_ct[ll_terms, 2],
  conf_low = lead_lag_ar_ct[ll_terms, 1] - lead_lag_ar_crit * lead_lag_ar_ct[ll_terms, 2],
  conf_high = lead_lag_ar_ct[ll_terms, 1] + lead_lag_ar_crit * lead_lag_ar_ct[ll_terms, 2],
  relative_day = seq(-window, window),
  ci_type = "Bonferroni simultaneous 95% CI, DK(30)"
)

lead_lag_placebo_df <- bind_rows(lapply(seq(-window, window), function(k) {
  if (k == 0) {
    ct <- fixest::coeftable(m_log_mobile, vcov = dk_vcov)
    ci <- suppressWarnings(confint(m_log_mobile, vcov = dk_vcov))
    data.frame(
      term = "log_mobile",
      estimate = ct["log_mobile", 1],
      std_error = ct["log_mobile", 2],
      conf_low = ci["log_mobile", 1],
      conf_high = ci["log_mobile", 2],
      relative_day = 0,
      specification = "Main same-day coefficient"
    )
  } else {
    term <- lead_lag_name("log_mobile", k)
    model_df <- df_ll |>
      filter(!is.na(.data[[term]]))
    model <- feols(
      as.formula(paste("log_entrees ~ log_mobile +", term, "| lieu + date")),
      data = model_df,
      panel.id = ~ lieu + date
    )
    ct <- fixest::coeftable(model, vcov = dk_vcov)
    ci <- suppressWarnings(confint(model, vcov = dk_vcov))
    data.frame(
      term = term,
      estimate = ct[term, 1],
      std_error = ct[term, 2],
      conf_low = ci[term, 1],
      conf_high = ci[term, 2],
      relative_day = k,
      specification = "Lead/lag placebo conditional on day 0"
    )
  }
}))

holdout_dates <- sort(unique(df$date))
holdout_start <- holdout_dates[max(1, length(holdout_dates) - 180 + 1)]
train_df <- df |> filter(date < holdout_start)
test_df <- df |> filter(date >= holdout_start)
holdout_models <- fit_nowcast_models_log(train_df)
holdout_predictions <- predict_log_models(holdout_models, test_df)
holdout_scores <- score_nowcast_log(test_df, holdout_predictions) |>
  mutate(test_start = format(holdout_start, "%Y-%m-%d"))

monthly_nowcast <- run_monthly_nowcast_log(df, n_test_months = 6)
monthly_winners <- monthly_nowcast$detail |>
  group_by(test_month) |>
  slice_min(order_by = rmse_entries, n = 1, with_ties = FALSE) |>
  ungroup() |>
  count(model, name = "months_won") |>
  arrange(desc(months_won))

regression_table <- data.frame(
  model = c(
    "Log mobile only",
    "Log mobile + log desktop"
  ),
  log_mobile = c(
    format_term(m_log_mobile, "log_mobile"),
    format_term(m_log_mobile_desktop, "log_mobile")
  ),
  log_desktop = c(
    "",
    format_term(m_log_mobile_desktop, "log_desktop")
  ),
  fixed_effects = c("Place + date", "Place + date"),
  r2 = c(fmt_num(fit_value(m_log_mobile, "r2")), fmt_num(fit_value(m_log_mobile_desktop, "r2"))),
  within_r2 = c(fmt_num(fit_value(m_log_mobile, "wr2")), fmt_num(fit_value(m_log_mobile_desktop, "wr2"))),
  observations = c(nobs(m_log_mobile), nobs(m_log_mobile_desktop))
)

robust_table <- data.frame(
  model = c(
    "Place trends + exact date FE",
    "Positive-attendance days only",
    "Calendar controls + city pageviews",
    "Winsorized mobile pageviews"
  ),
  log_mobile = c(
    format_term(m_log_trends, "log_mobile"),
    format_term(m_log_positive, "log_mobile"),
    format_term(m_log_city, "log_mobile"),
    format_term(m_log_winsor, "log_mobile_winsor")
  ),
  log_desktop = c(
    format_term(m_log_trends, "log_desktop"),
    format_term(m_log_positive, "log_desktop"),
    format_term(m_log_city, "log_desktop"),
    format_term(m_log_winsor, "log_desktop")
  ),
  log_city_mobile = c("", "", format_term(m_log_city, "log_city_mobile"), ""),
  log_city_desktop = c("", "", format_term(m_log_city, "log_city_desktop"), ""),
  r2 = c(
    fmt_num(fit_value(m_log_trends, "r2")),
    fmt_num(fit_value(m_log_positive, "r2")),
    fmt_num(fit_value(m_log_city, "r2")),
    fmt_num(fit_value(m_log_winsor, "r2"))
  ),
  within_r2 = c(
    fmt_num(fit_value(m_log_trends, "wr2")),
    fmt_num(fit_value(m_log_positive, "wr2")),
    fmt_num(fit_value(m_log_city, "wr2")),
    fmt_num(fit_value(m_log_winsor, "wr2"))
  ),
  observations = c(nobs(m_log_trends), nobs(m_log_positive), nobs(m_log_city), nobs(m_log_winsor))
)

timing_table <- data.frame(
  model = c("Same-day log mobile", "Lagged log mobile (t-1)", "Lead log mobile (t+1)", "Joint timing model"),
  same_day_log_mobile = c(format_term(m_log_mobile, "log_mobile"), "", "", format_term(m_log_timing, "log_mobile")),
  lagged_log_mobile = c("", format_term(m_log_lag, "log_mobile_lag1"), "", format_term(m_log_timing, "log_mobile_lag1")),
  lead_log_mobile = c("", "", format_term(m_log_lead, "log_mobile_lead1"), format_term(m_log_timing, "log_mobile_lead1")),
  r2 = c(
    fmt_num(fit_value(m_log_mobile, "r2")),
    fmt_num(fit_value(m_log_lag, "r2")),
    fmt_num(fit_value(m_log_lead, "r2")),
    fmt_num(fit_value(m_log_timing, "r2"))
  ),
  within_r2 = c(
    fmt_num(fit_value(m_log_mobile, "wr2")),
    fmt_num(fit_value(m_log_lag, "wr2")),
    fmt_num(fit_value(m_log_lead, "wr2")),
    fmt_num(fit_value(m_log_timing, "wr2"))
  ),
  observations = c(nobs(m_log_mobile), nobs(m_log_lag), nobs(m_log_lead), nobs(m_log_timing))
)

autocorr_table <- data.frame(
  model = c(
    "Same-day log mobile",
    "Joint t-1/t/t+1 timing",
    "AR controls: lagged attendance + 7 mobile lags",
    "Mobile innovation: residual from 7 mobile lags"
  ),
  coefficient = c(
    format_term(m_log_mobile, "log_mobile"),
    format_term(m_log_timing, "log_mobile"),
    format_term(m_log_ar_controls, "log_mobile"),
    format_term(m_log_mobile_innovation, "log_mobile_innovation")
  ),
  interpretation = c(
    "Same-day association",
    "Same-day association net of adjacent mobile days",
    "Same-day association net of lagged attendance and previous-week mobile traffic",
    "Association with unpredictable same-day mobile attention"
  ),
  r2 = c(
    fmt_num(fit_value(m_log_mobile, "r2")),
    fmt_num(fit_value(m_log_timing, "r2")),
    fmt_num(fit_value(m_log_ar_controls, "r2")),
    fmt_num(fit_value(m_log_mobile_innovation, "r2"))
  ),
  within_r2 = c(
    fmt_num(fit_value(m_log_mobile, "wr2")),
    fmt_num(fit_value(m_log_timing, "wr2")),
    fmt_num(fit_value(m_log_ar_controls, "wr2")),
    fmt_num(fit_value(m_log_mobile_innovation, "wr2"))
  ),
  observations = c(
    nobs(m_log_mobile),
    nobs(m_log_timing),
    nobs(m_log_ar_controls),
    nobs(m_log_mobile_innovation)
  )
)

observed_coef <- coef(m_log_mobile)[["log_mobile"]]
placebo_table <- data.frame(
  test = c(
    "Observed same-day log coefficient",
    "Within-date shuffle mean",
    "Within-date shuffle SD",
    "Within-date shuffle 95th percentile",
    "Share of shuffled coefficients >= observed",
    "Rotated-site placebo coefficient",
    "Rotated-site / observed coefficient"
  ),
  value = c(
    fmt_num(observed_coef, 4),
    fmt_num(mean(placebo_shuffle), 4),
    fmt_num(stats::sd(placebo_shuffle), 4),
    fmt_num(stats::quantile(placebo_shuffle, 0.95), 4),
    fmt_pct(mean(placebo_shuffle >= observed_coef), 1),
    format_term(m_log_rotated, "log_mobile_rotated"),
    fmt_num(coef(m_log_rotated)[["log_mobile_rotated"]] / observed_coef, 3)
  )
)

lead_lag_local <- lead_lag_ar_df |>
  filter(relative_day >= -5, relative_day <= 5) |>
  transmute(
    relative_day,
    estimate = fmt_num(estimate, 4),
    std_error = fmt_num(std_error, 4),
    ci_low = fmt_num(conf_low, 4),
    ci_high = fmt_num(conf_high, 4)
  )

preferred_timing_table <- data.frame(
  model = "Preferred DK lead-lag timing",
  same_day_log_mobile = paste0(
    fmt_num(lead_lag_ar_ct["log_mobile_0", 1], 4),
    stars(lead_lag_ar_ct["log_mobile_0", 4]),
    " (",
    fmt_num(lead_lag_ar_ct["log_mobile_0", 2], 4),
    ")"
  ),
  simultaneous_ci_95 = paste0(
    "[",
    fmt_num(lead_lag_ar_df$conf_low[lead_lag_ar_df$relative_day == 0], 4),
    ", ",
    fmt_num(lead_lag_ar_df$conf_high[lead_lag_ar_df$relative_day == 0], 4),
    "]"
  ),
  r2 = fmt_num(fit_value(ll_ar_model, "r2")),
  within_r2 = fmt_num(fit_value(ll_ar_model, "wr2")),
  observations = nobs(ll_ar_model)
)

out_dir <- file.path(project_root, "outputs", "results")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

twfe_main_table <- data.frame(
  model = c(
    "Mobile only",
    "Desktop only",
    "Mobile + Desktop",
    "Lead-lag full spec (day 0)"
  ),
  log_mobile = c(
    format_term(m_full_mobile, "log_mobile"),
    "",
    format_term(m_full_mobile_desktop, "log_mobile"),
    format_term(ll_ar_model, "log_mobile_0")
  ),
  log_desktop = c(
    "",
    format_term(m_full_desktop, "log_desktop"),
    format_term(m_full_mobile_desktop, "log_desktop"),
    ""
  ),
  log_entrees_lag1 = c(
    format_term(m_full_mobile, "log_entrees_lag1"),
    format_term(m_full_desktop, "log_entrees_lag1"),
    format_term(m_full_mobile_desktop, "log_entrees_lag1"),
    format_term(ll_ar_model, "log_entrees_lag1")
  ),
  r2 = c(
    fmt_num(fit_value(m_full_mobile, "r2")),
    fmt_num(fit_value(m_full_desktop, "r2")),
    fmt_num(fit_value(m_full_mobile_desktop, "r2")),
    fmt_num(fit_value(ll_ar_model, "r2"))
  ),
  within_r2 = c(
    fmt_num(fit_value(m_full_mobile, "wr2")),
    fmt_num(fit_value(m_full_desktop, "wr2")),
    fmt_num(fit_value(m_full_mobile_desktop, "wr2")),
    fmt_num(fit_value(ll_ar_model, "wr2"))
  ),
  observations = c(
    nobs(m_full_mobile),
    nobs(m_full_desktop),
    nobs(m_full_mobile_desktop),
    nobs(ll_ar_model)
  )
)

results <- list(
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  inputs = list(
    merged_file = paths$merged_path,
    wiki_file = paths$wiki_path
  ),
  sample = list(
    start = format(sample_start, "%Y-%m-%d"),
    end = format(sample_end, "%Y-%m-%d"),
    observations = n_obs,
    places = n_places,
    dates = n_dates,
    zero_share = zero_share,
    mean_attendance = mean(df$nombre_entrees),
    mean_mobile = mean(df$pv_user_mobile),
    median_mobile = stats::median(df$pv_user_mobile)
  ),
  regression_table = regression_table,
  twfe_main_table = twfe_main_table,
  robust_table = robust_table,
  timing_table = timing_table,
  autocorr_table = autocorr_table,
  preferred_timing_table = preferred_timing_table,
  placebo_table = placebo_table,
  lead_lag = list(
    peak_day = lead_lag_ar_df$relative_day[which.max(lead_lag_ar_df$estimate)],
    peak_coef = max(lead_lag_ar_df$estimate, na.rm = TRUE),
    day_minus_1 = lead_lag_ar_df$estimate[lead_lag_ar_df$relative_day == -1],
    day_0 = lead_lag_ar_df$estimate[lead_lag_ar_df$relative_day == 0],
    day_plus_1 = lead_lag_ar_df$estimate[lead_lag_ar_df$relative_day == 1],
    r2 = fit_value(ll_ar_model, "r2"),
    within_r2 = fit_value(ll_ar_model, "wr2"),
    observations = nobs(ll_ar_model),
    local = lead_lag_local,
    ar_peak_day = lead_lag_ar_df$relative_day[which.max(lead_lag_ar_df$estimate)],
    ar_peak_coef = max(lead_lag_ar_df$estimate, na.rm = TRUE),
    ar_day_minus_1 = lead_lag_ar_df$estimate[lead_lag_ar_df$relative_day == -1],
    ar_day_0 = lead_lag_ar_df$estimate[lead_lag_ar_df$relative_day == 0],
    ar_day_plus_1 = lead_lag_ar_df$estimate[lead_lag_ar_df$relative_day == 1],
    placebo_peak_day = lead_lag_placebo_df$relative_day[which.max(lead_lag_placebo_df$estimate)],
    placebo_peak_coef = max(lead_lag_placebo_df$estimate, na.rm = TRUE),
    placebo_day_minus_1 = lead_lag_placebo_df$estimate[lead_lag_placebo_df$relative_day == -1],
    placebo_day_0 = lead_lag_placebo_df$estimate[lead_lag_placebo_df$relative_day == 0],
    placebo_day_plus_1 = lead_lag_placebo_df$estimate[lead_lag_placebo_df$relative_day == 1],
    separate_peak_day = lead_lag_df$relative_day[which.max(lead_lag_df$estimate)],
    separate_peak_coef = max(lead_lag_df$estimate, na.rm = TRUE),
    separate_day_minus_1 = lead_lag_df$estimate[lead_lag_df$relative_day == -1],
    separate_day_0 = lead_lag_df$estimate[lead_lag_df$relative_day == 0],
    separate_day_plus_1 = lead_lag_df$estimate[lead_lag_df$relative_day == 1],
    joint_peak_day = lead_lag_joint_df$relative_day[which.max(lead_lag_joint_df$estimate)],
    joint_peak_coef = max(lead_lag_joint_df$estimate, na.rm = TRUE),
    joint_day_minus_1 = lead_lag_joint_df$estimate[lead_lag_joint_df$relative_day == -1],
    joint_day_0 = lead_lag_joint_df$estimate[lead_lag_joint_df$relative_day == 0],
    joint_day_plus_1 = lead_lag_joint_df$estimate[lead_lag_joint_df$relative_day == 1]
  ),
  holdout = list(
    start = format(holdout_start, "%Y-%m-%d"),
    scores = holdout_scores
  ),
  rolling = list(
    summary = monthly_nowcast$summary,
    winners = monthly_winners
  )
)

jsonlite::write_json(
  results,
  path = file.path(out_dir, "loglog_analysis_results.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null"
)

cat("Wrote log-log-only analysis exports in outputs/results/.\n")
