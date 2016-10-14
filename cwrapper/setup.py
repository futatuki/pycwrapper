#!/usr/bin/env python

import sys
import os.path
import platform
from distutils.core import setup
#from Cython.Build import cythonize
from Cython.Distutils.extension import Extension
from Cython.Distutils import build_ext
#from setuptools import setup, Extension

import cnumptrgen

cnumptrgen.main()
extensions = [
    Extension('cwrapper.cobj',['cobj.pyx']),
    Extension('cwrapper.numptr',['numptr.pyx'])]

site_package_path = (
    'lib/python' + '.'.join(platform.python_version_tuple()[0:2])
    + '/site-packages/' )

setup(name='cwrapper',
    version='0.99',
    description= 'Base Class to help writing wrapper for pointer of'
                    'C structure with Cython',
    author='Yasuhito FUTATSUKI',
    author_email='futatuki@yf.bsdclub.org',
    package_dir={'cwrapper' : ''},
    py_modules = ['cwrapper.__init__'],
    data_files = { site_package_path + 'cwrapper' :
                    ['__init__.pxd', 'numptr.pxd', 'cobj.pxd']},
    ext_modules = extensions,
    cmdclass = {'build_ext' : build_ext}
)
