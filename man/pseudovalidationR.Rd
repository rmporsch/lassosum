% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pseudovalidationR.R
\name{pseudovalidationR}
\alias{pseudovalidationR}
\title{Performs `pseudovalidation' to select the best \eqn{\lambda} value in 
lassosum (without PLINK bfile)}
\usage{
pseudovalidationR(genotype.mat, beta, cor)
}
\arguments{
\item{genotype.mat}{A genotype matrix (coded 0/1/2)}

\item{beta}{The matrix of estimated \eqn{\beta}s}

\item{cor}{The vector of correlations (\eqn{r})}
}
\value{
the results of the pseudovalidation, i.e. \eqn{f(\lambda)}
}
\details{
A function to calculate  
\deqn{f(\lambda)=\beta'r/\sqrt{\beta'X'X\beta}} 
where \eqn{X} is the standardized genotype matrix divided by \eqn{\sqrt n}, 
and \eqn{r} is a vector of (shrunken) correlations.
}
\note{
\itemize{
\item The number of rows in \code{beta} and the length of \code{cor} should be the 
same as the number of columns in \code{genotype.mat}.
}
}

