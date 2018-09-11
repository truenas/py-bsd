cimport defs

cdef class Process:
    cdef defs.kinfo_proc* proc
    cdef defs.procstat* ps
    cdef bint free

cpdef kinfo_getproc(pid)
