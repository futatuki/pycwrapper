# $yfId$
CFLAGS	+= 	-I/usr/local/include/python2.7
LDFLAGS +=	-L/usr/local/lib
LIBS	+=	-lpython2.7

COBJS    =  cobj.c

.SUFFIXES: .pyx .pxd .so

.pyx.c:
	cython $<

.c.so:
	$(CC) -DNDEBUG $(CFLAGS) -fPIC -I/usr/local/include/python2.7 \
	    -shared -pthread \
	    -Wl,-rpath,/usr/lib:/usr/local/lib \
	    -fstack-protector $(LDFLAGS) $< $(LIBS) -o $@

all: cobj.so

cobj.c  : cobj.pyx cobj.pxd

cleanobj:
	-rm ${COBJS} *.o

clean:
	-rm ${COBJS} *.so *.o
