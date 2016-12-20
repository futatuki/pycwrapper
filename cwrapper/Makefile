# $yfId$
PYTHON?  =      python
CYTHON?  =      cython
CFLAGS	+= 	-I/usr/local/include/python2.7
LDFLAGS +=	-L/usr/local/lib
LIBS	+=	-lpython2.7

COBJS    =  cobj.c numptr.c

.SUFFIXES: .pyx .pxd .so

.pyx.c:
	cython $<

.c.so:
	$(CC) -DNDEBUG $(CFLAGS) -fPIC \
	    -shared -pthread \
	    -Wl,-rpath,/usr/lib:/usr/local/lib \
	    -fstack-protector $(LDFLAGS) $< $(LIBS) -o $@

all: cobj.so numptr.so

cobj.c : cobj.pyx cobj.pxd

numptr.pxd numptr.pyx: ../cnumptrgen.py
	python ../cnumptrgen.py

numptr.c : numptr.pxd numptr.pyx

cleanobj:
	-rm ${COBJS} *.o numptr.pyx numptr.pxd

clean:
	-rm ${COBJS} *.so *.o *.pyc numptr.pyx numptr.pxd

clean-extra:
	-rm -rf MANIFEST build dist 

distclean: clean clean-extra
