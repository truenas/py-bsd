#-
# Copyright (c) 2015 iXsystems, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

import cython
from libc.string cimport strerror
from libc.errno cimport errno
from libc.stdlib cimport malloc, free
cimport defs


cdef class KernelModule(object):
    cdef defs.kld_file_stat* stat

    def __dealloc__(self):
        free(self.stat)

    def unload(self):
        if defs.kldunload(self.id) != 0:
            raise OSError(errno, strerror(errno))

    def __str__(self):
        return "<bsd.kld.KernelModule name '{0}'>".format(self.name)

    def __repr__(self):
        return str(self)

    property name:
        def __get__(self):
            return self.stat.name.decode('ascii')

    property refs:
        def __get__(self):
            return self.stat.refs

    property id:
        def __get__(self):
            return self.stat.id

    property address:
        def __get__(self):
            return <long>self.stat.address

    property size:
        def __get__(self):
            return self.stat.size

    property pathname:
        def __get__(self):
            return self.stat.pathname.decode('ascii')


def kldstat():
    cdef KernelModule kld
    cdef int mod_id = 0
    cdef defs.kld_file_stat* stat

    while True:
        mod_id = defs.kldnext(mod_id)
        if mod_id == 0:
            break

        stat = <defs.kld_file_stat*>malloc(cython.sizeof(defs.kld_file_stat))
        stat.version = cython.sizeof(defs.kld_file_stat)

        if defs.kldstat(mod_id, stat) != 0:
            free(stat)
            raise OSError(errno, strerror(errno))

        kld = KernelModule.__new__(KernelModule)
        kld.stat = stat
        yield kld


def kldload(path):
    path = path.encode('ascii')
    if defs.kldload(path) == -1:
        raise OSError(errno, strerror(errno))


def kldunload(name):
    pass
