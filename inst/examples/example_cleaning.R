# example_cleaning.R
# ---------------------------------------------------------------------------
# A self-contained example of the manifest workflow. Run it with:
#
#   script <- system.file("examples", "example_cleaning.R", package = "manifest")
#   source(script)
#
# Because it is run via source(), begin_manifest() auto-detects this file's
# path and end_manifest() can back-fill the CRITERIA / CODE columns from the
# `#:` comments below. The timestamped CSV is written under tempdir().
#
# Comment key:
#   #:   Manifest criteria  - appears in the CRITERIA column of the manifest
#   ##   Dev / internal note - ignored by manifest
#   #    Ordinary comment    - ignored by manifest
# ---------------------------------------------------------------------------

library(dplyr)
library(manifest)

## -- Simulate a raw dataset ---------------------------------------------------
set.seed(42)
d <- data.frame(
  id    = 1:1000,
  x     = rnorm(1000, mean = 8, sd = 3),
  state = sample(c("MN", "SD", "ND", "WI", "IA"), 1000, replace = TRUE),
  year  = sample(2018:2023, 1000, replace = TRUE),
  score = rnorm(1000, 50, 15)
)

## -- Open the manifest --------------------------------------------------------
begin_manifest(
  data         = d,
  description  = "Simulated dataset created to demonstrate package functionality",
  build_script = "compile_data.R",
  output_dir   = file.path(tempdir(), "manifest"),
  dataset_name = "package_demo_data",
  verbose      = TRUE
)

## QA note: x values were validated against source registry on 2024-01-15
#: {name} Drop outliers in X
#: Omit records where X statistic exceeds 10 (outliers per pre-reg criteria)
d <- mfilter(d, x <= 10)

## We originally considered all 5 states; ND/WI/IA dropped for sample size
#: {name} Study geography
#: Restrict study to Minnesota and South Dakota (primary catchment states)
d <- mfilter(d, state %in% c("MN", "SD"))

#: {name} Study time period
#: Limit to study period 2020-2022
d <- mfilter(d, year >= 2020, year <= 2022)

## Score < 0 is a data entry artifact; confirmed with PI on 2024-02-03
#: Remove records with invalid scores (score < 0 indicates data entry error)
d <- mfilter(d, score >= 0)

## -- Close the manifest, write the CSV, print the summary ---------------------
end_manifest(d)
