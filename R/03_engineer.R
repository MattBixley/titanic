# 03_engineer.R --------------------------------------------------------------
# Feature engineering that CANNOT live in a parsnip recipe because it needs
# cross-row information (ticket/family group sizes) or the outcome itself
# (group survival). We compute these for train AND test up front and write
# data/processed/{train,test}.csv. Every model document then reads the processed
# data and the recipe (make_recipe) only does per-row steps (impute, dummy,
# normalise, PCA). This keeps the "fitted workflow predicts on raw-ish test"
# pattern intact, because the engineered columns are already present in test.
#
# Leakage control: group-survival on TRAIN is computed leave-one-out (a
# passenger's own outcome never feeds their own feature). TEST rows use the full
# train group rate (test outcomes are unknown anyway). Unknown groups fall back
# to the global training survival rate.
#
# Run standalone:  Rscript R/03_engineer.R   (also used as a Quarto pre-render)

suppressMessages({
  library(tidyverse)
  library(here)
})

extract_title <- function(name) {
  t <- str_extract(name, "(?<=, )[A-Za-z]+(?=\\.)")
  t <- if_else(is.na(t), "Rare", t)
  # Collapse to the well-known survival-relevant buckets.
  dplyr::case_when(
    t %in% c("Mr")                              ~ "Mr",
    t %in% c("Mrs", "Mme")                      ~ "Mrs",
    t %in% c("Miss", "Mlle", "Ms")              ~ "Miss",
    t %in% c("Master")                          ~ "Master",   # boys -> high survival
    t %in% c("Dr", "Rev", "Col", "Major", "Capt") ~ "Officer",
    t %in% c("Lady", "Countess", "Sir", "Don", "Dona", "Jonkheer") ~ "Royalty",
    TRUE                                        ~ "Rare"
  )
}

extract_surname <- function(name) str_trim(str_extract(name, "^[^,]+"))

add_basic <- function(df) {
  df |>
    mutate(
      Title       = extract_title(Name),
      Surname     = extract_surname(Name),
      FamilySize  = SibSp + Parch + 1L,
      IsAlone     = if_else(FamilySize == 1L, "yes", "no"),
      Deck        = str_sub(Cabin, 1, 1),
      Deck        = if_else(is.na(Deck) | Deck == "", "Unknown", Deck),
      HasCabin    = if_else(is.na(Cabin) | Cabin == "", "no", "yes"),
      HasAge      = if_else(is.na(Age), "no", "yes"),
      IsChild     = if_else(!is.na(Age) & Age < 16, "yes", "no")
    )
}

engineer <- function() {
  train <- readr::read_csv(here("data", "raw", "train.csv"), show_col_types = FALSE)
  test  <- readr::read_csv(here("data", "raw", "test.csv"),  show_col_types = FALSE)

  train <- add_basic(train)
  test  <- add_basic(test)

  # --- Group sizes from the FULL train+test union (no outcome involved) -------
  all_rows <- bind_rows(
    train |> select(PassengerId, Ticket, Fare),
    test  |> select(PassengerId, Ticket, Fare)
  )
  tkt_size <- all_rows |> count(Ticket, name = "TicketGroupSize")

  attach_group_size <- function(df) {
    df |>
      left_join(tkt_size, by = "Ticket") |>
      mutate(
        TicketGroupSize = replace_na(TicketGroupSize, 1L),
        FarePerPerson   = Fare / TicketGroupSize
      )
  }
  train <- attach_group_size(train)
  test  <- attach_group_size(test)

  # --- Group survival (uses the OUTCOME -> train only, leave-one-out) ---------
  global_rate <- mean(train$Survived)

  # Per-group running totals on train (count + sum of Survived).
  tkt_stats  <- train |> group_by(Ticket)  |> summarise(n = n(), s = sum(Survived), .groups = "drop")
  fam_stats  <- train |> group_by(Surname) |> summarise(n = n(), s = sum(Survived), .groups = "drop")

  # TRAIN: leave-one-out group rate (exclude the row's own outcome).
  train <- train |>
    left_join(tkt_stats,  by = "Ticket",  suffix = c("", ".tkt")) |>
    left_join(fam_stats,  by = "Surname", suffix = c("", ".fam")) |>
    mutate(
      tkt_loo = if_else(n   > 1, (s   - Survived) / (n   - 1), NA_real_),
      fam_loo = if_else(n.fam > 1, (s.fam - Survived) / (n.fam - 1), NA_real_),
      GroupSurvival = coalesce(tkt_loo, fam_loo, global_rate),
      GroupKnown    = if_else(!is.na(tkt_loo) | !is.na(fam_loo), "yes", "no")
    ) |>
    select(-n, -s, -n.fam, -s.fam, -tkt_loo, -fam_loo)

  # TEST: full train group rate (test outcomes unknown), then surname, then global.
  test <- test |>
    left_join(tkt_stats |> transmute(Ticket,  tkt_rate = s / n),  by = "Ticket") |>
    left_join(fam_stats |> transmute(Surname, fam_rate = s / n),  by = "Surname") |>
    mutate(
      GroupSurvival = coalesce(tkt_rate, fam_rate, global_rate),
      GroupKnown    = if_else(!is.na(tkt_rate) | !is.na(fam_rate), "yes", "no")
    ) |>
    select(-tkt_rate, -fam_rate)

  dir.create(here("data", "processed"), showWarnings = FALSE, recursive = TRUE)
  readr::write_csv(train, here("data", "processed", "train.csv"))
  readr::write_csv(test,  here("data", "processed", "test.csv"))
  message("Wrote processed data: ", nrow(train), " train / ", nrow(test), " test rows, ",
          ncol(train), " train cols.")
  invisible(list(train = train, test = test))
}

# Run when sourced/executed.
engineer()
