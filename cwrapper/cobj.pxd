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
    cdef int _nelms
    cdef int _nth
    cdef dict _opts
    cdef dict _mddict
    cdef dict _madict
    cdef list _py_vals
    cdef object __weakref__
    cdef void bind(self, void *ptr, int n=?, int nth=?,
             object entity_obj=?, list py_vals=?)

cdef class CPtrPtr(CObjPtr):
    cdef type _ptr_class
    cdef int _ptr_is_const
#   for debug
#    cdef public object _ptr_class
#    cdef public object _ptr_is_const

cdef genPtrClass(type base_class, int base_is_const=?)
