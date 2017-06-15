# $yfId$
PYTHON?  =      python
CYTHON?  =      cython
CFLAGS	+= 	-I/usr/local/include/python2.7
LDFLAGS +=	-L/usr/local/lib
LIBS	+=	-lpython2.7

COBJS    =  cobj.c primptr.c genprimptr.c

.SUFFIXES: .pyx .pxd .so

.pyx.c:
	cython $<

.c.so:
	$(CC) -DNDEBUG $(CFLAGS) -fPIC \
	    -shared -pthread \
	    -Wl,-rpath,/usr/lib:/usr/local/lib \
	    -fstack-protector $(LDFLAGS) $< $(LIBS) -o $@

all: cobj.so primptr.so genprimptr.so

cobj.c : cobj.pyx cobj.pxd

primptr.pyx primptr.pxd genprimptr.pyx: ../primptrgen.py generator.py
	$(PYTHON) ../primptrgen.py

primptr.c : primptr.pyx primptr.pxd

genprimptr.c : genprimptr.pyx

cleanobj:
	-rm ${COBJS} *.o *.pyc primptr.pxd primptr.pyx genprimptr.pyx

clean:
	-rm ${COBJS} *.so *.o *.pyc primptr.pxd primptr.pyx genprimptr.pyx

clean-extra:
	-rm -rf __pycache__ ../MANIFEST ../build ../dist ../__pycache__ \
		../*.pyc 

distclean: clean clean-extra
