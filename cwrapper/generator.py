# $yfId$

import sys

#
# common code template for static/dynamic class
# 
common_template = """%%(decl_top)s
        cdef object c_base
        c_base = ('const ' if is_const else '') + '%%%%(ctype)s'
        %%(obj_ref)s._c_base_type = c_base
        %%(obj_ref)s._c_esize = sizeof(%%%%(ctype)s)
        %%(obj_ref)s._mddict = { 'p_' : %%%%(defval)s }%(madict)s
        %%(return_pre)sreturn %%(obj_ref)s%(ex_funcs)s
    %%(p_getter)s
        assert self._c_ptr is not NULL
        return (<%%%%(ctype)s*>(self._c_ptr))[0]
    %%(p_setter)s
        assert self._c_ptr is not NULL
        if self._is_const and self._is_init:
            raise TypeError('Pointer points const value. Cannot alter')
        (<%%%%(ctype)s*>(self._c_ptr))[0] = val
    %%(p_deleter)s
        assert self._c_ptr is not NULL
        if self._is_const and self._is_init:
            raise TypeError('Pointer points const value. Cannot alter')
        (<%%%%(ctype)s*>(self._c_ptr))[0] = %%%%(defval)s%(ex_props)s
%%(footer)s"""

#
# char/unsigned char wrapper specific code fragments
#
num_template_param = { 'madict' : '',  'ex_funcs' : '', 'ex_props' : '' }
def char_template_param(pyver=None):
    if pyver is None:
        pyver = sys.version_info[0]
    return {
    'madict' : """
        %(obj_ref)s._madict = { 's_' : ['p_'] }""",
    'ex_funcs' : """
    def __init__(%(init_args)s):
        cdef void * tmp_ptr
        cdef object tmp_vals
        cdef bytes bytes_val
        if (isinstance(vals, """ + (
            'str' if pyver < 3 else 'bytes') + """)):
            if is_const and nelms == 0:
                self._py_vals = [{ 's_': vals }] + ([{}] * len(vals))
                bytes_val =vals
                tmp_ptr = <void*><char*>bytes_val
                self.bind(tmp_ptr, len(vals) + 1, 0, vals, self._py_vals)
            else:
                tmp_vals = [ {'p_': """ + (
                    '%%(cast_ord_c)s' if pyver < 3 else '%%(cast_c)s') + """ }
                                    for c in vals ] + [ {'p_' : 0 } ]
                %(base)s.__init__(self, vals=tmp_vals, nelms=nelms,
                        is_const=is_const, **m)
        else:
            %(base)s.__init__(
                    self, vals=vals, nelms=nelms, is_const=is_const, **m)
    def __str__(self):
            return self.s_""",
    'ex_props' : """
    %(s_getter)s
        assert self._c_ptr is not NULL
        if (self._is_const and isinstance(self._py_vals[0], dict)
                and self._py_vals[0].has_key('s_')):
            return self._py_vals[0]['s_'][self._nth:(self._nelms-1)]
        if self._nelms != 0:
            if (<char *>(self._c_ptr))[(self._nelms-self._nth)-1] == 0:
                return (<char *>(self._c_ptr))[:(self._nelms-self._nth-1)]
            else:
                return (<char *>(self._c_ptr))[:(self._nelms-self._nth)]
        else:
            return <char *>(self._c_ptr)
    %(s_setter)s
        cdef int i, slen
        cdef %%(ctype)s* chptr
        cdef %%(ctype)s c
        assert self._c_ptr is not NULL
        if self._is_const and self._is_init:
            raise TypeError('Pointer points const value. Cannot alter')
        chptr = %%(cast_val)s
        slen = len(val) + 1
        i = 0
        while i < self._nelms - self._nth - 1 and i < slen:
            c = %%(cast_chptr)s[i]
            if c == 0:
                break
            (<%%(ctype)s*>(self._c_ptr))[i] = c
            i = i + 1
        (<%%(ctype)s*>(self._c_ptr))[i] = 0
    %(s_deleter)s
        assert self._c_ptr is not NULL
        if self._is_const and self._is_init:
            raise TypeError('Pointer points const value. Cannot alter')
        (<%%(ctype)s*>(self._c_ptr))[0] = 0"""}

#
# dynamic class generator function body
#
footer_template = """    # function body
    if not issubclass(base, CObjPtr):
        raise TypeError('base must be CObjPtr or its derivatives')
    attrdict = {'__new__'  : staticmethod(__new__)%(elms1)s,
                'p_'       : property(p_getter,p_setter,p_deleter)%(elms2)s}
    return type(etypename, (base,), attrdict.copy())"""

num_footer_params = { 'elms1' : '', 's_elm' : '' } 
char_footer_params = { 'elms1' : """,
                '__init__' : __init__,
                '__str__'  : __str__""",
                     'elms2' : """,
                's_'       : property(s_getter,s_setter,s_deleter)""" }

char_ptr_footer = footer_template % char_footer_params 

cls_params = {
    'decl_top' : """cdef class %(clsname)s(%(base)s):
    def __cinit__(self, vals=None, int nelms=0, int is_const=False, **m):""",
    'obj_ref' : 'self',
    'return_pre' : '# ',
    'init_args' : 'self, vals=None, int nelms=0, int is_const=False, **m',
    'base' : '%(base)s',
    'p_getter' : """@property
    def p_(self):""",
    'p_setter' : """@p_.setter
    def p_(self, val):""",
    'p_deleter' : """@p_.deleter
    def p_(self):""",
    's_getter' : """@property
    def s_(self):""",
    's_setter' : """@s_.setter
    def s_(self, val):""",
    's_deleter' : """@s_.deleter
    def s_(self):"""}

gen_params = {
    'decl_top' : """def gen_%(clsname)s(etypename, base):
    def __new__(cls, vals=None, nelms=0, is_const=False, **m):
        cdef CObjPtr ref
        ref = base.__new__(cls, vals, nelms, is_const, **m)""",
    'obj_ref' : 'ref',
    'return_pre' : '',
    'init_args' : 'CObjPtr self, vals=None, int nelms=0, int is_const=False, **m',
    'base' : 'base',
    'p_getter' : "def p_getter(CObjPtr self):",
    'p_setter' : "def p_setter(CObjPtr self, val):",
    'p_deleter' : "def p_deleter(CObjPtr self):",
    's_getter' : "def s_getter(CObjPtr self):",
    's_setter' : "def s_setter(CObjPtr self, val):",
    's_deleter' : "def s_deleter(CObjPtr self):" }

charptr_params = {'ctype'  : 'char', 
                         'clsname' : 'CCharPtr',  
                         'defval' : 0,
                         'base' : 'CObjPtr',
                         'cast_ord_c' : '<char>(<unsigned char>ord(c))',
                         'cast_c' : '<char>(<unsigned char>c)',
                         'cast_val' : 'val',
                         'cast_chptr' : '(<char*>chptr)' }

ucharptr_params = {'ctype'  : 'unsigned char', 
                         'clsname' : 'CUCharPtr',  
                         'defval' : 0,
                         'base' : 'CObjPtr',
                         'cast_ord_c' : '<unsigned char>ord(c)',
                         'cast_c' : '<unsigned char>(<char>c)',
                         'cast_val' : '<unsigned char*><char*>val',
                         'cast_chptr' : 'chptr' }

clsdcl_template = """cdef class %(clsname)s(%(base)s):
    pass
"""

ncls_seeds = [
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

def FileHeader(fname, import_text):
    return """# %s, generated by
#   $yfId$
from __future__ import absolute_import
%s
""" % (fname, import_text)
