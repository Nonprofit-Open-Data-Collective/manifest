# example_cleaning.R
# Demonstrates the manifest package comment conventions.
#
# Comment key:
#   #:   Manifest criteria  — appears in CRITERIA column of the manifest
#   ##   Dev/internal notes — ignored by manifest
#   #    Ordinary comment   — ignored by manifest

library( dplyr )
library( manifest )

## -- Simulate raw data --------------------------
set.seed(42)
d <- data.frame(
  id    = 1:1000,
  x     = rnorm(100, mean = 8, sd = 3),
  state = sample(c("MN","SD","ND","WI","IA"), 1000, replace = TRUE),
  year  = sample(2018:2023, 1000, replace = TRUE),
  score = rnorm(1000, 50, 15)
)


## -- start of the data manifest --------------------------

begin_manifest(
  data=d,
  description = "Simulated dataset created to demonstrate package functionality", 
  build_script = "compile_data.R", 
  current_script = "demo/example_cleaning.R", 
  output_dir = "manifest", 
  dataset_name = "package_demo_data", 
  verbose = TRUE ) 



## QA note: x values were validated against source registry on 2024-01-15
#: {name} Drop outliers in X
#: Omit records where X statistic exceeds 10 (outliers per pre-reg criteria)
d <- mfilter(d, x <= 10)


## We originally considered all 5 states; ND/WI/IA dropped for sample size
#: {name} Study geography
#: Restrict study to Minnesota and South Dakota (primary catchment states)
d <- mfilter(d, state %in% c("MN", "SD"))


#: Limit to study period 2020–2022
#: {name} Study time period
d <- mfilter(d, year >= 2020, year <= 2022)


## Score < 0 is a data entry artifact; confirmed with PI on 2024-02-03
#: Remove records with invalid scores (score < 0 indicates data entry error)
d <- mfilter(d, score >= 0)

end_manifest(d)



# ------ Data Manifest ------------------------------------------------------------------------------------------------------------------------------------
#
#                    STEP DROPPED DROPPED_PCT REMAIN REMAIN_PCT
#                   START      NA               1000       100%
#  (1) Drop outliers in X     250       25.0%    750      75.0%
#     (2) Study geography     441       44.1%    309      30.9%
#   (3) Study time period     143       14.3%    166      16.6%
#                     (4)       0        0.0%    166      16.6%
#                                                                     CRITERIA
#  description{Simulated dataset created to demonstrate package functionality}
#    Omit records where X statistic exceeds 10 (outliers per pre-reg criteria)
#     Restrict study to Minnesota and South Dakota (primary catchment states)
#                                              Limit to study period 2020–2022
#    Remove records with invalid scores (score < 0 indicates data entry error)
#                                         CODE
#                       source{compile_data.R}
#                     d <- mfilter(d, x <= 10)
#    d <- mfilter(d, state %in% c("MN", "SD"))
#  d <- mfilter(d, year >= 2020, year <= 2022)
#                 d <- mfilter(d, score >= 0)
# 
# ---  Saved --- manifest/package_demo_data_manifest_20260617_214720.csv

