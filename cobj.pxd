# $yfId$
from libc.stddef cimport size_t

cdef class CObjPtr(object):
    cdef void *_c_ptr
    cdef public const char *_c_base_type
    cdef public size_t _c_esize
    cdef readonly int boundstate
    cdef public int nelms
    cdef public object elmlist
    cdef object __mdict__
    cdef object __mddict__
    cdef void _allocator(self, int n)
    cpdef _deallocator(self)
    cdef void bind(self, void *ptr, int n=?)
    cpdef unbind(self)
