"""
Generates mock data sets for partial correlation analysis with cens_tau.f.
"""

import numpy

"""
First generates a test dataset x,y,z in which
  x=az+b
  y=cz+d
such that the correlation between x and y is actually driven by their mutual
correlation with z. I add white noise to the simulated data.
"""

# x,y,z
z=numpy.linspace(0,10,50)
noisex=numpy.random.normal(size=z.size)
noisey=numpy.random.normal(size=z.size)
x=z+10.+noisex
y=5.*z+3.+noisey
cens=numpy.ones(x.size,dtype=numpy.int)

# Exports to a data file
numpy.savetxt('test01.dat',numpy.transpose((x,cens,y,cens,z,cens)),fmt='%10.4f %i %10.4f %i %10.4f %i')