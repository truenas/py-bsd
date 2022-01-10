cdef extern from "sys/disk.h":
    enum:
        DIOCGSECTORSIZE
        DIOCGMEDIASIZE
        DIOCGIDENT
