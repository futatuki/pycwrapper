# $yfId$
from libc.stddef cimport size_t
IF (    UNAME_SYSNAME == 'Linux'  or UNAME_SYSNAME == 'FreeBSD'
     or UNAME_SYSNAME == 'NetBSD' or UNAME_SYSNAME == 'OpenBSD'
     or UNAME_SYSNAME == 'Darwin' ):
    cdef extern from "strings.h":
        void bzero(void *b, size_t len)
ELSE:
    from lib.string cimport memset
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.version cimport PY_MAJOR_VERSION

cdef class CObjPtr(object):
#    cdef void *_c_ptr
#    cdef readonly int _is_const
#    cdef int _is_init
#    cdef readonly int _has_entity
#    cdef readonly const char *_c_base_type
#    cdef readonly size_t _c_esize
#    cdef readonly object entity_obj
#    cdef int _nelms
#    cdef int _nth
#    cdef dict _mddict
#    cdef dict _madict
#    cdef list _py_vals
    def __cinit__(self, int nelms=1, vals=None, int is_const=False, **m):
        self._c_ptr = NULL
        self._is_const = is_const
        self._is_init = False
        self._has_entity = False
        self.entity_obj = None
        self._nelms  = 0
        self._nth  = 0
        if is_const:
            self._c_base_type = 'const void'
        else:
            self._c_base_type = 'void'
        self._c_esize = 1
        self._mddict = {}
        self._madict = {}
        self._py_vals = [{}]
    def __init__(self, nelms=1, vals=None, int is_const=False, **m):
        cdef void *tmp_ptr
        cdef int i
        cdef CObjPtr ref
        cdef nl
        assert self._c_ptr is NULL
        if nelms == 0:
            if vals is None:
                raise ValueError(
                    'nelms is number of allocation units, '
                    'so it must greater than 0')
            else:
                try:
                    nl = len(vals)
                except TypeError:
                    raise TypeError(
                        'vals must be sequence type of elements values')
            if nl == 0:
                raise ValueError(
                    'nelms is number of allocation units, '
                    'so it must greater than 0')
        else:
            nl = nelms
        tmp_ptr = self._allocator(nl)
        self.bind(tmp_ptr, nl, 0, None, [{}] * nl, True)
        self._has_entity = True
        # initialize allocated entity with values specified by arguments.
        #    1. argument m holds default values
        #    2. vals holds list of values, each of element is a dict of
        #       members to set.
        # check default values
        dv = self._mddict.copy()
        try:
            if len(m):
                for k in m:
                    if dv.has_key(k):
                        dv[k] = m[k]
                    else:
                        if self._madict.has_key(k):
                            del dv[self._madict[k]]
                            dv[k] = m[k]
                        else:
                            raise TypeError('Unknown member %s' % k)
            # check and set values
            if vals is None:
                for i in range(nl):
                    self[i] = dv
            else:
                try:
                    is_iterable = iter(vals)
                except TypeError:
                    raise TypeError(
                        'vals must be iterable of values to set elements')
                i = 0
                for val in vals:
                    if i >= nl:
                        break
                    if val is None:
                        self[i] = dv
                    else:
                        self[i] = val
                    i = i + 1
                while i < nl:
                    self[i] = dv
                    i = i + 1
            self._is_init = True
        except Exception,e:
            self._deallocator()
            self._c_ptr = NULL
            self._nelms  = 0
            self._nth  = 0
            del self._py_vals[0:]
            self._is_init = False
            self._has_entity = False
            self.entity_obj = None
            raise e
        #
    #
    def __getitem__(self, index):
        cdef int i
        cdef void * tmpptr
        cdef CObjPtr ref
        assert self._c_ptr is not NULL
        i = index + self._nth if index >= 0 else self._nelms + index
        if i < self._nth or i >= self._nelms:
            raise IndexError('array index out of range')
        tmpptr = self._c_ptr + self._c_esize * (i - self._nth)
        ref = self.__class__.__new__(self.__class__, is_const = self._is_const)
        ref.bind(tmpptr, self._nelms, i,
                    self if self._has_entity else self.entity_obj,
                    self._py_vals, False)
        return ref
    def __setitem__(self, index, val):
        cdef CObjPtr ref
        cdef CObjPtr ref2
        assert self._c_ptr is not NULL
        if self._is_const and self._is_init:
            raise TypeError('Pointer points const value. Cannot alter')
        ref = self[index]
        ref._is_const = False
        if val is None:
            for k in self._mddict:
               ref.__setattr__(k, self._mddict[k])
        elif isinstance(val, dict):
            for k in val:
                if ( not self._mddict.has_key(k)
                        and not self._madict.has_key(k) ):
                    raise TypeError('Unknown member %s' % k)
            for k in val:
                ref.__setattr__(k, val[k])
        elif isinstance(val, self.__class__):
            ref2 = val
            for k in ref._mddict:
                ref.__setattr__(k, ref2.__getattr__(k))
        else:
            raise TypeError(
                'val must be dict of member or instance of %s class'
                % self.__class__.__name__)
    def __len__(self):
        assert self._c_ptr is not NULL
        if self._nelms == 0:
            raise TypeError('length unknown')
        return self._nelms - self._nth
    def __next__(self):
        assert self._c_ptr is not NULL
        if self._nelms == 0:
            raise TypeError(
                "This object don't know how many element allocated")
        if self._nelms - self._nth == 1:
            raise StopIteration
        return self[1]
    def __dealloc__(self):
        if self._has_entity:
            assert self._c_ptr is not NULL
            self._deallocator()
            self._has_entity = False
    cdef void * _allocator(self, int n):
        cdef void *tmp_ptr
        tmp_ptr = PyMem_Malloc(self._c_esize * n)
        if tmp_ptr is NULL:
            raise MemoryError()
        IF (    UNAME_SYSNAME == 'Linux'  or UNAME_SYSNAME == 'FreeBSD'
             or UNAME_SYSNAME == 'NetBSD' or UNAME_SYSNAME == 'OpenBSD'
             or UNAME_SYSNAME == 'Darwin' ):
            bzero(tmp_ptr, self._c_esize * n)
        ELSE:
            memset(tmp_ptr, 0, self._c_esize * n)
        return tmp_ptr
    cdef _deallocator(self):
        PyMem_Free(self._c_ptr)
    def values(self):
        assert self._c_ptr is not NULL
        md = {}
        for m in self._mddict:
            md[m] = self.__getattr__(m)
        return md
    cdef void bind(self, void *ptr, int n=0, int nth=0,
                entity_obj=None, list py_vals=[{}], int flg_keep=False):
        cdef int i
        cdef void * tmp_ptr
        cdef CObjPtr ref
        assert self._c_ptr is NULL
        if ptr is NULL:
            raise ValueError('cannot bind NULL pointer')
        self._c_ptr = ptr
        self.entity_obj = entity_obj
        if n < 0:
            raise ValueError('number of elements must 0 or positive value')
        self._nelms = n
        self._nth = nth
        self._py_vals = py_vals
        self._is_init = not flg_keep
    def cast(self, type t, int is_const=False):
        cdef CObjPtr ref
        assert self._c_ptr is not NULL
        if ( t is not CObjPtr and
                not t in CObjPtr.__subclasses__() ):
            raise TypeError('cast type must be the CObjPtr or its subclass')
        ref = t.__new__(t,is_const=is_const)
        ref.bind(self._c_ptr, 0, 0,
                self if self._has_entity else self.entity_obj, [{}], False)
        return ref

cdef class CPtrPtr(CObjPtr):
    def __cinit__(self, int nelms=1, vals=None, int is_const=False, **m):
        cdef object base_type_name
        self._is_const     = is_const
        #self._ptr_class    = CObjPtr
        #self._ptr_is_const = False
        #base_type_name = (
        #       self._ptr_class.__new__(CObjPtr, False)._c_base_type
        #       + (' const *' if is_const else '*'))
        #self._c_base_type  = base_type_name
        self._c_esize = sizeof(void *)
        self._mddict = { 'p_' : None }
    property p_:
        def __get__(self):
            cdef void * tmp_ptr
            cdef CObjPtr p_
            cdef object mdict
            cdef object val
            assert self._c_ptr is not NULL
            tmp_ptr =  (<void**>(self._c_ptr))[0]
            if tmp_ptr is NULL:
                self._py_vals[self._nth] = {}
                return None
            else:
                mdict = self._py_vals[self._nth]
                # assert mdict is not None
                if mdict is None:
                    val = None
                else:
                    val = mdict.get('p_', None)
                if val is not None:
                    p_ = val
                    if p_._c_ptr == tmp_ptr:
                        return p_
                p_ = self._ptr_class.__new__(
                       self._ptr_class, is_const=self._ptr_is_const)
                p_.bind(tmp_ptr,1,0,None,[{}],False)
                self._py_vals[self._nth] = {'p_': p_}
                return p_
        def __set__(self,val):
            cdef CObjPtr ref
            assert self._c_ptr is not NULL
            if self._is_const and self._is_init:
                raise TypeError('Pointer points const value. Cannot alter')
            if val is None:
                self._py_vals[self._nth] = {}
                (<void**>(self._c_ptr))[0] = NULL
            else:
                if not isinstance(val,self._ptr_class):
                    raise TypeError('attribute p_ must be a %s instance' %
                            self._ptr_class.__name__)
                ref = val
                if not ref._is_init:
                    raise ValueError('p_ must be a %s bounded instance' %
                            self._ptr_class.__name__)
                else:
                    self._py_vals[self._nth] = {'p_': ref}
                    (<void**>(self._c_ptr))[0] = ref._c_ptr
            #
        def __del__(self):
            assert self._c_ptr is not NULL
            self._py_vals[self._nth] = None
            (<void**>(self._c_ptr))[0] = NULL

def genPtrClass(type base_class, int base_is_const=False):
    def __new__(cls, int nelms=1, vals=None, int is_const=False, **m):
        cdef object base_type_name
        cdef CPtrPtr ref
        ref = CPtrPtr.__new__(cls)
        ref._is_const     = is_const
        ref._ptr_class    = base_class
        ref._ptr_is_const = base_is_const
        base_type_name = (
               base_class.__new__(base_class,
                               is_const=base_is_const)._c_base_type
               + (' const *' if is_const else '*'))
        ref._c_base_type  = base_type_name
        ref._c_esize = sizeof(void *)
        ref._mddict = { 'p_' : None }
        return ref
    if ( base_class is not CObjPtr and
            not base_class in CObjPtr.__subclasses__() ):
        raise TypeError('base class must be the CObjPtr or its subclass')
    attrdict = {'__new__' : staticmethod(__new__)}
    return type(base_class.__name__ + 'Ptr', (CPtrPtr, ), attrdict)

cdef class CCharPtr(CObjPtr):
    def __cinit__(self, int nelms=1, vals=None, int is_const=False, **m):
        if is_const:
            self._c_base_type = 'const char'
        else:
            self._c_base_type = 'char'
        self._c_esize = sizeof(char)
        self._mddict = { 'p_' : 0 }
        self._madict = { 's_' : 'p_' }
    def __init__(self, int nelms=1, vals=None, int is_const=False, **m):
        cdef void * tmp_ptr
        cdef object tmp_vals
        if ( (PY_MAJOR_VERSION < 3 and isinstance(vals, str))
                or (PY_MAJOR_VERSION >= 3 and isinstance(vals, bytes)) ):
            if is_const and nelms == 0:
                self._py_vals = [{ 's_': vals }] + ([{}] * len(vals))
                tmp_ptr = <void*><char*>vals
                self.bind(tmp_ptr, len(vals) + 1, 0,
                            vals, self._py_vals, False)
            else:
                tmp_vals = [ {'p_': <char>(<unsigned char>ord(c)) }
                                for c in vals ] + [ {'p_' : 0 } ]
                CObjPtr.__init__(self, nelms, tmp_vals, is_const, **m)
        else:
            CObjPtr.__init__(self, nelms, vals, is_const, **m)
    property p_:
        def __get__(self):
            assert self._c_ptr is not NULL
            return (<char*>(self._c_ptr))[0]
        def __set__(self,val):
            assert self._c_ptr is not NULL
            if self._is_const and self._is_init:
                raise TypeError('Pointer points const value. Cannot alter')
            (<char*>(self._c_ptr))[0] = val
        def __del__(self):
            assert self._c_ptr is not NULL
            (<char*>(self._c_ptr))[0] = 0
    property s_:
        def __get__(self):
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
        def __set__(self,val):
            cdef CCharPtr ref
            cdef int i, slen
            cdef char* chptr
            cdef char c
            assert self._c_ptr is not NULL
            if self._is_const and self._is_init:
                raise TypeError('Pointer points const value. Cannot alter')
            chptr = val
            slen = len(val) + 1
            i = 0
            while i < self._nelms - self._nth - 1 and i < slen:
                c = (<char*>chptr)[i]
                if c == 0:
                    break
                (<char*>(self._c_ptr))[i] = c
                i = i + 1
            (<char*>(self._c_ptr))[i] = 0
        def __del__(self):
            assert self._c_ptr is not NULL
            (<char *>(self._c_ptr))[0] = 0

cdef class CUCharPtr(CObjPtr):
    def __cinit__(self, int nelms=1, vals=None, int is_const=False, **m):
        if is_const:
            self._c_base_type = 'const unsigned char'
        else:
            self._c_base_type = 'unsigned char'
        self._c_esize = sizeof(unsigned char)
        self._mddict = { 'p_' : 0 }
        self._madict = { 's_' : 'p_' }
    def __init__(self, int nelms=1, vals=None, int is_const=False, **m):
        cdef void * tmp_ptr
        cdef object tmp_vals
        if ( (PY_MAJOR_VERSION < 3 and isinstance(vals, str))
                or (PY_MAJOR_VERSION >= 3 and isinstance(vals, bytes)) ):
            if is_const and nelms == 0:
                self._py_vals = [{ 's_': vals }] + ([{}] * len(vals))
                tmp_ptr = <void*><char*>vals
                self.bind(tmp_ptr, len(vals) + 1, 0,
                            vals, self._py_vals, False)
            else:
                tmp_vals = [ {'p_': ord(c) }
                                for c in vals ] + [ {'p_' : 0 } ]
                CObjPtr.__init__(self, nelms, tmp_vals, is_const, **m)
        else:
            CObjPtr.__init__(self, nelms, vals, is_const, **m)
    property p_:
        def __get__(self):
            assert self._c_ptr is not NULL
            return (<unsigned char*>(self._c_ptr))[0]
        def __set__(self,val):
            assert self._c_ptr is not NULL
            if self._is_const and self._is_init:
                raise TypeError('Pointer points const value. Cannot alter')
            (<unsigned char*>(self._c_ptr))[0] = val
        def __del__(self):
            assert self._c_ptr is not NULL
            (<char*>(self._c_ptr))[0] = 0
    property s_:
        def __get__(self):
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
        def __set__(self,val):
            cdef CCharPtr ref
            cdef int i, slen
            cdef unsigned char* chptr
            cdef unsigned char c
            assert self._c_ptr is not NULL
            if self._is_const and self._is_init:
                raise TypeError('Pointer points const value. Cannot alter')
            chptr = <unsigned char*><char*>val
            slen = len(val) + 1
            i = 0
            while i < self._nelms - self._nth - 1 and i < slen:
                c = chptr[i]
                if c == 0:
                    break
                (<unsigned char*>(self._c_ptr))[i] = c
                i = i + 1
            (<unsigned char*>(self._c_ptr))[i] = 0
        def __del__(self):
            assert self._c_ptr is not NULL
            (<unsigned char *>(self._c_ptr))[0] = 0
