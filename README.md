# manifest

<!-- badges: start -->
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
<!-- badges: end -->

Create a data manifest to record and report the filters applied to a research
database during the pre-modeling phase.

Before a dataset reaches a model it is *sampled* — outliers trimmed, a geography
or time window chosen, invalid records removed. **manifest** produces a
lightweight audit trail of that stage: bracket your filtering code with
`begin_manifest()` and `end_manifest()`, and the package records, for every
row-reducing step, the rationale, the exact code, and how many rows were dropped
versus kept. The result prints as a table and is saved as a timestamped CSV that
travels with your project as documentation of the sampling framework.

## Installation

```r
# install.packages("remotes")
remotes::install_github("Nonprofit-Open-Data-Collective/manifest")
```

## Comment conventions

manifest reads your script and treats comments by prefix:

| Prefix | Meaning             | Captured? |
|:-------|:--------------------|:----------|
| `#:`   | Manifest criteria   | **Yes** — becomes the `CRITERIA` text |
| `#: {name} ...` | Step label | **Yes** — becomes the `STEP` label |
| `##`   | Dev / internal note | No |
| `#`    | Ordinary comment    | No |

## Example

```r
library(dplyr)
library(manifest)

begin_manifest(
  data         = d,
  description  = "Simulated dataset created to demonstrate package functionality",
  build_script = "compile_data.R",
  dataset_name = "package_demo_data"
)

#: {name} Drop outliers in X
#: Omit records where X statistic exceeds 10 (outliers per pre-reg criteria)
d <- mfilter(d, x <= 10)

#: {name} Study geography
#: Restrict study to Minnesota and South Dakota (primary catchment states)
d <- mfilter(d, state %in% c("MN", "SD"))

#: {name} Study time period
#: Limit to study period 2020-2022
d <- mfilter(d, year >= 2020, year <= 2022)

end_manifest(d)
```

Produces a manifest like:

```
                   STEP DROPPED DROPPED_PCT REMAIN REMAIN_PCT
                  START      NA               1000       100%
 (1) Drop outliers in X     250       25.0%    750      75.0%
    (2) Study geography     441       44.1%    309      30.9%
  (3) Study time period     143       14.3%    166      16.6%
```

...together with `CRITERIA` and `CODE` columns and a saved CSV.

A complete, runnable version ships with the package:

```r
source(system.file("examples", "example_cleaning.R", package = "manifest"))
```

## Learn more

See the [**Getting started** vignette](https://nonprofit-open-data-collective.github.io/manifest/articles/manifest.html)
for a full walk-through, including how to log steps that aren't simple filters
(joins, de-duplication) with `log_step()`.
