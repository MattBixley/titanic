# 02_features.R -------------------------------------------------------------
# The tidymodels preprocessing recipe. Operates on the PROCESSED data produced
# by R/03_engineer.R (data/processed/{train,test}.csv), which already carries
# the cross-row / outcome-derived features (Title, FamilySize, Deck, IsChild,
# TicketGroupSize, FarePerPerson, GroupSurvival, ...). This recipe only does
# per-row steps: impute, encode, normalise, and append principal components.
#
# The recipe works for BOTH train (with Survived) and test (no Survived).

source(here::here("R", "00_setup.R"))

#' Build the Titanic preprocessing recipe.
#'
#' @param data A processed data frame (train or test).
#' @param num_comp Number of principal components to append. Defaults to
#'   `tune()` so the model documents can tune it; pass an integer for a fixed
#'   recipe (e.g. quick experiments).
#' @return An unprepped tidymodels recipe.
make_recipe <- function(data, num_comp = tune()) {

  has_outcome <- "Survived" %in% names(data)

  if (has_outcome) {
    data <- data %>%
      mutate(Survived = factor(Survived, levels = c("0", "1")))
  }

  rec <- if (has_outcome) {
    recipe(Survived ~ ., data = data)
  } else {
    recipe(~ ., data = data)
  }

  rec <- rec %>%
    # PassengerId is an identifier, not a predictor.
    update_role(PassengerId, new_role = "id") %>%

    # Drop the raw text / high-cardinality columns now that all features are
    # derived (engineered upstream in 03_engineer.R).
    step_rm(Name, Ticket, Cabin, Surname) %>%

    # --- Imputation ---------------------------------------------------------
    # Age: KNN from the other predictors. Fare / FarePerPerson: median (one
    # missing Fare in the test set). Embarked: mode.
    step_impute_knn(Age, neighbors = 5) %>%
    step_impute_median(Fare, FarePerPerson) %>%
    step_impute_mode(Embarked) %>%

    # --- Nominal handling ---------------------------------------------------
    step_mutate(Pclass = as.character(Pclass)) %>%
    # Lump very rare Title levels (Royalty/Rare) so dummies stay stable in CV.
    step_other(Title, threshold = 0.02, other = "Rare") %>%
    step_novel(all_nominal_predictors()) %>%
    step_dummy(all_nominal_predictors()) %>%

    # Remove zero-variance predictors created by dummying.
    step_zv(all_predictors()) %>%

    # --- Principal components -----------------------------------------------
    # Normalise then append the top `num_comp` PCs as EXTRA features
    # (keep_original_cols = TRUE). num_comp defaults to tune(); normalisation
    # also benefits the (non-scale-invariant) neural net.
    step_normalize(all_numeric_predictors()) %>%
    step_pca(all_numeric_predictors(),
             num_comp           = num_comp,
             keep_original_cols = TRUE,
             prefix             = "PC")

  rec
}

# Note: the positive/event class is "1" (survived). Use event_level = "second"
# in yardstick metrics, since "1" is the second level under levels c("0","1").
