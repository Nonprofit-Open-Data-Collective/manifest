#' manifest: Data Provenance Tracking for Research Databases
#'
#' Comment conventions:
#'   `#:`  Manifest criteria  --- captured as CRITERIA in the log
#'   `##`  Internal/dev notes --- ignored by manifest
#'   `#`   Ordinary comments  --- ignored by manifest
#'
#' @name manifest-package
NULL

.menv <- new.env(parent = emptyenv())

#' Begin tracking a data manifest
#' @param data           The data frame at the start of cleaning.
#' @param description    Human-readable description of the dataset. Stored in
#'                       the CRITERIA cell of the START row as
#'                       \code{description\{...\}}.
#' @param build_script   Path to the script that assembled the raw data
#'                       (may differ from the cleaning script). Stored in
#'                       the CODE cell of the START row as
#'                       \code{source\{...\}}.
#' @param current_script Path to the script currently being executed (this
#'                       file). Used to locate \code{#:} comments. Auto-detected
#'                       when run via \code{source()}; set explicitly otherwise.
#' @param output_dir     Directory for the saved CSV. Created if absent.
#' @param dataset_name   Label used in the output filename.
#' @param verbose        Print status messages?
#' @return Invisibly returns the initial row count.
#' @export
begin_manifest <- function(data,
                           description    = "",
                           build_script   = "",
                           current_script = NULL,
                           output_dir     = "manifest",
                           dataset_name   = "dataset",
                           verbose        = TRUE) {
  if (is.null(current_script)) current_script <- .detect_script_path()

  n0 <- nrow(data)
  .menv$script       <- current_script
  .menv$output_dir   <- output_dir
  .menv$dataset_name <- dataset_name
  .menv$verbose      <- verbose
  .menv$n_start      <- n0
  .menv$n_current    <- n0
  .menv$step         <- 0L
  .menv$log          <- .empty_log()
  .menv$begin_line   <- .detect_call_line("begin_manifest")

  # START row: embed description and build_script using tagged syntax
  start_criteria <- if (nchar(trimws(description))  > 0)
                      sprintf("description{%s}", trimws(description)) else ""
  start_code     <- if (nchar(trimws(build_script)) > 0)
                      sprintf("source{%s}",      trimws(build_script)) else ""

  .menv$log <- rbind(.menv$log, data.frame(
    STEP        = "START",
    DROPPED     = NA_integer_,
    DROPPED_PCT = "",
    REMAIN      = n0,
    REMAIN_PCT  = "100%",
    CRITERIA    = start_criteria,
    CODE        = start_code,
    stringsAsFactors = FALSE
  ))

  if (verbose) message(sprintf("[manifest] Started. Initial N = %s",
                               format(n0, big.mark = ",")))
  invisible(n0)
}

#' Filter rows and automatically log the step
#'
#' Drop-in replacement for dplyr::filter() that records the row delta.
#' Pair with a `#:` comment on the preceding line for automatic CRITERIA.
#'
#' @param data  A data frame.
#' @param ...   Filter expressions passed to dplyr::filter().
#' @return The filtered data frame.
#' @export
mfilter <- function(data, ...) {
  if (!.manifest_active()) stop("[manifest] Call begin_manifest() first.")
  result <- dplyr::filter(data, ...)
  .log_delta(result, criteria = "")
  result
}

#' Manually log a filtering step with an explicit criteria string
#'
#' Use when mfilter() can't be used (e.g. merges, deduplication).
#'
#' @param data     Data frame *after* the row-reducing operation.
#' @param criteria Human-readable description of why rows were removed.
#' @return Invisibly returns data.
#' @export
log_step <- function(data, criteria = "") {
  if (!.manifest_active()) stop("[manifest] Call begin_manifest() first.")
  .log_delta(data, criteria = criteria)
  invisible(data)
}

#' Finalise the manifest and write to CSV
#'
#' Parses the source script for `#:` comments, back-fills CRITERIA,
#' prints a summary table, and saves a timestamped CSV.
#'
#' @param data   The data frame in its final filtered state.
#' @param print  Print the manifest table to the console?
#' @return Invisibly returns the manifest data frame.
#' @export
end_manifest <- function(data, print = TRUE) {
  if (!.manifest_active()) stop("[manifest] Call begin_manifest() first.")

  # Back-fill CRITERIA and CODE from source
  script <- .menv$script
  if (!is.null(script) && file.exists(script)) {
    end_line <- .detect_call_line("end_manifest")
    parsed   <- .extract_criteria(script,
                                  from = .menv$begin_line,
                                  to   = end_line)
    n_steps  <- nrow(.menv$log) - 1L
    for (i in seq_len(min(length(parsed), n_steps))) {
      .menv$log$CRITERIA[i + 1L] <- parsed[[i]]$criteria
      .menv$log$CODE[i + 1L]     <- parsed[[i]]$code
      if (nchar(parsed[[i]]$name) > 0)
        .menv$log$STEP[i + 1L] <- sprintf("(%d) %s", i, parsed[[i]]$name)
    }
  } else {
    message(
      "[manifest] Script path not found; CRITERIA left blank.\n",
      "  Tip: pass current_script = 'path/to/script.R' in begin_manifest(), or\n",
      "  use log_step(data, criteria = '...') for manual annotation."
    )
  }

  # Save CSV
  out_dir <- .menv$output_dir
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  ts    <- format(Sys.time(), "%Y%m%d_%H%M%S")
  fpath <- file.path(out_dir,
    sprintf("%s_manifest_%s.csv", .menv$dataset_name, ts))
  utils::write.csv(.menv$log, fpath, row.names = FALSE)

  # Print
  if (print) {
    cat("\n------ Data Manifest ", paste(rep("---", 44), collapse=""), "\n", sep="")
    print(.menv$log, row.names = FALSE)
    cat(sprintf("\n---  Saved --- %s\n", fpath))
    cat(paste(rep("---", 62), collapse=""), "\n\n")
  }

  invisible(.menv$log)
}

#' Inspect the current manifest log mid-script
#' @return Invisibly returns the log data frame.
#' @export
manifest_log <- function() {
  if (!.manifest_active()) {
    message("[manifest] No active manifest. Call begin_manifest() first.")
    return(invisible(NULL))
  }
  print(.menv$log, row.names = FALSE)
  invisible(.menv$log)
}


# ------ Internal helpers ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

.empty_log <- function() {
  data.frame(
    STEP=character(), DROPPED=integer(), DROPPED_PCT=character(),
    REMAIN=integer(), REMAIN_PCT=character(),
    CRITERIA=character(), CODE=character(),
    stringsAsFactors=FALSE
  )
}

.manifest_active <- function() exists("log", envir=.menv, inherits=FALSE)

.log_delta <- function(data, criteria="") {
  n_before <- .menv$n_current
  n_after  <- nrow(data)
  dropped  <- n_before - n_after
  n_start  <- .menv$n_start

  .menv$step      <- .menv$step + 1L
  .menv$n_current <- n_after

  .menv$log <- rbind(.menv$log, data.frame(
    STEP        = sprintf("(%d)", .menv$step),
    DROPPED     = dropped,
    DROPPED_PCT = sprintf("%.1f%%", 100 * dropped / n_start),
    REMAIN      = n_after,
    REMAIN_PCT  = sprintf("%.1f%%", 100 * n_after  / n_start),
    CRITERIA    = criteria,
    CODE        = "",            # back-filled by end_manifest()
    stringsAsFactors = FALSE
  ))
}

# Parse #: comments and their associated code lines from a script window.
#
# Returns a list of triples: list(name = "...", criteria = "...", code = "...")
# Rules:
#   - A #: line matching ^#:\s*\{name\} ... sets the step name; stripped from CRITERIA
#   - Remaining consecutive #: lines are concatenated into one criteria string
#   - The first non-comment, non-blank line after a #: block is captured as CODE
#   - ## lines and ordinary # lines are skipped (never captured as code)
#   - Multi-line expressions joined by a trailing pipe/plus are concatenated
.extract_criteria <- function(script, from=1L, to=Inf) {
  lines   <- readLines(script, warn=FALSE)
  from    <- max(1L, from)
  to      <- min(length(lines), to)
  lines   <- lines[seq(from, to)]

  results  <- list()
  current_criteria <- character()
  current_name     <- ""
  in_criteria_block <- FALSE
  capturing_code    <- FALSE
  current_code      <- character()

  flush <- function() {
    if (length(current_criteria) > 0 || nchar(current_name) > 0) {
      results[[length(results) + 1L]] <<- list(
        name     = current_name,
        criteria = paste(trimws(current_criteria), collapse = " "),
        code     = paste(trimws(current_code),     collapse = " ")
      )
    }
    current_name      <<- ""
    current_criteria  <<- character()
    current_code      <<- character()
    in_criteria_block <<- FALSE
    capturing_code    <<- FALSE
  }

  for (ln in lines) {
    s <- trimws(ln)

    if (grepl("^#:[[:space:]]?", s)) {
      # If we were capturing code, a new #: block starts a new entry
      if (capturing_code) flush()
      body <- trimws(sub("^#:[[:space:]]?", "", s))

      # Detect {name} tag: #: {name} My Step Label
      if (grepl("^[{]name[}]", body)) {
        current_name <- trimws(sub("^[{]name[}][[:space:]]?", "", body))
      } else {
        current_criteria <- c(current_criteria, body)
      }
      in_criteria_block <- TRUE
      capturing_code    <- FALSE

    } else if (in_criteria_block && !capturing_code &&
               (s == "" || grepl("^##", s) || grepl("^#[^:]", s))) {
      # Blank / ## / ordinary # between #: and the code line --- skip
      next

    } else if (in_criteria_block && !capturing_code && nchar(s) > 0) {
      # First real code line after a #: block
      current_code   <- c(current_code, s)
      capturing_code <- TRUE

      # If line ends with a pipe or infix operator, expect continuation
      if (!grepl("[|+&,]\\s*$", s)) flush()

    } else if (capturing_code && grepl("[|+&,]\\s*$", tail(current_code, 1))) {
      # Continuation line of a multi-line expression
      current_code <- c(current_code, s)
      if (!grepl("[|+&,]\\s*$", s)) flush()

    } else {
      # Unrelated code line --- close any open block
      if (in_criteria_block || capturing_code) flush()
    }
  }

  flush()   # close any trailing block
  results
}

.detect_call_line <- function(fn_name) {
  script <- .menv$script
  if (is.null(script) || !file.exists(script)) return(1L)
  lines <- readLines(script, warn=FALSE)
  hits  <- grep(paste0("\\b", fn_name, "\\s*\\("), lines)
  if (length(hits)==0L) return(1L)
  hits[length(hits)]
}

.detect_script_path <- function() {
  for (i in seq_len(sys.nframe())) {
    f <- sys.frame(i)$ofile
    if (!is.null(f)) return(normalizePath(f, mustWork=FALSE))
  }
  NULL
}
