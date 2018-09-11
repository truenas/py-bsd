cimport defs

from libc.errno cimport errno

import os


def __get_thread_id():
    cdef long id
    cdef int err
    with nogil:
        err = defs.thr_self(&id)
    if err:
        raise Exception(f'[Errorno {errno}] {os.strerror(errno)}')
    else:
        return id

def set_thread_name(str name):
    cdef long id = __get_thread_id()
    cdef int err
    name_bytes = name.encode()
    cdef char* n = name_bytes
    with nogil:
        err = defs.thr_set_name(id, n)
    if err:
        raise Exception(f'[Errorno {errno}] {os.strerror(errno)}')


def get_thread_name():
    #pid = os.getpid()
    #cdef long tid = __get_thread_id()
    #cdef _bsd.Process ps = _bsd.kinfo_getproc(pid)
    #return [v for v in ps.threads if v['id'] == tid][0]['name']
    pass
