library(ggplot2)

if (!exists("lead_lag_ar_df") || !exists("monthly_nowcast") || !exists("project_root")) {
  source(file.path("analysis", "run_loglog_only_analysis.R"))
}

fig_dir <- file.path(project_root, "outputs", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

paper_theme <- theme_classic(base_size = 11) +
  theme(
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    legend.title = element_blank(),
    legend.position = "bottom",
    axis.title = element_text(color = "black"),
    axis.text = element_text(color = "black")
  )

lead_lag_paper_theme <- theme_minimal(base_size = 11) +
  theme(
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    legend.position = "none",
    panel.grid.major = element_line(color = "grey88", linewidth = 0.35),
    panel.grid.minor = element_line(color = "grey93", linewidth = 0.25),
    axis.title = element_text(color = "black"),
    axis.text = element_text(color = "black"),
    axis.line = element_blank(),
    panel.border = element_blank(),
    plot.margin = margin(5.5, 8, 5.5, 5.5)
  )

save_paper_figure <- function(plot, basename, width = 6.5, height = 4.0) {
  ggsave(
    filename = file.path(fig_dir, paste0(basename, ".png")),
    plot = plot,
    width = width,
    height = height,
    dpi = 600,
    bg = "white"
  )
  ggsave(
    filename = file.path(fig_dir, paste0(basename, ".pdf")),
    plot = plot,
    width = width,
    height = height,
    device = grDevices::pdf
  )
}

lead_lag_plot <- ggplot(lead_lag_ar_df, aes(x = relative_day, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_ribbon(aes(ymin = conf_low, ymax = conf_high), fill = "#9bd2b5", alpha = 0.28) +
  geom_vline(xintercept = 0, color = "#b22222", linetype = "dashed", linewidth = 0.45) +
  geom_line(color = "#173f2f", linewidth = 0.55) +
  geom_point(color = "#173f2f", size = 1.25) +
  scale_x_continuous(breaks = seq(-30, 30, by = 5), minor_breaks = seq(-30, 30, by = 2.5)) +
  scale_y_continuous(minor_breaks = waiver()) +
  labs(
    x = "Relative day of site mobile pageviews",
    y = "Coefficient on log site mobile pageviews"
  ) +
  lead_lag_paper_theme

lead_lag_joint_plot <- ggplot(lead_lag_joint_df, aes(x = relative_day, y = estimate)) +
  geom_ribbon(aes(ymin = conf_low, ymax = conf_high), fill = "#9bd2b5", alpha = 0.28) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.35) +
  geom_vline(xintercept = 0, color = "#b22222", linetype = "dashed", linewidth = 0.45) +
  geom_line(color = "#173f2f", linewidth = 0.55) +
  geom_point(color = "#173f2f", size = 1.25) +
  scale_x_continuous(breaks = seq(-30, 30, by = 5), minor_breaks = seq(-30, 30, by = 2.5)) +
  scale_y_continuous(minor_breaks = waiver()) +
  labs(
    x = "Relative day of log mobile pageviews",
    y = "Conditional coefficient on log mobile pageviews"
  ) +
  lead_lag_paper_theme

lead_lag_combined_df <- rbind(
  transform(lead_lag_df, specification = "Separate regressions"),
  transform(lead_lag_joint_df, specification = "Joint distributed model")
)

lead_lag_combined_plot <- ggplot(
  lead_lag_combined_df,
  aes(x = relative_day, y = estimate, linetype = specification)
) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_line(color = "black", linewidth = 0.7) +
  geom_point(color = "black", size = 1.0) +
  geom_vline(xintercept = 0, color = "black", linetype = "dashed", linewidth = 0.5) +
  scale_x_continuous(breaks = seq(-30, 30, by = 10)) +
  labs(
    x = "Relative day of log mobile pageviews",
    y = "Coefficient on log mobile pageviews"
  ) +
  paper_theme

placebo_plot <- ggplot(data.frame(coefficient = placebo_shuffle), aes(x = coefficient)) +
  geom_histogram(bins = 30, fill = "grey75", color = "white", linewidth = 0.2) +
  geom_vline(xintercept = observed_coef, color = "black", linewidth = 0.7) +
  labs(
    x = "Placebo coefficient on shuffled log mobile pageviews",
    y = "Count"
  ) +
  paper_theme

rolling_plot <- ggplot(
  monthly_nowcast$detail,
  aes(x = test_month, y = rmse_entries, color = model, group = model)
) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.8) +
  scale_color_grey(start = 0.1, end = 0.65) +
  labs(
    x = "Test month",
    y = "RMSE, attendance scale"
  ) +
  paper_theme +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

coef_plot_df <- data.frame(
  term = c("Log mobile", "Log desktop"),
  estimate = c(
    fixest::coeftable(m_log_mobile_desktop, vcov = dk_vcov)["log_mobile", 1],
    fixest::coeftable(m_log_mobile_desktop, vcov = dk_vcov)["log_desktop", 1]
  ),
  conf_low = c(
    confint(m_log_mobile_desktop, vcov = dk_vcov)["log_mobile", 1],
    confint(m_log_mobile_desktop, vcov = dk_vcov)["log_desktop", 1]
  ),
  conf_high = c(
    confint(m_log_mobile_desktop, vcov = dk_vcov)["log_mobile", 2],
    confint(m_log_mobile_desktop, vcov = dk_vcov)["log_desktop", 2]
  )
)

coef_plot <- ggplot(coef_plot_df, aes(x = estimate, y = reorder(term, estimate))) +
  geom_vline(xintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_errorbar(aes(xmin = conf_low, xmax = conf_high), width = 0.15, orientation = "y", color = "black") +
  geom_point(size = 2, color = "black") +
  labs(
    x = "Elasticity estimate",
    y = NULL
  ) +
  paper_theme

save_paper_figure(lead_lag_plot, "loglog_lead_lag_no_title")
save_paper_figure(lead_lag_plot, "loglog_lead_lag_autocorr_wide_no_title", width = 9.0, height = 3.3)
save_paper_figure(placebo_plot, "loglog_placebo_no_title")
save_paper_figure(rolling_plot, "loglog_rolling_rmse_no_title", width = 7.0, height = 4.2)
save_paper_figure(coef_plot, "loglog_coefficients_no_title", width = 5.5, height = 3.2)

cat("Exported log-log paper figures to ", fig_dir, "\n", sep = "")
