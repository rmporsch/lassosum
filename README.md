lassosum
=======================

### Description

`lassosum` is a method for computing LASSO estimates of a linear regression problem given summary statistics from GWAS and Genome-wide meta-analyses, accounting for Linkage Disequilibrium (LD), via a reference panel.
The reference panel is assumed to be in PLINK [format](https://www.cog-genomics.org/plink2/), although `lassosum` also provides functions that work with reference panels in the form of an R data.frame or matrix.
Summary statistics are expected to be loaded into memory as a data.frame. The SNPs in the reference panel and the summary statistics need not exactly match. 

We also provide the function `pseudovalidation` to choose the optimal value of lambda in the absence of a validation dataset, and the function `pgs` for deriving polygenic scores from the estimated betas. 

### Installation

Installation is easy with `devtools`.

```r
package.install("devtools")
devtools::install_github("tshmak/lassosum")
```
### Warning!

Most functions in `lassosum` impute missing genotypes in PLINK bfiles with a homozygous A2 genotype, which is the same as using the `--fill-missing-a2` option in PLINK. It is the user's responsibility to filter out individuals and SNPs with too many missing genotypes beforehand. 

### Tutorial

We advise the use of the packages `data.table` to import summary statistics text files and `fdrtool` to compute the shrunken estimations of the correlations.

In the following tutorial we make use of two dummy datasets, which can be downloaded from this repository.
You can download the repository via

```bash
git clone https://github.com/tshmak/lassosum
```

or just download the [ZIP file](https://github.com/tshmak/lassosum/archive/master.zip).

The data for this tutorial is stored in `tutorial/data`. 
We will assume you have set your `R` working directory at `tutorial/` with 

```r
setwd("path/to/repository/tutorial")
```

First we read the summary statistics and genotyoe information of the refrence panel into R. (`read.table` is ok, but `fread` from the `data.table` package is much faster for large files.)

```r
### Read summary statistics file ###
ss <- fread("./data/summarystats.txt", data.table=F)

### Read .bim file of the reference panel ###
bim <- fread("./data/chr22a.bim", data.table=F)
```

We advise doing the analysis chromosome by chromosome.
```r
### Select chromosome 22 only ###
ss.chr22 <- subset(ss, CHR==22) 	
```

`lassosum` comes with a function `comp.ss.bim` to compare the SNPs in the summary statistics and reference panel. It identifies the common SNPs and whether the reference alleles have been reversed. To use this function, both the summary statistics and the reference panel data.frame must have at minimum 3 columns, representing the 

* the SNP id
* the reference allele
* the alternative allele

```r
### Compare ss and bim 
comp <- comp.ss.bim(ss.chr22[, c("SNP", "A1", "A2")], bim[, c("V2", "V5", "V6")]) 
```

We also provide a function `p2cor` to convert p-values into correlations. 
```r
correlation <- with(ss.chr22, 
		    p2cor(p=P[comp$ss.order], 
			  n = NMISS[comp$ss.order], 
			  sign=log(OR[comp$ss.order]) * comp$rev))
```

Define a range of lambda:
```r
lambda <- exp(seq(log(0.001), log(0.1), length.out=20))
```

Obtain the beta estimates from lassosum
```r
ls <- lassosum(cor=correlation, bfile="./data/chr22a", lambda=lambda, shrink=0.9, 
	       extract=comp$bim.extract)
```

(See below for obtaining estimates when the reference panel is given as an R data.frame.)

We can also get the independent LASSO (i.e. soft-thresholded) estimates for SNPs not in the reference panel. 

```r
correlation2 <- with(ss.chr22, p2cor(P, NMISS))
il <- indeplasso(correlation2, lambda = lambda)
```

We then combine the two sets of estimates

```r
beta <- il$beta
beta[comp$ss.order, ] <- ls$beta
```

### Pseudovalidation

We obtain the shrunken estimates for the correlations

```r
fdr <- fdrtool::fdrtool(correlation2, statistic="correlation")
correlation2.shrunk <- correlation2 * (1 - fdr$lfdr)
```

We read in the `.bim` file from the target/validation dataset and compare the included SNPs.

```r
val.bim <- fread("./data/chr22b.bim", data.table=F) 
comp2 <- comp.ss.bim(ss.chr22[, c("SNP", "A1", "A2")], val.bim[, c("V2", "V5", "V6")]) 
```

Following one can perform the pseudovalidation with
```r
pv <- pseudovalidation("./data/chr22b", 
  beta=beta[comp2$ss.order, ] * outer(comp2$rev, rep(1,ncol(beta))), 
	cor=correlation2.shrunk[comp2$ss.order], 
	extract=comp2$bim.extract)
plot(lambda, pv, log="x")
```

The best lambda is obtained by
```r
best.lambda.pos <- which(pv == max(pv))
```

and the corresponding PGS scores for the best lambda

```r
PGS <- pgs(bfile = "./data/chr22b", weights = beta[comp2$ss.order] * comp2$rev, 
	   extract=comp2$bim.extract)
```

### lassosum using a reference panel given as a data.frame

load "./data/chr22a" as a matrix 
```r
chr22a <- readbfile("./data/chr22a", fillmissing=T)
```

Get beta estimates from `lassosumR`
```r
lsR <- lassosumR(cor=correlation, refpanel=chr22a[,comp$bim.extract], 
                 lambda=lambda, shrink=0.9) 
```

pseudovalidation using chr22b as target data (using `pseudovalidationR`)
```r
chr22b <- readbfile("./data/chr22b", fillmissing=T)
pvR <- pseudovalidationR(chr22b[, comp2$bim.extract], 
                        beta=beta[comp2$ss.order, ] * outer(comp2$rev, rep(1,ncol(beta))), 
                        cor=correlation2.shrunk[comp2$ss.order])
```

### De-standardizing correlation coefficients to get regression coefficients 
Obtain SNP-wise standard deviation of target dataset 
```r
sd <- sd.bfile(bfile = "./data/chr22b", extract=comp2$bim.extract)
```
regression coefficients = correlation coefficients / sd(X) * sd(y) 
```r
reg.coef <- Matrix::Diagonal(x=1/sd) %*% beta[comp2$ss.order, ]
```

