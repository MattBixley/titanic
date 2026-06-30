# 01_eda.R ------------------------------------------------------------------
# Exploratory data analysis on the Titanic training/test sets.
# Runnable script version of the EDA; the Quarto doc mirrors this.
# Reads from data/raw/, writes plots to figures/.

source(here::here("R", "00_setup.R"))

# Read data (tolerant of missing files) --------------------------------------
train_path <- file.path(path_data_raw, "train.csv")
test_path  <- file.path(path_data_raw, "test.csv")

if (!file.exists(train_path)) {
  message(
    "train.csv not found at ", train_path, ".\n",
    "Download the Kaggle Titanic data into data/raw/ before running EDA."
  )
  # Stop here gracefully when sourced interactively without data present.
  if (!interactive()) quit(save = "no", status = 0)
} else {
  train <- readr::read_csv(train_path, show_col_types = FALSE)
  test  <- if (file.exists(test_path)) {
    readr::read_csv(test_path, show_col_types = FALSE)
  } else {
    message("test.csv not found at ", test_path, " (continuing with train only).")
    NULL
  }

  # Quick structural overview ------------------------------------------------
  glimpse(train)
  if (requireNamespace("skimr", quietly = TRUE)) {
    print(skimr::skim(train))
  } else {
    print(summary(train))
  }

  # EDA plots ----------------------------------------------------------------
  # Treat the outcome and key categoricals as factors for plotting.
  train_plot <- train %>%
    mutate(
      Survived = factor(Survived, levels = c(0, 1), labels = c("Died", "Survived")),
      Pclass   = factor(Pclass),
      Sex      = factor(Sex)
    )

  # 1. Survival by Sex
  p_sex <- ggplot(train_plot, aes(x = Sex, fill = Survived)) +
    geom_bar(position = "fill") +
    scale_y_continuous(labels = scales::percent) +
    labs(title = "Survival rate by Sex", x = "Sex", y = "Proportion", fill = NULL) +
    theme_minimal()

  # 2. Survival by Pclass
  p_pclass <- ggplot(train_plot, aes(x = Pclass, fill = Survived)) +
    geom_bar(position = "fill") +
    scale_y_continuous(labels = scales::percent) +
    labs(title = "Survival rate by Passenger Class", x = "Pclass",
         y = "Proportion", fill = NULL) +
    theme_minimal()

  # 3. Age distribution by survival
  p_age <- ggplot(train_plot, aes(x = Age, fill = Survived)) +
    geom_histogram(binwidth = 5, position = "identity", alpha = 0.6,
                   na.rm = TRUE) +
    labs(title = "Age distribution by survival", x = "Age", y = "Count",
         fill = NULL) +
    theme_minimal()

  # 4. Fare distribution by survival (log scale; fares are right-skewed)
  p_fare <- ggplot(train_plot, aes(x = Survived, y = Fare, fill = Survived)) +
    geom_boxplot(na.rm = TRUE, show.legend = FALSE) +
    scale_y_log10() +
    labs(title = "Fare by survival (log scale)", x = NULL, y = "Fare (log10)") +
    theme_minimal()

  # Save plots ---------------------------------------------------------------
  ggsave(file.path(path_figures, "eda_survival_by_sex.png"),    p_sex,    width = 6, height = 4, dpi = 150)
  ggsave(file.path(path_figures, "eda_survival_by_pclass.png"), p_pclass, width = 6, height = 4, dpi = 150)
  ggsave(file.path(path_figures, "eda_age_distribution.png"),   p_age,    width = 6, height = 4, dpi = 150)
  ggsave(file.path(path_figures, "eda_fare_by_survival.png"),   p_fare,   width = 6, height = 4, dpi = 150)

  message("EDA plots written to ", path_figures)
}
