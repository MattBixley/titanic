# 02_features.R -------------------------------------------------------------
# Feature engineering for the Titanic dataset, expressed as a tidymodels
# recipe. Define make_recipe(data) and source this file from modelling scripts.
#
# The recipe is written to work for BOTH the training set (with Survived) and
# the test set (no Survived column) — outcome-specific steps are guarded.

source(here::here("R", "00_setup.R"))

#' Build the Titanic preprocessing recipe.
#'
#' @param data A data frame (training or test). The recipe is specified from
#'   `data` so the formula/roles adapt to whichever columns are present.
#' @return An unprepped tidymodels recipe.
make_recipe <- function(data) {

  has_outcome <- "Survived" %in% names(data)

  # If Survived is present, ensure it is a factor with positive class "1"
  # LAST (yardstick treats the first level as the event by default, but we
  # set the event level explicitly downstream; levels c("0","1") keeps it
  # interpretable). Done before recipe() so the outcome type is correct.
  if (has_outcome) {
    data <- data %>%
      mutate(Survived = factor(Survived, levels = c("0", "1")))
  }

  # Formula: predict Survived from everything when present, else outcome-free
  # recipe used purely for transforming the test set.
  rec <- if (has_outcome) {
    recipe(Survived ~ ., data = data)
  } else {
    recipe(~ ., data = data)
  }

  rec <- rec %>%
    # PassengerId is an identifier, not a predictor: keep it but exclude from
    # modelling by giving it the "id" role.
    update_role(PassengerId, new_role = "id") %>%

    # --- Feature engineering ------------------------------------------------

    # Title extracted from Name, e.g. "Braund, Mr. Owen Harris" -> "Mr".
    step_mutate(
      Title = str_extract(Name, "(?<=, )[A-Za-z]+(?=\\.)"),
      Title = if_else(is.na(Title), "Unknown", Title)
    ) %>%
    # Lump rare titles (Dr, Rev, Major, Countess, ...) into "Other".
    step_other(Title, threshold = 0.01, other = "Other") %>%

    # Family-structure features from siblings/spouses + parents/children.
    step_mutate(
      FamilySize = SibSp + Parch + 1L,
      IsAlone    = if_else(FamilySize == 1L, "yes", "no")
    ) %>%

    # Deck = first letter of Cabin; missing cabins -> "Unknown".
    step_mutate(
      Deck = str_sub(Cabin, 1, 1),
      Deck = if_else(is.na(Deck) | Deck == "", "Unknown", Deck)
    ) %>%

    # Drop raw text/high-cardinality columns now that features are derived.
    # (Name and Ticket carry little extra signal once Title/family are built;
    # Cabin is captured by Deck.)
    step_rm(Name, Ticket, Cabin) %>%

    # --- Imputation ---------------------------------------------------------
    # Age: k-nearest-neighbour imputation from the other predictors (richer
    # than a flat median, robust to skew). KNN is used in preference to
    # step_impute_bag(), whose rpart/ipred backend segfaults on this R build.
    step_impute_knn(Age, neighbors = 5) %>%
    # Embarked: impute the mode (most-frequent category).
    step_impute_mode(Embarked) %>%
    # Fare: median impute (test set has one missing Fare).
    step_impute_median(Fare) %>%

    # --- Nominal handling ---------------------------------------------------
    # Treat the engineered/categorical columns as nominal.
    step_mutate(
      Pclass = as.character(Pclass)
    ) %>%
    # Guard against categories appearing only in new data (test set).
    step_novel(all_nominal_predictors()) %>%
    # One-hot / dummy encode all nominal predictors.
    step_dummy(all_nominal_predictors()) %>%

    # --- Cleanup ------------------------------------------------------------
    # Remove zero-variance predictors created by dummying.
    step_zv(all_predictors())

  rec
}

# Note: the positive/event class is "1" (survived). Set this when computing
# metrics, e.g. yardstick metrics with event_level = "second", since "1" is
# the second factor level under levels = c("0", "1").
