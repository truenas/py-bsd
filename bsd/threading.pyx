cimport defs

from libc.errno cimport errno

import os


def set_thread_name(str name):
    cdef long id
    cdef int err = defs.thr_self(&id)
    if err:
        raise Exception(f'[Errorno {errno}] {os.strerror(errno)}')
    else:
        err = defs.thr_set_name(id, name.encode())
        if err:
            raise Exception(f'[Errorno {errno}] {os.strerror(errno)}')
