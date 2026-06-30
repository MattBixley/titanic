
## Quarto website (docs agent)
- `_quarto.yml` — website config; cosmo theme, navbar, output-dir _site, execute.freeze: auto. ~0.3k tok
- `index.qmd` — master doc: Kaggle intro, project tree, reproduce steps, results table placeholder, submission workflow. ~2k tok
- `docs/01-eda.qmd` — EDA: glimpse/skim, missingness, ggplot survival by sex/class/age/fare/family/title; motivates make_recipe(). ~3k tok
- `docs/02-xgboost.qmd` — boost_tree (xgboost), tune 4 params, 5-fold CV, vip, saves models/xgboost_fit.rds. ~1.8k tok
- `docs/03-random-forest.qmd` — rand_forest (ranger, permutation imp), tune mtry/min_n, saves models/rf_fit.rds. ~1.5k tok
- `docs/04-neural-net.qmd` — mlp (brulee; nnet fallback), step_normalize added, saves models/nnet_fit.rds. ~2k tok
- `docs/submission.qmd` — PARAMETERIZED (params$model: xgboost/rf/nnet); loads fit, predicts test, writes models/submission_<model>.csv. ~1.5k tok
