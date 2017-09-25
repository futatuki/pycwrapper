#!/usr/bin/env python
# $yfId$

import sys
import os
import os.path
import platform
from distutils.core import setup
from Cython.Distutils.extension import Extension
from Cython.Distutils import build_ext
from distutils.command.build import build as _build
from distutils.cmd import Command
import primptrgen

class build(_build):
    sub_commands = [('pre_build', None)] + _build.sub_commands

class pre_build(Command):
    description = "run pre-build jobs"
    user_options = []
    boolean_options = []
    help_opthons = []
    def initialize_options(self):
        return
    def finalize_options(self):
        return
    def run(self):
        primptrgen.main()

extensions = [
    Extension('cwrapper.cobj',['cwrapper/cobj.pyx']),
    Extension('cwrapper.primptr',['cwrapper/primptr.pyx']),
    Extension('cwrapper.genprimptr',['cwrapper/genprimptr.pyx'])]

setup(name='cwrapper',
    version='0.98.3',
    description= 'Base Class to help writing wrapper for pointer of '
                    'C structure with Cython',
    author='Yasuhito FUTATSUKI',
    author_email='futatuki@yf.bsdclub.org',
    license="BSD 2 clause",
    packages = ['cwrapper'],
    package_data = { 'cwrapper': ['*.pxd'] },
    ext_modules = extensions,
    cmdclass = {'pre_build' : pre_build,
                'build'     : build,
                'build_ext' : build_ext}
)
