% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plotting-functions.R
\name{plot_covariance}
\alias{plot_covariance}
\title{Plot Covariance between predictor (components) and response (components)}
\usage{
plot_covariance(
  sigma_df,
  lambda_df = NULL,
  base_theme = theme_grey,
  lab_list = NULL,
  theme_list = NULL
)
}
\arguments{
\item{sigma_df}{A data.frame generated by tidy_sigma}

\item{lambda_df}{A data.frame generated by tidy_lambda}

\item{base_theme}{Base ggplot theme to apply}

\item{lab_list}{List of labs arguments such as x, y, title, subtitle}

\item{theme_list}{List of theme arguments to apply in the plot}
}
\value{
A plot of true regression coefficients for the simulated data
}
\description{
Plot Covariance between predictor (components) and response (components)
}
\examples{
sobj <- bisimrel(p = 12)
sigma_df <- sobj \%>\%
    cov_mat(which = "zy") \%>\%
    tidy_sigma() \%>\%
    abs_sigma()
lambda_df <- sobj \%>\%
    tidy_lambda()
plot_covariance(
    sigma_df,
    lambda_df,
    base_theme = ggplot2::theme_bw,
    lab_list = list(
        title = "Covariance between Response and Predictor Components",
        subtitle = "The bar represents the eigenvalues predictor covariance",
        y = "Absolute covariance",
        x = "Predictor Component",
        color = "Response Component"
    ),
    theme_list = list(
        legend.position = "bottom"
    )
)
}
