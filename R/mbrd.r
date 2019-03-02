#'@title Function to create MBR-design.
#'@name mbrd
#'@aliases mbrd
#'@description Function to create multi-level binary replacement (MBR) design (Martens et al., 2010). The MBR approach was 
#'developed for constructing experimental designs for computer experiments.
#'MBR makes it possible to set up fractional designs for multi-factor problems 
#'with potentially many levels for each factor. In this package 
#'it is mainly called by the \code{mbrdsim} function.
#'@usage mbrd(l2levels = c(2, 2), fraction = 0, gen = NULL, fnames1 = NULL, fnames2 = NULL)
#'@param l2levels A vector indicating the number of log2-levels for each factor. E.g. \code{c(2,3)} means 2 factors,
#'the first with \eqn{2^2=4} levels, the second with \eqn{2^3=8} levels
#'@param fraction Design fraction at bit-level. Full design: fraction=0, half-fraction: fraction=1, and so on...
#'@param gen list of generators at bit-factor level. Same as generators in function FrF2.
#'@param fnames1 Factor names of original multi-level factors (optional).
#'@param fnames2 Factor names at bit-level (optional).
#'@details The MBR design approach was developed for designing fractional designs in multi-level multi-factor experiments, 
#'typically computer experiments. The basic idea can be summarized in the following steps: 1) Choose the number of levels \eqn{L} 
#'for each multi-level factor as a multiple of 2, that is \eqn{L \in \{2, 4, 8,...\}}. 2) Replace any given multi-level factor by a 
#'set of \eqn{ln(L)} two-level "bit factors". The complete bit-factor design can then by expressed as a \eqn{2^K} design where \eqn{K} 
#'is the total number of bit-factors across all original multi-level factors. 3) Choose a fraction level \eqn{P} defining av fractional 
#'design \eqn{2^{(K-P)}} (see e.g. Montgomery, 2008) as for regular two-levels factorial designs. 4) 
#'Express the reduced design in terms of the original multi-level factors.
#'@return 
#'  \item{BitDesign}{The design at bit-factor level (inherits from FrF2). Function \code{design.info()}
#'  can be used to get extra design info of the bit-design, and \code{plot} for plotting of the bit-level design.} 
#'  \item{Design}{The design at original factor levels, non-randomized.}
#'@references Martens, H., Måge, I., Tøndel, K., Isaeva, J., Høy, M. and Sæbø¸, S., 2010, Multi-level binary replacement (MBR) design for computer experiments in high-dimensional nonlinear systems, \emph{J, Chemom}, \bold{24}, 748--756.
#'@references Montgomery, D., \emph{Design and analysis of experiments}, John Wiley & Sons, 2008.
#'@examples 
#'  #Two variables with 8 levels each (2^3=8), a half-fraction design.
#'  res <- mbrd(c(3,3),fraction=1, gen=list(c(1,4)))
#'  #plot(res$Design, pch=20, cex=2, col=2)
#'  #Three variabler with 8 levels each, a 1/16-fraction.
#'  res <- mbrd(c(3,3,3),fraction=4)
#'  #library(rgl)
#'  #plot3d(res$Design,type="s",col=2)
#'@keywords MBRD
#'@keywords Design
#'@importFrom FrF2 FrF2
#'@importFrom sfsmisc polyn.eval
#'@export

mbrd <- function(l2levels = c(2,2), fraction = 0, gen = NULL, fnames1 = NULL, fnames2 = NULL){
    nfac <- length(l2levels)
    if(is.null(fnames1)){
      fnames1 <- character()
      for(i in 1:nfac){
        fnames1 <- c(fnames1, paste(letters[i], 1:l2levels[i], sep=""))
      }
    }
    if(is.null(fnames2)){
      fnames2 <- LETTERS[1:nfac]      
    }
    D1 <- FrF2(nfactors = sum(l2levels), randomize = FALSE, nruns = 2^(sum(l2levels) - fraction), 
               generators = gen, factor.names = fnames1)
    D2 <- ifelse(D1 == -1, 0, 1)
    D3 <- t(apply(D2, 1, .bits2int, l2levels = l2levels))
    colnames(D3) <- fnames2
    res <- list(BitDesign = D1, Design = D3+1)
    return(res)
}

.bits2int <- function(x, l2levels){
    nfac <- length(l2levels)
    cumlevels<-c(0,cumsum(l2levels))+1
    intvec <- rep(0,nfac)
    for(i in 1:nfac){
      z <- x[cumlevels[i]:(cumlevels[i+1]-1)]
      intvec[i] <- polyn.eval(z, 2)
    }
    return(intvec)
  }