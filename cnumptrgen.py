#!/usr/bin/env python
# $yfId$
import os.path 

basename = 'numptr'
seeds = [
    {'ctype' : 'int',                'clsname' : 'CIntPtr',     'defval' : 0},
    {'ctype' : 'unsigned int',       'clsname' : 'CUIntPtr',    'defval' : 0},
    {'ctype' : 'short',              'clsname' : 'CShortPtr',   'defval' : 0},
    {'ctype' : 'unsigned short',     'clsname' : 'CUShortPtr',  'defval' : 0},
    {'ctype' : 'long',               'clsname' : 'CLongPtr',    'defval' : 0},
    {'ctype' : 'unsigned long',      'clsname' : 'CULongPtr',   'defval' : 0},
    {'ctype' : 'long long',          'clsname' : 'CLLongPtr',   'defval' : 0},
    {'ctype' : 'unsigned long long', 'clsname' : 'CULLongPtr',  'defval' : 0},
    {'ctype' : 'float',              'clsname' : 'CFloatPtr',   'defval' : 0},
    {'ctype' : 'double',             'clsname' : 'CDoublePtr',  'defval' : 0},
    {'ctype' : 'long double',        'clsname' : 'CLDoublePtr', 'defval' : 0}]


hdr_text = """# %s, generated by
#   $yfId$
from __future__ import absolute_import
from .cobj cimport CObjPtr

"""

def clsdcl(ctype, clsname, defval):
    return """cdef class %s(CObjPtr): 
    pass
""" % clsname

def clsdef(ctype, clsname, defval):
    return ("""
cdef class %s(CObjPtr):
    def __cinit__(self, vals=None, nelms=0, int is_const=False, **m):
        cdef object c_base
        c_base = ('const ' if is_const else '') + '%s *'
        self._c_base_type = c_base
        self._c_esize = sizeof(%s)
        self._mddict = { 'p_' : %s }
    property p_:
        def __get__(self):
            assert self._c_ptr is not NULL
            return (<%s *>(self._c_ptr))[0]
        def __set__(self, val):
            assert self._c_ptr is not NULL
            if self._is_const and self._is_init:
                raise TypeError('Pointer points const value. Cannot alter')
            (<%s*>(self._c_ptr))[0] = val
        def __del__(self):
            assert self._c_ptr is not NULL
            (<%s*>(self._c_ptr))[0] = %s
""" % (clsname, ctype, ctype, defval, ctype, ctype, ctype, defval))

def write_cython_src(prefix=None):

    if prefix:
        pxdfname = os.path.join(prefix, basename + '.pxd')
        pyxfname = os.path.join(prefix, basename + '.pyx')
    else:
        pxdfname = basename + '.pxd'
        pyxfname = basename + '.pyx'
    pxdfile = open(pxdfname, 'w')
    pyxfile = open(pyxfname, 'w')
    # write header
    pxdfile.write(hdr_text % pxdfname)
    pyxfile.write(hdr_text % pyxfname)
    for s in seeds:
        pxdfile.write(clsdcl(**s))
        pyxfile.write(clsdef(**s))
    pxdfile.close()
    pyxfile.close()

def main():
    write_cython_src()

if __name__ == "__main__":
    main()
