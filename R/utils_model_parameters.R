#' @importFrom utils packageVersion
#' @keywords internal
.add_model_parameters_attributes <- function(params, model, ci, exponentiate = FALSE, bootstrap = FALSE, iterations = 1000, df_method = NULL, ci_method = NULL, ...) {
  dot.arguments <- lapply(match.call(expand.dots = FALSE)$`...`, function(x) x)
  info <- tryCatch(
    {
      suppressWarnings(insight::model_info(model, verbose = FALSE))
    },
    error = function(e) {
      NULL
    }
  )

  ## TODO remove is.list() when insight 0.8.3 on CRAN
  if (is.null(info) || !is.list(info)) {
    info <- list(family = "unknown", link_function = "unknown")
  }

  if (is.null(attr(params, "pretty_names", exact = TRUE))) {
    attr(params, "pretty_names") <- format_parameters(model)
  }
  attr(params, "ci") <- ci
  attr(params, "bayes_ci_method") <- ci_method
  attr(params, "exponentiate") <- exponentiate
  attr(params, "ordinal_model") <- isTRUE(info$is_ordinal) | isTRUE(info$is_multinomial)
  attr(params, "model_class") <- class(model)
  attr(params, "bootstrap") <- bootstrap
  attr(params, "iterations") <- iterations
  attr(params, "df_method") <- df_method

  model_formula <- tryCatch(
    {
      .safe_deparse(insight::find_formula(model)$conditional)
    },
    error = function(e) {
      NULL
    }
  )
  attr(params, "model_formula") <- model_formula

  # column name for coefficients
  coef_col <- .find_coefficient_type(info, exponentiate)
  attr(params, "coefficient_name") <- coef_col
  attr(params, "zi_coefficient_name") <- ifelse(isTRUE(exponentiate), "Odds Ratio", "Log-Odds")


  if (inherits(model, c("rma", "rma.uni"))) {
    rma_data <- tryCatch(
      {
        insight::get_data(model)
      },
      error = function(e) {
        NULL
      }
    )
    attr(params, "data") <- rma_data
    attr(params, "study_weights") <- 1 / model$vi
  }

  if (utils::packageVersion("insight") > "0.10.0") {
    if (inherits(model, c("meta_random", "meta_fixed", "meta_bma"))) {
      rma_data <- tryCatch(
        {
          insight::get_data(model)
        },
        error = function(e) {
          NULL
        }
      )
      attr(params, "data") <- rma_data
      attr(params, "study_weights") <- 1 / params$SE^2
    }
  }

  if ("digits" %in% names(dot.arguments)) {
    attr(params, "digits") <- eval(dot.arguments[["digits"]])
  } else {
    attr(params, "digits") <- 2
  }

  if ("ci_digits" %in% names(dot.arguments)) {
    attr(params, "ci_digits") <- eval(dot.arguments[["ci_digits"]])
  } else {
    attr(params, "ci_digits") <- 2
  }

  if ("p_digits" %in% names(dot.arguments)) {
    attr(params, "p_digits") <- eval(dot.arguments[["p_digits"]])
  } else {
    attr(params, "p_digits") <- 3
  }

  if ("s_value" %in% names(dot.arguments)) {
    attr(params, "s_value") <- eval(dot.arguments[["s_value"]])
  }

  params
}



.find_coefficient_type <- function(info, exponentiate) {
  # column name for coefficients
  coef_col <- "Coefficient"
  if (!is.null(info)) {
    if (!info$family == "unknown") {
      if (isTRUE(exponentiate)) {
        if ((info$is_binomial && info$is_logit) || info$is_ordinal || info$is_multinomial || info$is_categorical) {
          coef_col <- "Odds Ratio"
        } else if (info$is_binomial && !info$is_logit) {
          coef_col <- "Risk Ratio"
        } else if (info$is_count) {
          coef_col <- "IRR"
        }
      } else {
        if (info$is_binomial || info$is_ordinal || info$is_multinomial || info$is_categorical) {
          coef_col <- "Log-Odds"
        } else if (info$is_count) {
          coef_col <- "Log-Mean"
        }
      }
    }
  }
  coef_col
}



#' @keywords internal
.exponentiate_parameters <- function(params) {
  columns <- grepl(pattern = "^(Coefficient|Mean|Median|MAP|Std_Coefficient|CI_|Std_CI)", colnames(params))
  if (any(columns)) {
    params[columns] <- exp(params[columns])
    if (all(c("Coefficient", "SE") %in% names(params))) {
      params$SE <- params$Coefficient * params$SE
    }
  }
  params
}




#' @importFrom insight clean_parameters
.add_pretty_names <- function(params, model) {
  attr(params, "model_class") <- class(model)
  cp <- insight::clean_parameters(model)
  clean_params <- cp[cp$Parameter %in% params$Parameter, ]
  attr(params, "cleaned_parameters") <- setNames(clean_params$Cleaned_Parameter[match(params$Parameter, clean_params$Parameter)], params$Parameter)
  attr(params, "pretty_names") <- setNames(clean_params$Cleaned_Parameter[match(params$Parameter, clean_params$Parameter)], params$Parameter)

  params
}




#' @keywords internal
.add_anova_attributes <- function(params, model, ci, ...) {
  dot.arguments <- lapply(match.call(expand.dots = FALSE)$`...`, function(x) x)

  attr(params, "ci") <- ci
  attr(params, "model_class") <- class(model)

  if ("digits" %in% names(dot.arguments)) {
    attr(params, "digits") <- eval(dot.arguments[["digits"]])
  } else {
    attr(params, "digits") <- 2
  }

  if ("ci_digits" %in% names(dot.arguments)) {
    attr(params, "ci_digits") <- eval(dot.arguments[["ci_digits"]])
  } else {
    attr(params, "ci_digits") <- 2
  }

  if ("p_digits" %in% names(dot.arguments)) {
    attr(params, "p_digits") <- eval(dot.arguments[["p_digits"]])
  } else {
    attr(params, "p_digits") <- 3
  }

  if ("s_value" %in% names(dot.arguments)) {
    attr(params, "s_value") <- eval(dot.arguments[["s_value"]])
  }

  params
}



.additional_arguments <- function(x, value, default) {
  args <- attributes(x)$additional_arguments

  if (length(args) > 0 && value %in% names(args)) {
    out <- args[[value]]
  } else {
    out <- attributes(x)[[value]]
  }

  if (is.null(out)) {
    out <- default
  }

  out
}
