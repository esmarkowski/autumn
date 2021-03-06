#' Diagnose convergence of weighted data to targets
#'
#' This function assesses the convergence of data to target proportions given
#' weights and returns diagnostic results.
#'
#' @param data A data frame (tibble) or matrix containing all variables in the
#'   \code{target} argument. The data frame can contain additional variables.
#' @param target A list of target proportions in the population of interest.
#'   This argument can be one of two formats: a list of named numeric vectors,
#'   or a data frame (tibble) with three columns (variable, variable level, and
#'   proportion) in order. No level may have a negative proportion or an NA, and
#'   each variable should sum to 1. If this argument is not provided, and
#'   \code{data} was constructed by \code{\link{harvest}}, then target will be
#'   read from environment.
#' @param weights Optionally, a numeric vector of weights equal in length to
#'   the number of rows in \code{data}. If this argument is not provided, then
#'   data must contain a weight column named "weights" or one of the automatic
#'   names for weight columns generated by \code{\link{harvest}}
#' @return A data frame with seven rows: "variable" (the variable among the
#'   target variables), "level" (the specific value of that variable),
#'   "prop_original" (the unweighted proportion in \code{data}),
#'   "prop_weighted" (the weighted proportion in \code{data}),
#'   "target" (the proportion expressed in \code{target}),
#'   "error_original" (absolute deviation in the unweighted \code{data}),
#'   "error_weighted" (absolute deviation in \code{data} after applying
#'   weights).
#' @export
#' @examples
#' \dontrun{
#' # Sample pipe workflow
#' respondent_data %>%
#'   harvest(ns_target) %>%
#'   diagnose_weights()
#'
#' # Explicit calls
#' result = harvest(respondent_data, ns_target)
#' diagnose_weights(data=result,
#'                  target=ns_target,
#'                  weights=result$weights)
#' }
diagnose_weights = function(data, target=NULL, weights=NULL) {
  # User did not provide target proportions. We have one trick we can try here
  # if user built the data frame using harvest and attached the weights to
  # their data frame, then we also know where in the environment that we can
  # find the target proportion that was used.
  if(is.null(target) && !is.null(attr(data, "target_symbol"))) {
    # get0 checks if a variable matching the character vector exists, and
    # returns null if it doesn't. So we're still null, then we thought we
    # could get the target proportions but we couldn't.
    target = get0(attr(data, "target_symbol"))
    if(is.null(target)) {
      stop("Error: No `target` argument was provided and attempt to locate ",
           "target used to construct weights failed. Either explicitly ",
           "provide `target` as argument or verify that `",
           attr(data, "target_symbol"),
           "` exists in R environment.")
    }
  }

  # First setup everything we need and error check.
  check_any_startup_issues(data, target,
                           convergence = c("pct" = 0, "absolute" = 0))

  # If the targets are a data frame instead of a list
  if(is.data.frame(target)) {
    target = df_targets_to_list(target)
  } else if(!is.list(target)) {
    stop("Target weights must be a list of named vectors or a data frame.")
  }

  if(is.null(weights)) {
    cand_weights = c("weights", paste0(".weights_autumn", 1:10))
    weight_var = cand_weights[which(cand_weights %in% colnames(data))[1]]
    if(is.na(weight_var)) {
      stop("Error: No `weights` specified and data does not contain a ",
           "default weights column. Please specify `weights`.")
    }

    weights = data[[weight_var]]
  }

  check_any_data_issues(data, target, weights)

  # Next, run the diagnostic.
  do.call("rbind", lapply(names(target), function(variable) {
    # Get target levels
    levels = names(target[[variable]])

    # Get original and weighted proportions (re-order to make sure the levels
    # are all copacetic)
    prop_original = weighted_pct(data[[variable]],
                                 rep(1, length(data[[variable]])))[levels]
    prop_weighted = weighted_pct(data[[variable]],
                                 weights)[levels]


    data.frame(
      variable = variable,
      level = levels,
      prop_original = prop_original,
      prop_weighted = prop_weighted,
      target = target[[variable]],
      error_original = abs(target[[variable]] - prop_original),
      error_weighted = abs(target[[variable]] - prop_weighted),
      row.names = NULL,
      stringsAsFactors = FALSE
    )
  }))
}
