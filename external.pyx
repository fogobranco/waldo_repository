from libc.math cimport sqrt, pow
from libc.stdlib cimport rand, RAND_MAX


cpdef double distance (double x1, double y1, double x2, double y2):
    return sqrt(pow(x2-x1,2.0)+pow(y2-y1,2.0))

cpdef double prob(double chance):
    r =  float(rand()/(RAND_MAX*1.0)) 
    return r*100 < chance * 100