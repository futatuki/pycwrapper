# $yfId$
from libc.stddef cimport size_t

cdef class CObjPtr(object):
    cdef void *_c_ptr
    cdef public const char *_c_base_type
    cdef public size_t _c_esize
    cdef readonly int boundstate
    cdef readonly object entity_obj
    cdef public int nelms
    cdef public list elmlist
    cdef dict __mdict__
    cdef dict __mddict__
    cdef _allocator(self, int n)
    cdef _deallocator(self)
    cdef void bind(self, void *ptr, int n=?, object entity_obj=?)
    cpdef unbind(self)

cdef class CPtrPtr(CObjPtr):
    cdef type ptr_class 
