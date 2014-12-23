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

_boundstate_unbound      = 0
_boundstate_bound        = 1
_boundstate_selfallocate = 2

cdef class CObjPtr(object):
#    cdef void *_c_ptr
#    cdef public const char *_c_base_type
#    cdef public size_t _c_esize
#    cdef public int boundstate
#    cdef public int nelms
#    cdef object elmlist
#    cdef object __mddict__
#    cdef object __mdict__
    def __cinit__(self, nelms=1, vals=None, **m):
        self._c_ptr = NULL
        self.boundstate  = _boundstate_unbound
        self.nelms  = 0
        self.elmlist = []
        self._c_base_type = 'void'
        self._c_esize = 0
        self.__mddict__ = {}
        self.__mdict__ = {}
    def __init__(self, nelms=1, vals=None, **m):
        if nelms > 0:
            self.alloc_entity(nelms, vals, **m)
    def __getitem__(self, index):
        if self.boundstate == _boundstate_unbound:
            raise TypeError('Not bound yet')
        return self.elmlist[index]
    def __setitem__(self, index, val): 
        cdef CObjPtr ref
        cdef CObjPtr ref2
        if self.boundstate == _boundstate_unbound:
            raise TypeError('Not bound yet')
        ref = self.elmlist[index]
        if val is None:
           for k in self.__mddict__:
              ref.__setattr__(k, self.__mddict__[k])
        elif isinstance(val, dict):
            for k in val:
                if not self.__mddict__.has_key(k):
                    raise TypeError('Unknown member %s' % k)
            for k in val:
                ref.__setattr__(k, val[k])
        elif isinstance(val, self.__class__):
            ref2 = val
            for k in ref2.__mddict__:
                ref.__setattr__(k, ref2.__getattr__(k))
        else:
            raise TypeError(
                'val must be dict of member or instance of %s class'
                % self.__class__.__name__)
    def __len__(self):
        if self.boundstate == _boundstate_unbound:
            raise TypeError('Not bound yet')
        if self.nelms == 0:
            raise TypeError('length unknown')
        return self.nelms
    def __next__(self):
        if self.boundstate == _boundstate_unbound:
            raise TypeError('Not bound yet')
        if self.nelms == 0:
            raise TypeError(
                "This object don't know how many element allocated")
        if self.nelms == 1:
            raise StopIteration
        return self.elmlist[1]
    def __dealloc__(self):
        if self.boundstate == _boundstate_selfallocate:
            assert self._c_ptr is not NULL
            # Any call of instance methods is inhibited,
            # so try to call class method of _deallocator
            self.__class__._deallocator(self)
            self.boundstate = _boundstate_unbound
    cdef void _allocator(self, int n):
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
        self._c_ptr = tmp_ptr
    cpdef _deallocator(self):
        PyMem_Free(self._c_ptr)
    def values(self): 
        if self.boundstate == _boundstate_unbound:
            raise TypeError('Not bound yet')
        md = {}
        for m in self.__mddict__:
            md[m] = self.__getattr__(m)
        return md
    cdef void bind(self, void *ptr, int n=0):
        cdef int i
        cdef void * tmp_ptr
        cdef CObjPtr ref
        if self.boundstate != 0:
            raise TypeError('must do unbind() before bind()')
            # self.unbind()
        if ptr is NULL:
            raise ValueError('cannot bind NULL pointer')
        #if self.__class__.__name__ != 'CObjPtr':
        #    raise NotImplementedError()
        self._c_ptr = ptr
        if n > 0:
            self.nelms = n
            del self.elmlist[0:]
            self.elmlist.append(self)
            i = 1
            tmp_ptr = ptr + self._c_esize
            while i < n:
                ref = self.__class__(0)
                ref.bind(tmp_ptr)
                ref.nelms = n - i
                self.elmlist.append(ref)
                tmp_ptr = tmp_ptr + self._c_esize
                i = i + 1
            i = 1
            for ref in self.elmlist[1:]:
                ref.elmlist[0:] = self.elmlist[i:]
                i = i + 1
        else:
            # there is no way to know how many elements to access safely ...
            self.nelms = 0
            del self.elmlist[0:]
        self.boundstate = _boundstate_bound
    cpdef unbind(self):
        if self._c_ptr is not NULL:
            if self.boundstate == _boundstate_selfallocate:
                self.dealloc_entity()
        self._c_ptr = NULL
        self.__mdict__ = {}
        self.nelms = 0
        del self.elmlist[0:]
        self.boundstate  = _boundstate_unbound
    def alloc_entity(self, nelms=1, vals=None, **m):
        cdef void *tmp_ptr
        cdef int i
        cdef CObjPtr ref
        if self.boundstate != _boundstate_unbound:
            raise TypeError('must do unbind() before alloc_entry()')
        if nelms < 1:
            raise ValueError(
                'nelms is number of allocation units, '
                'so it must greater than 0')
        self._allocator(nelms)
        self.bind(self._c_ptr, nelms)
        self.boundstate = _boundstate_selfallocate
        # initialize allocated entity with values specified by arguments.
        #    1. argument m holds default values 
        #    2. vals holds list of values, each of element is a dict of 
        #       members to set. 
        # check default values
        dv = self.__mddict__.copy()
        try:
            if len(m):
                for k in m:
                    if not dv.has_key(k):
                        raise TypeError('Unknown member %s' % k)
                    dv[k] = m[k]
            # check and set values
            if vals is None: 
                i = 0
                while i < nelms:
                    self[i] = dv
                    i = i + 1
            elif isinstance(vals, list):
                i = 0
                for val in vals:
                    if i >= nelms:
                        break
                    if val is None:
                        self[i] = dv
                    else:
                        self[i] = val
                    i = i + 1
                while i < nelms: 
                    self[i] = dv
                    i = i + 1
            else:
                raise TypeError('vals must be lists of member dict')
        except Exception,e:
            self.dealloc_entity()
            raise e
        #
    def dealloc_entity(self):
        if self.boundstate == _boundstate_selfallocate:
            self._deallocator()
            self.boundstate = _boundstate_unbound
            self._c_ptr = NULL
            self.nelms  = 0
            del self.elmlist[0:]
