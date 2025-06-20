# $yfId$
from libc.stddef cimport size_t
from posix.strings cimport bzero
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
import weakref

cdef object ptr_to_bytes(void *ptr):
    cdef char * s
    s = <char*>&ptr
    return s[:sizeof(void*)]
cdef void * bytes_to_ptr(object bptr):
    cdef char * s
    if isinstance(bptr, bytes):
        s = bptr
        return (<void **>s)[0]
    else:
        raise TypeError('bptr must str/bytes type')

def CObjToPtrValue(CObjPtr obj):
    return ptr_to_bytes(obj._c_ptr)

def PtrValueToCObj(val, type objtype=CObjPtr,
        int is_const=False, int nelms=1, entity_obj=None):
    cdef CObjPtr obj
    if not issubclass(objtype, CObjPtr):
        raise TypeError('objtype must be CObjPtr or its derivatives')
    obj = objtype.__new__(objtype, val=None, is_const=is_const,
            vals=None, nelms=nelms)
    obj.bind(bytes_to_ptr(val), nelms, 0, entity_obj, [{}] * nelms)
    return obj

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
#    cdef dict _opts
#    cdef dict _mddict
#    cdef dict _madict
#    cdef list _py_vals
#    cdef object __weakref__
    # C type name to wrapper dict
    _typedict = {'void': CObjPtr}
    # for custom argments of constructer
    _copts = {}
    def __cinit__(self, val=None, int is_const=False, vals=None,
            int nelms=0, **m):
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
        self._opts = self.__class__._copts.copy()
        self._mddict = {}
        self._madict = {}
        self._py_vals = [{}]
    def __init__(self, val=None, int is_const=False, vals=None,
            int nelms=0, **m):
        cdef void *tmp_ptr
        cdef int i
        cdef CObjPtr ref
        cdef int nl
        assert self._c_ptr is NULL
        dv = val if val is not None else self._mddict.copy()
        for k in m:
            if k in self._opts:
                self._opts[k] = m[k]
            elif k in dv:
                dv[k] = m[k]
            elif k in self._madict:
                if isinstance(list, self._madict[k]):
                    for ak in self._madict[k]:
                        if ak in dv:
                            del dv[self._madict[ak]]
                else:
                    if self._madict[k] in dv:
                        del dv[self._madict[k]]
                dv[k] = m[k]
            else:
                raise TypeError('Unknown member %s' % k)
        if nelms:
            nl = nelms
        else:
            if vals is not None:
                nl = len(vals)
                if nl == 0:
                    nl = 1
            else:
                nl = 1
        self.__class__._allocate(self, nl)
        self._nelms = nl
        self._nth = 0
        self._has_entity = True
        self._py_vals = [{}] * nl
        # initialize allocated entity with values specified by arguments.
        #    1. dict dv holds default values
        #    2. vals holds list of values, each of element is a dict of
        #       members to set.
        # check default values
        try:
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
                for v in vals:
                    if i >= nl:
                        break
                    if v is None:
                        v = dv
                    self[i] = v
                    i = i + 1
                while i < nl:
                    self[i] = dv
                    i = i + 1
            self._is_init = True
        except Exception,e:
            self.__class__._deallocate(self)
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
    def __richcmp__(CObjPtr self, b, op):
        if op == 0:
            return super.__lt__(b)
        if op == 1:
            if isinstance(b, CObjPtr):
                return (  (    self._c_base_type == b._c_base_type
                           and self._c_ptr == (<CObjPtr>b)._c_ptr)
                        or super.__lt__(b) )
            else:
                return super.__lt__(b)
        if op == 2:
            if isinstance(b, CObjPtr):
                return (    self._c_base_type == b._c_base_type
                        and self._c_ptr == (<CObjPtr>b)._c_ptr)
            else:
                return False
        if op == 3:
            if isinstance(b, CObjPtr):
                return not (    self._c_base_type == b._c_base_type
                            and self._c_ptr == (<CObjPtr>b)._c_ptr)
            else:
                return True
        if op == 4:
            return super.__gt__(b)
        if op == 5:
            if isinstance(b, CObjPtr):
                return (  (    self._c_base_type == b._c_base_type
                           and self._c_ptr == (<CObjPtr>b)._c_ptr)
                        or super.__gt__(b) )
            else:
                return super.__gt__(b)

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
                    self._py_vals)
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
                if ( not k in self._mddict
                        and not k in self._madict ):
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
            self.__class__._deallocate(self)
            self._has_entity = False
    def values(self):
        assert self._c_ptr is not NULL
        md = {}
        for m in self._mddict:
            md[m] = self.__getattr__(m)
        return md
    cdef void bind(self, void *ptr, int n=0, int nth=0,
                entity_obj=None, list py_vals=[{}]):
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
        self._is_init = True
    def cast(self, type t, int is_const=False):
        cdef CObjPtr ref
        assert self._c_ptr is not NULL
        if not issubclass(t, CObjPtr):
            raise TypeError('cast type must be the CObjPtr or its subclass')
        ref = t.__new__(t,is_const=is_const)
        ref.bind(self._c_ptr, 0, 0,
                self if self._has_entity else self.entity_obj, [{}])
        return ref
    # for allocater methods
    _allocated = {}
    @staticmethod
    def _default_allocater(CObjPtr obj, int n):
        cdef void *tmp_ptr
        tmp_ptr = PyMem_Malloc(obj._c_esize * n)
        if tmp_ptr is NULL:
            raise MemoryError()
        bzero(tmp_ptr, obj._c_esize * n)
        obj._c_ptr = tmp_ptr
    @staticmethod
    def _default_deallocater(CObjPtr obj):
        PyMem_Free(obj._c_ptr)
    _allocater_method = [(_default_allocater, _default_deallocater)]
    @classmethod
    def _allocate(cls, CObjPtr obj, int nl):
        allocater, deallocater = cls._allocater_method[0]
        allocater(obj, nl)
        cls._allocated[CObjToPtrValue(obj)] = deallocater
    @classmethod
    def _deallocate(cls, CObjPtr obj):
        cdef object ptrval
        ptrval = CObjToPtrValue(obj)
        cls._allocated[ptrval](obj)
        del cls._allocated[ptrval]
    @classmethod
    def set_allocater_method(cls, allocater, deallocater):
        cls._allocater_method[0] = (allocater, deallocater)

cdef class CPtrPtr(CObjPtr):
    def __cinit__(self, val=None, int is_const=False, vals=None,
            int nelms=0, **m):
        cdef object base_type_name
        self._is_const     = is_const
        #self._ptr_class    = CObjPtr
        #self._ptr_is_const = False
        #base_type_name = (
        #       self._ptr_class.__new__(CObjPtr, is_const=False)._c_base_type
        #       + (' const *' if is_const else '*'))
        #self._c_base_type  = base_type_name
        self._c_esize = sizeof(void *)
        self._mddict = { 'p_' : None }
    @property
    def p_(self):
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
            p_.bind(tmp_ptr,1,0,None,[{}])
            self._py_vals[self._nth] = {'p_': p_}
            return p_
    @p_.setter
    def p_(self, val):
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
    @p_.deleter
    def p_(self):
        assert self._c_ptr is not NULL
        self._py_vals[self._nth] = None
        (<void**>(self._c_ptr))[0] = NULL

cdef genPtrClass(type base_class, int base_is_const=False):
    def __new__(cls, val=None, int is_const=False, vals=None,
                int nelms=0, **m):
        cdef object base_type_name
        cdef CPtrPtr ref
        ref = CPtrPtr.__new__(cls, is_const=is_const)
        ref._ptr_class    = base_class
        ref._ptr_is_const = base_is_const
        base_type_name = (
               base_class.__new__(base_class,
                               is_const=base_is_const)._c_base_type
               + (b' const *' if is_const else b'*'))
        # base_type_name is a temporary for this function, so keep reference
        ref._b_base_type = <bytes>base_type_name
        ref._c_base_type = base_type_name
        ref._c_esize = sizeof(void *)
        ref._mddict = { 'p_' : None }
        return ref
    if not issubclass(base_class,CObjPtr):
        raise TypeError('base class must be the CObjPtr or its subclass')
    attrdict = {'__new__' : staticmethod(__new__)}
    return type(base_class.__name__ + 'Ptr', (CPtrPtr, ), attrdict)

# enum type class generator
def gen_enum(etypename, valuedict, defaultvalue,
        initfunc = None,
        intfunc = (lambda self : getattr(self, 'value')),
        strfunc = (lambda self :
                    getattr(self, '_revdict')[getattr(self, 'value')]),
        reprfunc = (
            lambda self :
                '<' + getattr(getattr(self, '__class__'), '__name__') + '.'
                    + getattr(getattr(self, '__class__'),
                                '_revdict')[getattr(self,'value')] + '>'),
        ltfunc = (lambda self, val : int(self) <  int(val)),
        lefunc = (lambda self, val : int(self) <= int(val)),
        eqfunc = (lambda self, val : int(self) == int(val)),
        nefunc = (lambda self, val : int(self) != int(val)),
        gtfunc = (lambda self, val : int(self) >  int(val)),
        gefunc = (lambda self, val : int(self) >= int(val)),
        attrdict = None):
    valdict = {}
    revdict = {}
    if attrdict is None:
        _attrdict = {}
    elif isinstance(attrdict, dict):
        _attrdict = attrdict.copy()
    else:
        raise TypeError('attrdict should be a dict')
    for vdkey in valuedict.keys():
        _attrdict[str(vdkey)] = int(valuedict[vdkey])
        valdict[str(vdkey)] = int(valuedict[vdkey])
        revdict[int(valuedict[vdkey])] = str(vdkey)
    _attrdict['_valdict'] = valdict.copy()
    _attrdict['_revdict'] = revdict
    if initfunc is not None:
        _attrdict['__init__'] = initfunc
    else:
        def __init__(self, val=defaultvalue):
            if isinstance(val, getattr(self, '__class__')):
                setattr(self, 'value' , getattr(val, 'value'))
            else:
                try:
                    setattr(self, 'value' ,
                        getattr(getattr(self, '__class__'),'_valdict')[
                            getattr(getattr(self,'__class__'),
                                                    '_revdict')[int(val)]])
                except (ValueError, TypeError, KeyError):
                    try:
                        setattr(self, 'value',
                            getattr(getattr(self,'__class__'),
                                    '_valdict')[str(val)])
                    except (ValueError, TypeError, KeyError):
                        raise ValueError(
                            'init value %s is not valid' % repr(val))
        _attrdict['__init__'] = __init__
    _attrdict['__int__'] = intfunc
    _attrdict['__str__'] = strfunc
    _attrdict['__repr__'] = reprfunc
    _attrdict['__lt__'] = ltfunc
    _attrdict['__le__'] = lefunc
    _attrdict['__eq__'] = eqfunc
    _attrdict['__ne__'] = nefunc
    _attrdict['__gt__'] = gtfunc
    _attrdict['__ge__'] = gefunc
    return type(etypename, (object,), _attrdict.copy())
