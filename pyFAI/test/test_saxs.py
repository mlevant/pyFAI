#!/usr/bin/python
# coding: utf-8
#
#    Project: Azimuthal integration
#             https://github.com/pyFAI/pyFAI
#
#    Copyright (C) 2015 European Synchrotron Radiation Facility, Grenoble, France
#
#    Principal author:       Jérôme Kieffer (Jerome.Kieffer@ESRF.eu)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

from __future__ import absolute_import, division, print_function

__doc__ = "test suite for masked arrays"
__author__ = "Jérôme Kieffer"
__contact__ = "Jerome.Kieffer@ESRF.eu"
__license__ = "MIT"
__copyright__ = "European Synchrotron Radiation Facility, Grenoble, France"
__date__ = "02/08/2016"


import unittest
import os
import numpy
import logging
import time
import sys
import fabio
from .utilstest import UtilsTest, Rwp, getLogger
logger = getLogger(__file__)
from ..azimuthalIntegrator import AzimuthalIntegrator
from ..detectors import Pilatus1M
if logger.getEffectiveLevel() <= logging.INFO:
    import pylab
try:
    from ..third_party import six
except (ImportError, Exception):
    import six


class TestSaxs(unittest.TestCase):

    def setUp(self):
        unittest.TestCase.setUp(self)
        img = UtilsTest.getimage("Pilatus1M.edf")
        self.data = fabio.open(img).data
        self.ai = AzimuthalIntegrator(1.58323111834, 0.0334170169115, 0.0412277798782, 0.00648735642526, 0.00755810191106, 0.0, detector=Pilatus1M())
        self.ai.wavelength = 1e-10
        self.npt = 1000

    def tearDown(self):
        unittest.TestCase.tearDown(self)
        self.data = self.ai = self.npt = None

    def testMask(self):
        ss = self.ai.mask.sum()
        self.assertTrue(ss == 73533, "masked pixel = %s expected 73533" % ss)

    def testNumpy(self):
        qref, Iref, s = self.ai.saxs(self.data, self.npt)

        q, I, s = self.ai.saxs(self.data, self.npt, error_model="poisson", method="numpy")
        self.assertTrue(q[0] > 0, "q[0]>0 %s" % q[0])
        self.assertTrue(q[-1] < 8, "q[-1] < 8, got %s" % q[-1])
        self.assertTrue(s.min() >= 0, "s.min() >= 0 got %s" % (s.min()))
        self.assertTrue(s.max() < 21, "s.max() < 21 got %s" % (s.max()))
        self.assertTrue(I.max() < 52000, "I.max() < 52000 got %s" % (I.max()))
        self.assertTrue(I.min() >= 0, "I.min() >= 0 got %s" % (I.min()))
        R = Rwp((q, I), (qref, Iref))
        if R > 20: logger.error("Numpy has R=%s", R)
        if logger.getEffectiveLevel() == logging.DEBUG:
            pylab.errorbar(q, I, s, label="Numpy R=%.1f" % R)
            pylab.yscale("log")
        self.assertTrue(R < 20, "Numpy: Measure R=%s<2" % R)

    def testCython(self):
        qref, Iref, s = self.ai.saxs(self.data, self.npt)
        q, I, s = self.ai.saxs(self.data, self.npt, error_model="poisson", method="cython")
        self.assertTrue(q[0] > 0, "q[0]>0 %s" % q[0])
        self.assertTrue(q[-1] < 8, "q[-1] < 8, got %s" % q[-1])
        self.assertTrue(s.min() >= 0, "s.min() >= 0 got %s" % (s.min()))
        self.assertTrue(s.max() < 21, "s.max() < 21 got %s" % (s.max()))
        self.assertTrue(I.max() < 52000, "I.max() < 52000 got %s" % (I.max()))
        self.assertTrue(I.min() >= 0, "I.min() >= 0 got %s" % (I.min()))
        R = Rwp((q, I), (qref, Iref))
        if R > 20: logger.error("Cython has R=%s", R)
        if logger.getEffectiveLevel() == logging.DEBUG:
            pylab.errorbar(q, I, s, label="Cython R=%.1f" % R)
            pylab.yscale("log")
        self.assertTrue(R < 20, "Cython: Measure R=%s<2" % R)

    def testSplitBBox(self):
        qref, Iref, s = self.ai.saxs(self.data, self.npt)
        q, I, s = self.ai.saxs(self.data, self.npt, error_model="poisson", method="splitbbox")
        self.assertTrue(q[0] > 0, "q[0]>0 %s" % q[0])
        self.assertTrue(q[-1] < 8, "q[-1] < 8, got %s" % q[-1])
        self.assertTrue(s.min() >= 0, "s.min() >= 0 got %s" % (s.min()))
        self.assertTrue(s.max() < 21, "s.max() < 21 got %s" % (s.max()))
        self.assertTrue(I.max() < 52000, "I.max() < 52000 got %s" % (I.max()))
        self.assertTrue(I.min() >= 0, "I.min() >= 0 got %s" % (I.min()))
        R = Rwp((q, I), (qref, Iref))
        if R > 20: logger.error("SplitPixel has R=%s", R)
        if logger.getEffectiveLevel() == logging.DEBUG:
            pylab.errorbar(q, I, s, label="SplitBBox R=%.1f" % R)
            pylab.yscale("log")
        self.assertEqual(R < 20, True, "SplitBBox: Measure R=%s<20" % R)

    def testSplitPixel(self):
        qref, Iref, s = self.ai.saxs(self.data, self.npt)
        q, I, s = self.ai.saxs(self.data, self.npt, error_model="poisson", method="splitpixel")
        self.assertTrue(q[0] > 0, "q[0]>0 %s" % q[0])
        self.assertTrue(q[-1] < 8, "q[-1] < 8, got %s" % q[-1])
        self.assertTrue(s.min() >= 0, "s.min() >= 0 got %s" % (s.min()))
        self.assertTrue(s.max() < 21, "s.max() < 21 got %s" % (s.max()))
        self.assertTrue(I.max() < 52000, "I.max() < 52000 got %s" % (I.max()))
        self.assertTrue(I.min() >= 0, "I.min() >= 0 got %s" % (I.min()))
        R = Rwp((q, I), (qref, Iref))
        if R > 20: logger.error("SplitPixel has R=%s", R)
        if logger.getEffectiveLevel() == logging.DEBUG:
            pylab.errorbar(q, I, s, label="SplitPixel R=%.1f" % R)
            pylab.yscale("log")
        self.assertEqual(R < 20, True, "SplitPixel: Measure R=%s<20" % R)


def suite():
    testsuite = unittest.TestSuite()
    testsuite.addTest(TestSaxs("testMask"))
    testsuite.addTest(TestSaxs("testNumpy"))
#    testsuite.addTest(TestSaxs("testCython"))
    testsuite.addTest(TestSaxs("testSplitBBox"))
    testsuite.addTest(TestSaxs("testSplitPixel"))
#    testsuite.addTest(TestSaxs("test_mask_splitBBox"))
#    testsuite.addTest(TestSaxs("test_mask_splitBBox"))
#    testsuite.addTest(TestSaxs("test_mask_splitBBox"))
#    testsuite.addTest(TestSaxs("test_mask_splitBBox"))

    return testsuite

if __name__ == '__main__':
    runner = unittest.TextTestRunner()
    runner.run(suite())
    if logger.getEffectiveLevel() == logging.DEBUG:
        pylab.legend()
        pylab.show()
        six.moves.input()
        pylab.clf()
