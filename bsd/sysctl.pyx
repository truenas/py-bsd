"""
Cython sysctl bindings

Copyright (c) 2011-2012 Garrett Cooper, All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL Garrett Cooper OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.
"""

import os
import types

from libc.stdlib cimport free, malloc
from libc.string cimport memcpy, strcpy
from libc.errno cimport *
from cpython cimport array as c_array
from array import array

cimport cython
cimport defs

# XXX: sys/sysctl.h
CTLTYPE = 0xf
CTLTYPE_INT = 2
CTLTYPE_STRING = 3
CTLTYPE_S64 = 4
CTLTYPE_UINT = 6
CTLTYPE_LONG = 7
CTLTYPE_ULONG = 8
CTLTYPE_U64 = 9

CTLTYPE_INTEGERS = [
                    CTLTYPE_INT,
                    CTLTYPE_UINT,
                    ]

CTLTYPE_LONGS = [
                 CTLTYPE_S64,
                 CTLTYPE_LONG,
                 CTLTYPE_ULONG,
                 CTLTYPE_U64,
                 ]

CTLTYPE_ALL_INTEGERS = CTLTYPE_INTEGERS + CTLTYPE_LONGS

CTL_MAXNAME = 24


cdef extern from "errno.h":
    # XXX: this is wrong per POSIX spec.
    extern int errno


# XXX: stdio.h
DEF BUFSIZ = 1024

def sysctl(name, old=True, new=None):
    """Wrapper for sysctl(3) API.

    :Parameters:
        - name (int list): an array of integers which represent the MIB
                           OID, e.g.

                           # 4 = CTL_NET; 17 = PF_ROUTE; 1 = NET_RT_DUMP
                           [ 4, 17, 0, 0, 1, 0 ]

        - new (object): new value for sysctl or None if the value isn't
                        supposed to be changed.
        - old (bool): a boolean value to note whether or not the old
                      value should be queried and returned.

    :Raises:
        OSError: the sysctl(3) call failed according to one of the
                 ERRORS noted in the manpage.
        ValueError: an invalid value is provided for the 'name'
                    parameter.

    :Returns:
        a character buffer (str) corresponding to the value returned
        when querying the sysctl by the OID represented by 'name' and
        'old=True'. 'None' otherwise.

    """

    cdef:
        char *buf
        char *newp_s
        int *namep
        int *namet
        void *newp
        void *oldp
        size_t buflen
        size_t newlen
        size_t oldlen
        int new_i
        char c

    buf = NULL
    buflen = BUFSIZ
    namep = NULL
    namet = NULL
    newp_s = NULL
    oldp = NULL

    if not name:
        raise ValueError("'name' must be a non-zero length iterable object")

    try:
        buf = <char*>malloc(sizeof(char) * BUFSIZ)
        if not buf:
            raise MemoryError()

        namep = <int*>malloc(sizeof(int) * (len(name)))
        if not namep:
            raise MemoryError()

        # Administrative functions for determining the type add an additional
        # 2 elements to the OID.
        namet = <int*>malloc(sizeof(int) * (len(name) + 2))
        if not namet:
            raise MemoryError()

        namet[0] = 0
        namet[1] = 4

        for i, n in enumerate(name):
            namep[i] = n
            namet[i + 2] = n

        ret = defs.sysctl(namet, len(name)+2, buf, &buflen, NULL, 0)
        if ret == -1:
            raise OSError(errno, os.strerror(errno))
        sysctl_type = (<int*>buf)[0] & CTLTYPE

        if new is None:
            newp = NULL
            newlen = 0
        else:
            if sysctl_type in CTLTYPE_ALL_INTEGERS:
                new_i = new
                newp = <void*>&new_i

                if sysctl_type in CTLTYPE_INTEGERS:
                    newlen = sizeof(int)
                else:
                    newlen = sizeof(long)
            else:
                if sysctl_type == CTLTYPE_STRING:
                    newlen = len(new) + 1
                else:
                    newlen = len(new)
                # String or opaque
                newp_s = <char*>malloc(sizeof(char) * newlen)
                if not newp_s:
                    raise MemoryError()
                # NOTE: void* cast does the wrong thing here.
                memcpy(newp_s, <char*>new, newlen)
                newp = <void*>newp_s

        if old:
            # Allocate storage for the old data.
            ret = defs.sysctl(namep, len(name), oldp, &oldlen, NULL, 0)
            if ret == -1:
                raise OSError(errno, os.strerror(errno))
            oldp = malloc(oldlen)
            if not oldp:
                raise MemoryError()
        else:
            oldp = NULL
            oldlen = 0

        ret = defs.sysctl(namep, len(name), oldp, &oldlen, newp, newlen)
        if ret == -1:
            raise OSError(errno, os.strerror(errno))

        if oldp:
            if sysctl_type in CTLTYPE_INTEGERS:
                return (<int*>oldp)[0]
            elif sysctl_type in CTLTYPE_LONGS:
                return (<long*>oldp)[0]
            elif sysctl_type == CTLTYPE_STRING:
                old_arr = <char*>oldp
                return old_arr
            else:
                return [(<char*>oldp)[i] for i in range(oldlen)]
    finally:
        free(buf)
        free(namep)
        free(namet)
        free(newp_s)
        free(oldp)


def sysctlbyname(name, old=True, new=None):
    """Wrapper for sysctlbyname(3) API.

    :Parameters:
        - name (str): a textual representation of the OID, e.g.
                      'hw.machine'.
        - new (object): new value for sysctl or None if the value isn't
                        supposed to be changed.
        - old (bool): a value to note whether or not the old value
                      should be queried and returned.

    :Raises:
        OSError: the sysctlbyname(3) call failed according to one of the
                 ERRORS noted in the manpage.
        ValueError: an invalid value is provided for the 'name'
                    parameter.

    :Returns:
        a buffer 'array' corresponding to the value returned by when
        querying the textual representation of the sysctl by 'name'.

    """

    cdef:
        char *buf
        char *namep
        char *newp_s
        int *mibp
        int *namet
        void *newp
        void *oldp
        size_t buflen
        size_t newlen
        size_t oldlen
        size_t _size
        int new_i
        char c

    buf = NULL
    buflen = BUFSIZ
    namep = name
    namet = NULL
    newp_s = NULL
    oldp = NULL
    _size = CTL_MAXNAME

    if not name:
        raise ValueError("'name' must be a non-zero length iterable object")

    try:
        mibp = <int*>malloc(sizeof(int) * (CTL_MAXNAME))
        if not mibp:
            raise MemoryError()

        ret = defs.sysctlnametomib(namep, mibp, &_size)
        if ret == -1:
            raise OSError(errno, os.strerror(errno))

        buf = <char*>malloc(sizeof(char) * BUFSIZ)
        if not buf:
            raise MemoryError()

        # Administrative functions for determining the type add an additional
        # 2 elements to the OID.
        namet = <int*>malloc(sizeof(int) * (_size + 2))
        if not namet:
            raise MemoryError()

        namet[0] = 0
        namet[1] = 4

        for i in range(_size):
            namet[i + 2] = mibp[i]

        ret = defs.sysctl(namet, _size + 2, buf, &buflen, NULL, 0)
        if ret == -1:
            raise OSError(errno, os.strerror(errno))
        sysctl_type = (<int*>buf)[0] & CTLTYPE

        if new is None:
            newp = NULL
            newlen = 0
        else:
            if sysctl_type in CTLTYPE_ALL_INTEGERS:
                new_i = new
                newp = <void*>&new_i

                if sysctl_type in CTLTYPE_INTEGERS:
                    newlen = sizeof(int)
                else:
                    newlen = sizeof(long)
            else:
                if sysctl_type == CTLTYPE_STRING:
                    newlen = len(new) + 1
                else:
                    newlen = len(new)
                # String or opaque
                newp_s = <char*>malloc(sizeof(char) * newlen)
                if not newp_s:
                    raise MemoryError()
                # NOTE: void* cast does the wrong thing here.
                memcpy(newp_s, <char*>new, newlen)
                newp = <void*>newp_s

        if old:
            # Allocate storage for the old data.
            ret = defs.sysctl(mibp, _size, NULL, &oldlen, NULL, 0)
            if ret == -1:
                raise OSError(errno, os.strerror(errno))
            oldlen += BUFSIZ * 16
            oldp = malloc(oldlen)
            if not oldp:
                raise MemoryError()
        else:
            oldp = NULL
            oldlen = 0

        ret = defs.sysctl(mibp, _size, oldp, &oldlen, newp, newlen)
        if ret == -1:
            raise OSError(errno, os.strerror(errno))

        if oldp:
            if sysctl_type in CTLTYPE_INTEGERS:
                return (<int*>oldp)[0]
            elif sysctl_type in CTLTYPE_LONGS:
                return (<long*>oldp)[0]
            elif sysctl_type == CTLTYPE_STRING:
                old_arr = <char*>oldp
                return old_arr
            else:
                return [(<char*>oldp)[i] for i in range(oldlen)]
    finally:
        free(buf)
        free(mibp)
        free(namet)
        free(newp_s)
        free(oldp)


def sysctlnametomib(name, size=CTL_MAXNAME):
    """Wrapper for sysctlnametomib(3) API.

    :Parameters:
        - name (str): a textual representation of the OID, e.g.
                      'hw.machine'.
        - size (int): an optional value to pass in to limit the returned OID
                      to n elements. Defaults to 'CTL_MAXNAME'.

    :Raises:
        OSError: the sysctlnametomib(3) call failed according to one of
                 the ERRORS noted in the manpage.
        ValueError: an invalid value is provided for the 'name'
                    parameter.
        ValueError: the value provided for 'size' was not greater than 0.
    :Returns:
        A list of integers corresponding to the MIB OID for pointed by
        the parameter, 'name'.

    """

    cdef:
        char *namep
        int *mibp
        size_t _size

    _size = size
    namep = name

    if not name:
        raise ValueError("'name' must be a non-zero length iterable object")

    if size <= 0:
        raise ValueError("'size' must be greater than or equal to 1")

    mibp = <int*>malloc(sizeof(int) * (_size))
    if not mibp:
        raise MemoryError()

    try:
        ret = defs.sysctlnametomib(namep, mibp, &_size)
        if ret == -1:
            raise OSError(errno, os.strerror(errno))
        return [mibp[i] for i in range(_size)]
    finally:
        free(mibp)


def sysctlmibtoname(mib):
    cdef:
        c_array.array c_mib
        int name[22]
        char ret[256]
        size_t l1
        size_t l2

    name[0] = 0
    name[1] = 1
    l1 = len(mib) + 2
    l2 = cython.sizeof(ret)

    c_mib = array('i', mib)
    memcpy(&name[2], c_mib.data.as_voidptr, len(mib) * cython.sizeof(int))
    if defs.sysctl(name, l1, ret, &l2, NULL, 0) < 0:
        raise OSError(errno, os.strerror(errno))

    return ret[:l2 - 1]


def filter(name=None):
    cdef:
        c_array.array mib
        int name1[22]
        int name2[22]
        size_t l1
        size_t l2

    name1[0] = 0
    name1[1] = 2

    l1 = 2
    if name:
        mib = array('i', sysctlnametomib(name))
    else:
        mib = array('i', [])

    memcpy(&name1[2], mib.data.as_voidptr, len(mib) * cython.sizeof(int))
    l1 += len(mib)

    while True:
        l2 = cython.sizeof(name2)
        j = defs.sysctl(name1, l1, name2, &l2, NULL, 0)
        if j < 0:
            if errno == ENOENT:
                return
            else:
                raise OSError(errno, os.strerror(errno))

        l2 /= cython.sizeof(int)

        if name and (len(mib) < 0 or l2 < len(mib)):
            return

        for i in range(0, len(mib)):
            if name2[i] != mib[i]:
                return

        try:
            ret = sysctl([x for x in name2[:l2]])
        except OSError, e:
            if e.errno == ENOENT:
                return

        else:
            yield (sysctlmibtoname([x for x in name2[:l2]]), ret)

        memcpy(name1+2, name2, l2 * sizeof(int))
        l1 = 2 + l2
