library( dplyr )
library( manifest )

## -- Simulate raw data --------------------------
set.seed(42)
d <- data.frame(
  id    = 1:100,
  x     = rnorm(100, mean = 8, sd = 4),
  state = sample(c("MN","SD","ND","WI","IA"), 100, replace = TRUE),
  year  = sample(2018:2023, 100, replace = TRUE),
  score = rnorm(100, 50, 15)
)



begin_manifest(
  data=d,
  description = "Simulated dataset created to demonstrate package functionality", 
  build_script = "compile_data.R", 
  current_script = "demo/example_cleaning.R", 
  output_dir = "manifest/demo", 
  dataset_name = "fakedata", 
  verbose = TRUE ) 
 

## QA note: x values were validated against source registry on 2024-01-15
#: Omit records where X statistic exceeds 10 (outliers per pre-reg criteria)
d <- mfilter(d, x <= 10)


## We originally considered all 5 states; ND/WI/IA dropped for sample size
#: Restrict study to Minnesota and South Dakota (primary catchment states)
d <- mfilter(d, state %in% c("MN", "SD"))


#: Limit to study period 2020–2022
d <- mfilter(d, year >= 2020, year <= 2022)


## Score < 0 is a data entry artifact; confirmed with PI on 2024-02-03
#: Remove records with invalid scores (score < 0 indicates data entry error)
d <- mfilter(d, score >= 0)

end_manifest(d)