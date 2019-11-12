PARTIAL CORRELATION COEFFICIENT AND SIGNIFICANCE FOR CENSORED DATA
=======================================

The code is based on the methodology presented in ['A test for partial correlation with censored astronomical data'](https://ui.adsabs.harvard.edu/abs/1996MNRAS.278..919A/abstract), Akritas & Siebert, MNRAS, 278, 919 (1996).

# What is this for? 

The idea here is suppose you have measurements for two variables, X and Y. X and Y correlate well with each other. However, they mutually correlate with a third variable Z, which you have also measured. How can you be sure that the correlation you see between X and Y is not actually driven by Z? 

One important astronomical example is when you are studying the correlation between luminosities at different bands—say X-rays and radio—for a sample of sources. The "hidden variable" Z in this case is the luminosity distance dL, which you used to convert from fluxes to luminosities. 

This statistical test quantifies the p-value for the null hypothesis Pnull of no correlation between X and Y taking into account the effect of Z. If Pnull is high, then your X-Y correlation is caused by both variables depending on Z.

# Installation

Make sure you have a fortran (sorry) compiler such as `gfortran` or `pgfortran`. This code was originally written in 1995, so be understanding.

Compile it with the command

    gfortran -O cens_tau.f -o cens_tau
    
or by running

    ./make.sh

# Usage

1.. Put your data in an ASCII file with the following structure (no need for the first line of cols in the file OK?):

```
col1 col2 col3 col4 col5 col6
 X  censX  Y  censY Z  censZ  
```

- X: independent variable
- Y: dependent variable 
- Z: test variable
- censX, censY, censZ: integer which is 1 if censX/censY/censZ is a detection or 0 if it is an upper limit

The following python snippet can be useful. Suppose you have all variables each stored in a numpy array. To create an ASCII file with the appropriate structure to be processed by `cens_tau`, issue the following command:

    numpy.savetxt(fileout, transpose((X,censX,Y,censY,Z,censZ)), fmt='%10.4f %i %10.4f %i %10.4f %i')

2.. Run the test

    ./cens_tau

[![asciicast](https://asciinema.org/a/OHsWi1RysfiDEXtJjJMfYKL1B.svg)](https://asciinema.org/a/OHsWi1RysfiDEXtJjJMfYKL1B)

If you want to test this code with artificial data, first run `gendata.py` which will generate a mock dataset in the file `test01.dat` where X and Y both are correlated with Z.

# Citation

If you use this code in your work and it gets published, you are morally obliged to cite the original paper: ['A test for partial correlation with censored astronomical data'](https://ui.adsabs.harvard.edu/abs/1996MNRAS.278..919A/abstract), Akritas & Siebert, MNRAS, 278, 919 (1996). 

I also ask you to cite [Nemmen, R. et al. *Science*, 2012, 338, 1445](http://labs.adsabs.harvard.edu/adsabs/abs/2012Sci...338.1445N/) ([bibtex citation info](http://adsabs.harvard.edu/cgi-bin/nph-bib_query?bibcode=2012Sci...338.1445N&data_type=BIBTEX&db_key=AST&nocookieset=1)) as one of the examples of application of the this test. I spent some time improving this code, so I would appreciate your citation of [my paper](http://labs.adsabs.harvard.edu/adsabs/abs/2012Sci...338.1445N/) as a token of gratitute. Thanks! 🙂
