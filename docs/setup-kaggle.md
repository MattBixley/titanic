# Kaggle Setup Guide (Titanic)

This guide gets you from zero to submitting predictions on the Kaggle
[Titanic competition](https://www.kaggle.com/competitions/titanic) leaderboard.
Written for R / ggplot users who are new to Kaggle.

> **Note on data:** For offline development this project ships the Titanic CSVs
> from a public GitHub mirror in `data/raw/` (`train.csv`, `test.csv`). Those are
> identical to the official Kaggle files. The **authoritative** source is Kaggle
> itself — use the `kaggle` CLI download below once you are authenticated.

---

## 1. Create a Kaggle account and accept the rules

1. Sign up at <https://www.kaggle.com> (free; Google sign-in works).
2. Go to the competition page: <https://www.kaggle.com/competitions/titanic>.
3. Click **Join Competition** and accept the rules. **You must do this** — the
   API will refuse to download data or accept submissions until you have
   accepted the competition rules in the browser.

---

## 2. Generate your API token (`kaggle.json`)

1. Click your avatar (top right) → **Settings**.
2. Scroll to the **API** section → **Create New Token**.
3. Your browser downloads a file called `kaggle.json` (it contains your username
   and a secret key — treat it like a password, never commit it).
4. Move it into place and lock down the permissions:

   ```bash
   mkdir -p ~/.kaggle
   mv ~/Downloads/kaggle.json ~/.kaggle/
   chmod 600 ~/.kaggle/kaggle.json
   ```

The `chmod 600` step matters — the CLI warns (and on some systems refuses to run)
if the file is world-readable.

---

## 3. Verify the CLI

The `kaggle` CLI is installed for your user. If `kaggle` is not found, add the
user bin directory to your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"   # add to ~/.bashrc to make it permanent
kaggle --version
```

---

## 4. Download the data the "real" way

Once authenticated, pull the official competition files:

```bash
kaggle competitions download -c titanic -p data/raw
unzip data/raw/titanic.zip -d data/raw
```

This gives you `data/raw/train.csv` (891 rows, includes `Survived`),
`data/raw/test.csv` (418 rows, no `Survived`), and `gender_submission.csv`
(a sample submission). These overwrite the mirror copies — that is fine, they
are the same data.

---

## 5. Submit predictions to the leaderboard

The Quarto submission document in this project generates one CSV per model into
`models/`, named `submission_<model>.csv` where `<model>` is one of
`xgboost`, `rf`, or `nnet`. Each file has exactly two columns —
`PassengerId,Survived` — one row per test passenger.

General form:

```bash
kaggle competitions submit -c titanic -f models/submission_<model>.csv -m "<message>"
```

Concrete examples (one per model):

```bash
# XGBoost
kaggle competitions submit -c titanic -f models/submission_xgboost.csv -m "xgboost baseline"

# Random forest
kaggle competitions submit -c titanic -f models/submission_rf.csv -m "ranger random forest, tuned mtry"

# Neural net
kaggle competitions submit -c titanic -f models/submission_nnet.csv -m "nnet single hidden layer"
```

The `-m` message is your own note — it shows up next to the score so you can
tell submissions apart. Kaggle allows a limited number of submissions per day
(currently 10 for Titanic), so submit deliberately.

---

## 6. Check your score and submission history

```bash
kaggle competitions submissions -c titanic
```

This lists every submission with its public leaderboard score and your message.
To see where you stand overall:

```bash
kaggle competitions leaderboard -c titanic --show
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `403 Forbidden` on download/submit | You have not accepted the competition rules — do step 1.3 in the browser. |
| `kaggle: command not found` | Add `~/.local/bin` to your `PATH` (step 3). |
| `Could not find kaggle.json` | It must live at `~/.kaggle/kaggle.json` (step 2). |
| Warning about insecure permissions | `chmod 600 ~/.kaggle/kaggle.json`. |
