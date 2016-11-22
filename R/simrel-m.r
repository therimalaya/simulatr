#' Validating parameter that is passed into \code{simulatr} function
#' @param par_list A list of parameters that \code{simulatr} takes
#' @importFrom stats cov rnorm runif
#' @keywords internal
#' @return A list of validation message either stop message \code{stop_msg} or warning message \code{warn_msg}

.validate_param <- function(par_list){
  pl <- par_list
  stop_msg <- list()
  warn_msg <- list()
  
  ## Critical Error
  if (!all(sapply(list(length(pl$relpos), length(pl$R2)), identical, length(pl$q))))
    stop_msg$uneql <- "Length of relpos, R2 and q must be equal\n"

  if (!all(sapply(seq_along(pl$q), function(i) pl$q[i] > sapply(pl$relpos, length)[i])))
    stop_msg$bigPred <- "Number of relevant predictor is smaller than the number of relevant components\n"

  if (!sum(pl$q) < pl$p)
    stop_msg$smallnvar <- "Number of variables can not be smaller than the number of relevant variables\n"

  if (!max(unlist(pl$relpos)) < pl$p)
    stop_msg$bigRelpos <- "Relevant Position can not exceed the number of variables\n"

  if (!all(pl$R2 < 1 & pl$R2 > 0))
    stop_msg$invalidR2 <- "R2 must be between 0 and 1\n"
  if (!is.null(pl$muX) & length(pl$muX) != pl$p) {
    stop_msg$muXlength <- "Mean of X must have same length as the number of X variables\n"
  }
  if (!is.null(pl$muY) & length(pl$muY) != pl$m) {
    stop_msg$muYlength <- "Mean of Y must have same length as the number of Y variables\n"
  }
  if (any(duplicated(unlist(pl$ypos)))) {
    stop_msg$duplicateY <- "Response Space must have unique combination of response variable."
  }

  ## Warning Conditions
  if (any(unlist(lapply(pl$ypos, identical, 1:2)))) {
    warnMst$noisY <- "Current setting of ypos will produce uninformative response variable."
  }
  valdMsg <- list(stop_msg = stop_msg, warn_msg = warn_msg)
  return(valdMsg)
}

#' Simulation of Multivariate Linear Model Data
#' @param n Number of observations
#' @param p Number of variables
#' @param q Vector containing the number of relevant predictor variables for each relevant response components
#' @param m Number of response variables
#' @param relpos A list of position of relevant component for predictor variables. The list contains vectors of position index, one vector or each relevant response components
#' @param gamma A declining (decaying) factor of eigen value of predictors (X). Higher the value of \code{gamma}, the decrease of eigenvalues will be steeper
#' @param R2 Vector of coefficient of determination (proportion of variation explained by predictor variable) for each relevant response components
#' @param ntest Number of test observation
#' @param muX Vector of average (mean) for each predictor variable
#' @param muY Vector of average (mean) for each response variable
#' @param ypos List of position of relevant response components that are combined to generate response variable during orthogonal rotation
#' @return A simrel object with all the input arguments along with following additional items
#'     \item{X}{Simulated predictors}
#'     \item{Y}{Simulated responses}
#'     \item{W}{Simulated predictor components}
#'     \item{Z}{Simulated response components}
#'     \item{beta}{True regression coefficients}
#'     \item{beta0}{True regression intercept}
#'     \item{relPred}{Position of relevant predictors}
#'     \item{testX}{Test Predictors}
#'     \item{testY}{Test Response}
#'     \item{testW}{Test predictor components}
#'     \item{testZ}{Test response components}
#'     \item{minerror}{Minimum model error}
#'     \item{Xrotation}{Rotation matrix of predictor (R)}
#'     \item{Yrotation}{Rotation matrix of response (Q)}
#'     \item{type}{Type of simrel object \emph{univariate} or \emph{multivariate}}
#'     \item{lambda}{Eigenvalues of predictors}
#'     \item{SigmaWZ}{Variance-Covariance matrix of components of response and predictors}
#'     \item{SigmaWX}{Covariance matrix of response components and predictors}
#'     \item{SigmaYZ}{Covariance matrix of response and predictor components}
#'     \item{Sigma}{Variance-Covariance matrix of response and predictors}
#'     \item{RsqW}{Coefficient of determination corresponding to response components}
#'     \item{RsqY}{Coefficient of determination corresponding to response variables}
#' @keywords simulation, linear model, linear model data
#' @references Sæbø, S., Almøy, T., & Helland, I. S. (2015). simrel—A versatile tool for linear model data simulation based on the concept of a relevant subspace and relevant predictors. Chemometrics and Intelligent Laboratory Systems, 146, 128-135.
#' @references Almøy, T. (1996). A simulation study on comparison of prediction methods when only a few components are relevant. Computational statistics & data analysis, 21(1), 87-107.
#' @export

simrel_m <- function(n = 100, p = 15, q = c(5, 4, 3), m = 5,
                    relpos = list(c(1, 2), c(3, 4, 6), c(5, 7)),
                    gamma = 0.6, R2 = c(0.8, 0.7, 0.8),
                    ntest = NULL, muX = NULL, muY = NULL,
                    ypos = list(c(1), c(3, 4), c(2, 5))) {

  ## Validate Inputs
  arg_list <- as.list(environment())
  ### Make Different Function for this and pass argList to the function
  val.out <- .validate_param(arg_list)
  if (length(val.out$stop_msg) != 0) {
    stop(paste(sapply(val.out$stop_msg, paste, collapse = '\n')), call. = FALSE)
  }

  if (length(val.out$warn_msg) != 0) {
    warning(paste(sapply(val.out$warn_msg, paste, collapse = '\n')), call. = FALSE)
  }

  ## Expected Error Messages
  err.msg <- list(
    lessCor = expression({
      stop("Two Responses in orthogonal, but highly relevant spaces must be less correlated. Choose rho closer to zero.")
    }),
    noPD = expression({
      stop("No positive definite coveriance matrix found with current parameter settings")
    })
  )

  ## Completing Parameter for required response
  nW0 <- length(relpos)
  nW.extra <- m - length(relpos)
  nW.extra.idx <- seq.int(nW0 + 1, length.out = nW.extra)

  relpos <- append(relpos, lapply(nW.extra.idx, function(x) integer()))
  R2 <- c(R2, rep(0, nW.extra))
  q <- c(q, rep(0, nW.extra))

  ## How many components are relevant for each W_i
  n.relpos <- vapply(relpos, length, 0L)

  ## Irrelevant position of predictors
  irrelpos <- setdiff(seq_len(p), Reduce(union, relpos))
  predPos <- lapply(seq_along(relpos), function(i){
    pos <- relpos[[i]]
    ret <- c(pos, sample(irrelpos, q[i] - length(pos)))
    irrelpos <<- setdiff(irrelpos, ret)
    return(ret)
  })
  names(predPos) <- paste0("Relevant for W", seq_along(relpos))

  ## Constructing Sigma
  lambda <- exp(-gamma * (1:p))/exp(-gamma)
  SigmaZ <- diag(lambda); SigmaZinv <- diag(1 / lambda)
  # SigmaW <- matrix(rho, nW, nW); diag(SigmaW) <- 1
  # SigmaW <- as.matrix(Matrix::bdiag(SigmaW, diag(m - nW)))
  SigmaW <- diag(m)
  rhoMat <- SigmaW

  ### Covariance Construction
  get_cov <- function(pos, Rsq, p = p, lambda = lambda){
    out <- vector("numeric", p)
    alph <- runif(length(pos), -1, 1)
    out[pos] <- sign(alph) * sqrt(Rsq * abs(alph) / sum(abs(alph)) * lambda[pos])
    return(out)
  }
  get_rho <- function(rhoMat, RsqVec) {
    sapply(1:nrow(rhoMat), function(row){
      sapply(1:ncol(rhoMat), function(col){
        if (row == col) return(1)
        rhoMat[row, col] / sqrt((RsqVec[row]) * (RsqVec[col]))
      })
    })
  }

  SigmaZW <- mapply(get_cov, pos = relpos, Rsq = R2, MoreArgs = list(p = p, lambda = lambda))
  Sigma <- cbind(rbind(SigmaW, SigmaZW), rbind(t(SigmaZW), SigmaZ))
  rho.out <- get_rho(rhoMat, R2)
  rho.out[is.nan(rho.out)] <- 0
  if (any(rho.out < -1 | rho.out > 1)) eval(err.msg$lessCor)

  ## Rotation Matrix
  RotX <- diag(p)
  RotY <- diag(m)

  getRotate <- function(predPos){
    n <- length(predPos)
    Qmat <- matrix(rnorm(n ^ 2), n)
    Qmat <- scale(Qmat, scale = FALSE)
    qr.Q(qr(Qmat))
  }

  for (pos in predPos) {
    rotMat <- getRotate(pos)
    RotX[pos, pos] <- rotMat
  }

  for (pos in ypos) {
    rotMat <- getRotate(pos)
    RotY[pos, pos] <- rotMat
  }


  ## True Regression Coefficient
  betaZ <- SigmaZinv %*% SigmaZW
  betaX <- RotX %*% betaZ %*% t(RotY)

  ## Geting Coef for Intercept
  beta0 <- rep(0, m)
  if (!(is.null(muY))) {
    beta0 <- beta0 + muY
  }
  if (!(is.null(muX))) {
    beta0 <- beta0 - t(betaX) %*% muX
  }

  ## True Coefficient of Determination for W's
  RsqW <- t(betaZ) %*% SigmaZW %*% solve(SigmaW)
  RsqY <- t(RotY) %*% RsqW %*% RotY

  ## Var-Covariance for Response and Predictors
  SigmaY <- t(RotY) %*% SigmaW %*% RotY
  SigmaX <- t(RotX) %*% SigmaZ %*% RotX
  SigmaYX <- t(RotY) %*% t(SigmaZW) %*% RotX
  SigmaYZ <- t(RotY) %*% t(SigmaZW)
  SigmaWX <- t(SigmaZW) %*% t(RotX)
  SigmaOut <- rbind(
    cbind(SigmaY, SigmaYX),
    cbind(t(SigmaYX), SigmaX)
  )
  ## Minimum Error
  minerror <- SigmaY - RsqY

  ## Check for Positive Definite
  pd <- all(eigen(Sigma)$values > 0)
  if (!pd) eval(err.msg[['noPD']])

  ## Simulation of Test and Training Data
  SigmaRot <- chol(Sigma)
  train_cal <- matrix(rnorm(n * (p + m), 0, 1), nrow = n)
  train_cal <- train_cal %*% SigmaRot
  W <- train_cal[, 1:m, drop = F]
  Z <- train_cal[, (m + 1):(m + p), drop = F]
  X <- Z %*% t(RotX)
  Y <- W %*% t(RotY)
  if (!(is.null(muX))) X <- sweep(X, 2, '+')
  if (!(is.null(muY))) Y <- sweep(Y, 2, '+')
  colnames(X) <- paste0('X', 1:p)
  colnames(Y) <- paste0('Y', 1:m)

  ### Test Data
  if (!is.null(ntest)) {
    test_cal <- matrix(rnorm(ntest * (p + m), 0, 1), nrow = ntest)
    test_cal <- test_cal %*% SigmaRot
    testW <- test_cal[, 1:m, drop = F]
    testZ <- test_cal[, (m + 1):(m + p), drop = F]
    testX <- testZ %*% t(RotX)
    testY <- testW %*% t(RotY)
    if (!(is.null(muX))) testX <- sweep(testX, 2, muX, '+')
    if (!(is.null(muY))) testY <- sweep(testY, 2, muY, '+')
    colnames(testX) <- paste0('X', 1:p)
    colnames(testY) <- paste0('Y', 1:m)
  } else {
    testX <- NULL; testY <- NULL
    testZ <- NULL; testW <- NULL
  }

  ## Return List
  ret <- list(
    call = match.call(),
    X = X,
    Y = Y,
    W = W,
    Z = Z,
    beta = betaX,
    beta0 = beta0,
    relPred = predPos,
    testX = testX,
    testY = testY,
    testW = testW,
    testZ = testZ,
    minerror = minerror,
    Xrotation = RotX,
    Yrotation = RotY,
    type = "multivariate",
    lambda = lambda,
    SigmaWZ = Sigma,
    SigmaWX = SigmaWX,
    SigmaYZ = SigmaYZ,
    SigmaYX = SigmaYX,
    Sigma = SigmaOut,
    rho.out = rho.out,
    RsqW = RsqW,
    RsqY = RsqY
  )
  ret <- `class<-`(append(arg_list, ret), 'simrel')
  return(ret)
}
