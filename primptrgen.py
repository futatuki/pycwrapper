#!/usr/bin/env python
# $yfId$
import os
import sys

src_path=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cwrapper')
sys.path.insert(0,src_path)

from generator import GenStaticClsSrcFile, GenDynamicClsSrcFile

cobj_import_text="from .cobj cimport CObjPtr\n"
bcls_text="CObjPtr"

def main():
    GenStaticClsSrcFile(prefix=src_path, fname='primptr',
        import_text=cobj_import_text, base=bcls_text)
    GenDynamicClsSrcFile(prefix=src_path, fname='genprimptr',
        import_text=cobj_import_text)

if __name__ == "__main__":
    main()
