#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#    Project: Fast Azimuthal integration
#             https://github.com/pyFAI/pyFAI
#
#    Copyright (C) European Synchrotron Radiation Facility, Grenoble, France
#
#    Principal author:       Jérôme Kieffer (Jerome.Kieffer@ESRF.eu)
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
__author__ = "Jerome Kieffer"
__license__ = "GPLv3+"
__date__ = "08/03/2016"
__copyright__ = "2011-2015, ESRF"
__contact__ = "jerome.kieffer@esrf.fr"


import cython
cimport numpy
import numpy
from cython.parallel cimport prange
from libc.math cimport sin, cos, atan2, sqrt, M_PI


cdef inline double f_t1(double p1, double p2, double p3, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3) nogil:
    """Calculate t2 (aka y) for 1 pixel
    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param p3: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    """
    return p1 * cosRot2 * cosRot3 + \
           p2 * (cosRot3 * sinRot1 * sinRot2 - cosRot1 * sinRot3) - \
           p3 * (cosRot1 * cosRot3 * sinRot2 + sinRot1 * sinRot3)


cdef inline double f_t2(double p1, double p2, double p3, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3) nogil:
    """Calculate t2 (aka y) for 1 pixel

    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param p3: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    """
    return p1 * cosRot2 * sinRot3 + \
           p2 * (cosRot1 * cosRot3 + sinRot1 * sinRot2 * sinRot3) - \
           p3 * (-(cosRot3 * sinRot1) + cosRot1 * sinRot2 * sinRot3)


cdef inline double f_t3(double p1, double p2, double p3, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3) nogil:
    """Calculate t3 (aka -z) for 1 pixel

    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param p3: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    """

    return  p1 * sinRot2 - p2 * cosRot2 * sinRot1 + p3 * cosRot1 * cosRot2


@cython.cdivision(True)
cdef inline double f_tth(double p1, double p2, double L, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3) nogil:
    """
    Calculate 2 theta for 1 pixel

    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param L: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    @return 2 theta
    """
    cdef:
        double t1 = f_t1(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
        double t2 = f_t2(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
        double t3 = f_t3(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    return atan2(sqrt(t1 * t1 + t2 * t2), t3)


@cython.cdivision(True)
cdef inline double f_q(double p1, double p2, double L, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3, double wavelength) nogil:
    """
    Calculate the scattering vector q for 1 pixel

    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param L: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    """
    return 4.0e-9 * M_PI / wavelength * sin(f_tth(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3) / 2.0)


@cython.cdivision(True)
cdef inline double f_chi(double p1, double p2, double L, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3) nogil:
    """
    calculate chi for 1 pixel
    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param L: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    """
    cdef:
        double t1 = f_t1(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
        double t2 = f_t2(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    return atan2(t1, t2)


@cython.cdivision(True)
cdef inline double f_r(double p1, double p2, double L, double sinRot1, double cosRot1, double sinRot2, double cosRot2, double sinRot3, double cosRot3) nogil:
    """
    calculate r for 1 pixel, radius from beam center to current
    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param L: distance sample - PONI
    @param sinRot1,sinRot2,sinRot3: sine of the angles
    @param cosRot1,cosRot2,cosRot3: cosine of the angles
    """
    cdef:
        double t1 = f_t1(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
        double t2 = f_t2(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
        double t3 = f_t3(p1, p2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    return L * sqrt(t1 * t1 + t2 * t2) / (t3 * cosRot1 * cosRot2)


@cython.cdivision(True)
cdef inline double f_cosa(double p1, double p2, double L) nogil:
    """
    calculate cosine of the incidence angle for 1 pixel

    @param p1:distances in meter along dim1 from PONI
    @param p2: distances in meter along dim2 from PONI
    @param L: distance sample - PONI
    """
    return L / sqrt((L * L) + (p1 * p1) + (p2 * p2))


################################################################################
# End of pure cython function declaration
################################################################################


@cython.boundscheck(False)
@cython.wraparound(False)
def calc_pos_zyx(double L, double rot1, double rot2, double rot3,
                 numpy.ndarray pos1 not None,
                 numpy.ndarray pos2 not None,
                 numpy.ndarray pos3=None):
    """Calculate the 3D coordinates in the sample's referential

    @param L: distance sample - PONI
    @param rot1: angle1
    @param rot2: angle2
    @param rot3: angle3
    @param pos1: numpy array with distances in meter along dim1 from PONI (Y)
    @param pos2: numpy array with distances in meter along dim2 from PONI (X)
    @param pos3: numpy array with distances in meter along Sample->PONI (Z), positive behind the detector
    @return: 3-tuple of ndarray of double with same shape and size as pos1

    """
    cdef:
        double sinRot1 = sin(rot1)
        double cosRot1 = cos(rot1)
        double sinRot2 = sin(rot2)
        double cosRot2 = cos(rot2)
        double sinRot3 = sin(rot3)
        double cosRot3 = cos(rot3)
        ssize_t  size = pos1.size, i = 0
    assert pos2.size == size
    cdef:
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float64_t, ndim = 1] t1, t2, t3

    t1 = numpy.empty(size, dtype=numpy.float64)
    t2 = numpy.empty(size, dtype=numpy.float64)
    t3 = numpy.empty(size, dtype=numpy.float64)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            t1[i] = f_t1(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t2[i] = f_t2(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t3[i] = f_t3(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            t1[i] = f_t1(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t2[i] = f_t2(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t3[i] = f_t3(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)

    if pos1.ndim == 3:
        return t1.reshape(pos1.shape[0], pos1.shape[1],pos1.shape[2]),\
               t2.reshape(pos1.shape[0], pos1.shape[1],pos1.shape[2]),\
               t3.reshape(pos1.shape[0], pos1.shape[1],pos1.shape[2])
    if pos1.ndim == 2:
        return t1.reshape(pos1.shape[0], pos1.shape[1]),\
               t2.reshape(pos1.shape[0], pos1.shape[1]),\
               t3.reshape(pos1.shape[0], pos1.shape[1])
    else:
        return t1, t2, t3


@cython.boundscheck(False)
@cython.wraparound(False)
def calc_tth(double L, double rot1, double rot2, double rot3,
             numpy.ndarray pos1 not None,
             numpy.ndarray pos2 not None,
             numpy.ndarray pos3=None):
    """
    Calculate the 2theta array (radial angle) in parallel

    @param L: distance sample - PONI
    @param rot1: angle1
    @param rot2: angle2
    @param rot3: angle3
    @param pos1: numpy array with distances in meter along dim1 from PONI (Y)
    @param pos2: numpy array with distances in meter along dim2 from PONI (X)
    @param pos3: numpy array with distances in meter along Sample->PONI (Z), positive behind the detector
    @return: ndarray of double with same shape and size as pos1
    """
    cdef:
        double sinRot1 = sin(rot1)
        double cosRot1 = cos(rot1)
        double sinRot2 = sin(rot2)
        double cosRot2 = cos(rot2)
        double sinRot3 = sin(rot3)
        double cosRot3 = cos(rot3)
        ssize_t  size = pos1.size, i = 0
    assert pos2.size == size
    cdef:
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float64_t, ndim = 1] out = numpy.empty(size, dtype=numpy.float64)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_tth(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_tth(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)

    if pos1.ndim == 2:
        return out.reshape(pos1.shape[0], pos1.shape[1])
    else:
        return out


@cython.boundscheck(False)
@cython.wraparound(False)
def calc_chi(double L, double rot1, double rot2, double rot3,
             numpy.ndarray pos1 not None,
             numpy.ndarray pos2 not None,
             numpy.ndarray pos3=None):
    """
    Calculate the chi array (azimuthal angles) in parallel

    X1 = p1*cos(rot2)*cos(rot3) + p2*(cos(rot3)*sin(rot1)*sin(rot2) - cos(rot1)*sin(rot3)) -  L*(cos(rot1)*cos(rot3)*sin(rot2) + sin(rot1)*sin(rot3))
    X2 = p1*cos(rot2)*sin(rot3) - L*(-(cos(rot3)*sin(rot1)) + cos(rot1)*sin(rot2)*sin(rot3)) +  p2*(cos(rot1)*cos(rot3) + sin(rot1)*sin(rot2)*sin(rot3))
    X3 = -(L*cos(rot1)*cos(rot2)) + p2*cos(rot2)*sin(rot1) - p1*sin(rot2)
    tan(Chi) =  X2 / X1


    @param L: distance sample - PONI
    @param rot1: angle1
    @param rot2: angle2
    @param rot3: angle3
    @param pos1: numpy array with distances in meter along dim1 from PONI (Y)
    @param pos2: numpy array with distances in meter along dim2 from PONI (X)
    @param pos3: numpy array with distances in meter along Sample->PONI (Z), positive behind the detector
    @return: ndarray of double with same shape and size as pos1
    """
    cdef:
        double sinRot1 = sin(rot1)
        double cosRot1 = cos(rot1)
        double sinRot2 = sin(rot2)
        double cosRot2 = cos(rot2)
        double sinRot3 = sin(rot3)
        double cosRot3 = cos(rot3)
    cdef ssize_t  size = pos1.size, i = 0
    assert pos2.size == size
    cdef:
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float64_t, ndim = 1] out = numpy.empty(size, dtype=numpy.float64)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_chi(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_chi(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)

    if pos1.ndim == 2:
        return out.reshape(pos1.shape[0], pos1.shape[1])
    else:
        return out


@cython.boundscheck(False)
@cython.wraparound(False)
def calc_q(double L, double rot1, double rot2, double rot3,
           numpy.ndarray pos1 not None,
           numpy.ndarray pos2 not None,
           double wavelength, pos3=None):
    """
    Calculate the q (scattering vector) array in parallel

    X1 = p1*cos(rot2)*cos(rot3) + p2*(cos(rot3)*sin(rot1)*sin(rot2) - cos(rot1)*sin(rot3)) -  L*(cos(rot1)*cos(rot3)*sin(rot2) + sin(rot1)*sin(rot3))
    X2 = p1*cos(rot2)*sin(rot3) - L*(-(cos(rot3)*sin(rot1)) + cos(rot1)*sin(rot2)*sin(rot3)) +  p2*(cos(rot1)*cos(rot3) + sin(rot1)*sin(rot2)*sin(rot3))
    X3 = -(L*cos(rot1)*cos(rot2)) + p2*cos(rot2)*sin(rot1) - p1*sin(rot2)
    tan(Chi) =  X2 / X1


    @param L: distance sample - PONI
    @param rot1: angle1
    @param rot2: angle2
    @param rot3: angle3
    @param pos1: numpy array with distances in meter along dim1 from PONI (Y)
    @param pos2: numpy array with distances in meter along dim2 from PONI (X)
    @param pos3: numpy array with distances in meter along Sample->PONI (Z), positive behind the detector
    @param wavelength: in meter to get q in nm-1
    @return: ndarray of double with same shape and size as pos1
    """
    cdef:
        double sinRot1 = sin(rot1)
        double cosRot1 = cos(rot1)
        double sinRot2 = sin(rot2)
        double cosRot2 = cos(rot2)
        double sinRot3 = sin(rot3)
        double cosRot3 = cos(rot3)
        ssize_t  size = pos1.size, i = 0, ndim
    assert pos2.size == size
    cdef:
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float64_t, ndim = 1] out = numpy.empty(size, dtype=numpy.float64)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_q(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3, wavelength)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_q(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3, wavelength)

    if pos1.ndim == 2:
        return out.reshape(pos1.shape[0], pos1.shape[1])
    else:
        return out


@cython.boundscheck(False)
@cython.wraparound(False)
def calc_r(double L, double rot1, double rot2, double rot3,
           numpy.ndarray pos1 not None, numpy.ndarray pos2 not None,
           numpy.ndarray pos3=None):
    """
    Calculate the radius array (radial direction) in parallel

    @param L: distance sample - PONI
    @param rot1: angle1
    @param rot2: angle2
    @param rot3: angle3
    @param pos1: numpy array with distances in meter along dim1 from PONI (Y)
    @param pos2: numpy array with distances in meter along dim2 from PONI (X)
    @param pos3: numpy array with distances in meter along Sample->PONI (Z), positive behind the detector
    @return: ndarray of double with same shape and size as pos1
    """
    cdef:
        double sinRot1 = sin(rot1)
        double cosRot1 = cos(rot1)
        double sinRot2 = sin(rot2)
        double cosRot2 = cos(rot2)
        double sinRot3 = sin(rot3)
        double cosRot3 = cos(rot3)
        ssize_t  size = pos1.size, i = 0
    assert pos2.size == size
    cdef:
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float64_t, ndim = 1] out = numpy.empty(size, dtype=numpy.float64)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_r(c1[i], c2[i], L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_r(c1[i], c2[i], L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)

    if pos1.ndim == 2:
        return out.reshape(pos1.shape[0], pos1.shape[1])
    else:
        return out


@cython.boundscheck(False)
@cython.wraparound(False)
def calc_cosa(double L,
              numpy.ndarray pos1 not None,
              numpy.ndarray pos2 not None,
              numpy.ndarray pos3=None):
    """
    Calculate the cosine of the incidence angle in parallel

    @param L: distance sa    - PONI
    @param pos1: numpy array with distances in meter along dim1 from PONI (Y)
    @param pos2: numpy array with distances in meter along dim2 from PONI (X)
    @param pos3: numpy array with distances in meter along Sample->PONI (Z), positive behind the detector
    @return: ndarray of double with same shape and size as pos1
    """
    cdef ssize_t  size = pos1.size, i = 0
    assert pos2.size == size
    cdef:
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float64_t, ndim = 1] out = numpy.empty(size, dtype=numpy.float64)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_cosa(c1[i], c2[i], L)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            out[i] = f_cosa(c1[i], c2[i], L + c3[i])

    if pos1.ndim == 2:
        return out.reshape(pos1.shape[0], pos1.shape[1])
    else:
        return out


# @cython.boundscheck(False)
# @cython.wraparound(False)
def calc_rad_azim(double L,
                  double poni1,
                  double poni2,
                  double rot1,
                  double rot2,
                  double rot3,
                  numpy.ndarray pos1 not None,
                  numpy.ndarray pos2 not None,
                  numpy.ndarray pos3=None,
                  space="2th",
                  wavelength=None):
    """

    raise KeyError when space is bad !
    """
    cdef ssize_t  size = pos1.size, i = 0
    assert pos2.size == size
    cdef:
        double sinRot1 = sin(rot1)
        double cosRot1 = cos(rot1)
        double sinRot2 = sin(rot2)
        double cosRot2 = cos(rot2)
        double sinRot3 = sin(rot3)
        double cosRot3 = cos(rot3)
        int cspace = 0
        double[::1] c1 = numpy.ascontiguousarray(pos1.ravel(), dtype=numpy.float64)
        double[::1] c2 = numpy.ascontiguousarray(pos2.ravel(), dtype=numpy.float64)
        double[::1] c3
        numpy.ndarray[numpy.float32_t, ndim = 2] out = numpy.empty((size,2), dtype=numpy.float32)
        double t1, t2, t3, fwavelength

    if space == "2th":
        cspace = 1
    elif space == "q":
        cspace = 2
        if not wavelength:
            raise ValueError("wavelength is needed for q calculation")
        else:
            fwavelength = float(wavelength)
    elif space == "r":
        cspace = 3
    else:
        raise KeyError("Not implemented space %s in cython"%space)

    if pos3 is None:
        for i in prange(size, nogil=True, schedule="static"):
            t1 = f_t1(c1[i]-poni1, c2[i]-poni2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t2 = f_t2(c1[i]-poni1, c2[i]-poni2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t3 = f_t3(c1[i]-poni1, c2[i]-poni2, L, sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            if cspace==1:
                out[i,0] = atan2(sqrt(t1 * t1 + t2 * t2), t3)
            elif cspace==2:
                out[i,0] = 4.0e-9 * M_PI / fwavelength * sin(atan2(sqrt(t1 * t1 + t2 * t2), t3) / 2.0)
            elif cspace==3:
                out[i,0] = L * sqrt(t1 * t1 + t2 * t2) / (t3 * cosRot1 * cosRot2)
            out[i,1] = atan2(t1, t2)
    else:
        assert pos3.size == size
        c3 = numpy.ascontiguousarray(pos3.ravel(), dtype=numpy.float64)
        for i in prange(size, nogil=True, schedule="static"):
            t1 = f_t1(c1[i]-poni1, c2[i]-poni2, L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t2 = f_t2(c1[i]-poni1, c2[i]-poni2, L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            t3 = f_t3(c1[i]-poni1, c2[i]-poni2, L + c3[i], sinRot1, cosRot1, sinRot2, cosRot2, sinRot3, cosRot3)
            if cspace==1:
                out[i,0] = atan2(sqrt(t1 * t1 + t2 * t2), t3)
            elif cspace==2:
                out[i,0] = 4.0e-9 * M_PI / fwavelength * sin(atan2(sqrt(t1 * t1 + t2 * t2), t3) / 2.0)
            elif cspace==3:
                out[i,0] = L * sqrt(t1 * t1 + t2 * t2) / (t3 * cosRot1 * cosRot2)
            out[i,1] = atan2(t1, t2)

    if pos1.ndim == 3:
        return out.reshape(pos1.shape[0], pos1.shape[1], pos1.shape[2], 2)
    if pos1.ndim == 2:
        return out.reshape(pos1.shape[0], pos1.shape[1], 2),
    else:
        return out