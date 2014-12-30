# $yfId$
from libc.stddef cimport size_t

cdef class CObjPtr(object):
    cdef void *_c_ptr
    cdef readonly int _is_const
    cdef int _is_init
    cdef readonly int _has_entity
    cdef readonly const char *_c_base_type
    cdef readonly size_t _c_esize
    cdef readonly object entity_obj
    cdef public int nelms
    cdef dict __mdict__
    cdef dict __mddict__
    cdef void * _allocator(self, int n)
    cdef _deallocator(self)
    cdef void bind(self, void *ptr, int n=?,
                         object entity_obj=?, int flg_keep=?)

cdef class CPtrPtr(CObjPtr):
    cdef type ptr_class 
