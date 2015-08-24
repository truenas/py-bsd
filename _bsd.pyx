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

import enum
import resource
import cython
from libc.string cimport strerror
from libc.errno cimport errno
from libc.stdlib cimport malloc, free
cimport defs


class MountFlags(enum.IntEnum):
    RDONLY = defs.MNT_RDONLY
    SYNCHRONOUS = defs.MNT_SYNCHRONOUS
    NOEXEC = defs.MNT_NOEXEC
    NOSUID = defs.MNT_NOSUID
    NFS4ACLS = defs.MNT_NFS4ACLS
    UNION = defs.MNT_UNION
    ASYNC = defs.MNT_ASYNC
    SUIDDIR = defs.MNT_SUIDDIR
    SOFTDEP = defs.MNT_SOFTDEP
    NOSYMFOLLOW = defs.MNT_NOSYMFOLLOW
    GJOURNAL = defs.MNT_GJOURNAL
    MULTILABEL = defs.MNT_MULTILABEL
    ACLS = defs.MNT_ACLS
    NOATIME = defs.MNT_NOATIME
    NOCLUSTERR = defs.MNT_NOCLUSTERR
    NOCLUSTERW = defs.MNT_NOCLUSTERW


cdef class MountPoint(object):
    cdef defs.statfs* statfs
    cdef bint free

    def __cinit__(self):
        self.free = False

    def __dealloc__(self):
        if self.free:
            free(self.statfs)

    def __str__(self):
        return "<bsd.MountPoint '{0}' on '{1}' type '{2}'>".format(self.source, self.dest, self.fstype)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'flags': [x.name for x in self.flags],
            'fstype': self.fstype,
            'source': self.source,
            'dest': self.dest,
            'blocksize': self.blocksize,
            'total_blocks': self.total_blocks,
            'free_blocks': self.free_blocks,
            'avail_blocks': self.avail_blocks,
            'files': self.files,
            'free_files': self.free_files,
            'name_max': self.name_max,
            'fsid': self.fsid
        }

    property flags:
        def __get__(self):
            return bitmask_to_set(self.statfs.f_flags, MountFlags)

    property fstype:
        def __get__(self):
            return self.statfs.f_fstypename

    property source:
        def __get__(self):
            return self.statfs.f_mntfromname

    property dest:
        def __get__(self):
            return self.statfs.f_mntonname

    property blocksize:
        def __get__(self):
            return self.statfs.f_bsize

    property total_blocks:
        def __get__(self):
            return self.statfs.f_blocks

    property free_blocks:
        def __get__(self):
            return self.statfs.f_bfree

    property avail_blocks:
        def __get__(self):
            return self.statfs.f_bavail

    property files:
        def __get__(self):
            return self.statfs.f_files

    property free_files:
        def __get__(self):
            return self.statfs.f_ffree

    property name_max:
        def __get__(self):
            return self.statfs.f_namemax

    property fsid:
        def __get__(self):
            return self.statfs.f_fsid.val[0], self.statfs.f_fsid.val[1]


cdef class Process(object):
    cdef defs.kinfo_proc* proc
    cdef bint free

    def __cinit__(self):
        self.free = False

    def __dealloc__(self):
        if self.free:
            free(self.proc)

    def __getstate__(self):
        return {
            'pid': self.pid,
            'ppid': self.ppid,
            'command': self.command
        }

    property pid:
        def __get__(self):
            return self.proc.ki_pid

    property ppid:
        def __get__(self):
            return self.proc.ki_ppid

    property command:
        def __get__(self):
            return self.proc.ki_comm

    property rusage:
        def __get__(self):
            return resource.struct_rusage((
                convert_timeval(&self.proc.ki_rusage.ru_utime),
                convert_timeval(&self.proc.ki_rusage.ru_stime),
                self.proc.ki_rusage.ru_maxrss,
                self.proc.ki_rusage.ru_ixrss,
                self.proc.ki_rusage.ru_idrss,
                self.proc.ki_rusage.ru_isrss,
                self.proc.ki_rusage.ru_minflt,
                self.proc.ki_rusage.ru_majflt,
                self.proc.ki_rusage.ru_nswap,
                self.proc.ki_rusage.ru_inblock,
                self.proc.ki_rusage.ru_oublock,
                self.proc.ki_rusage.ru_msgsnd,
                self.proc.ki_rusage.ru_msgrcv,
                self.proc.ki_rusage.ru_nsignals,
                self.proc.ki_rusage.ru_nvcsw,
                self.proc.ki_rusage.ru_nivcsw,
            ))


def getmntinfo():
    cdef MountPoint mnt
    cdef defs.statfs* mntbuf

    count = defs.getmntinfo(&mntbuf, defs.MNT_WAIT)
    if count == 0:
        raise OSError(errno, strerror(errno))

    for i in range(0, count):
        mnt = MountPoint.__new__(MountPoint)
        mnt.statfs = &mntbuf[i]
        yield mnt


def statfs(path):
    cdef MountPoint mnt
    cdef defs.statfs* statfs

    statfs = <defs.statfs*>malloc(cython.sizeof(defs.statfs))

    if defs.c_statfs(path, statfs) != 0:
        raise OSError(errno, strerror(errno))

    mnt = MountPoint.__new__(MountPoint)
    mnt.statfs = statfs
    mnt.free = True
    return mnt


def nmount(**kwargs):
    cdef defs.iovec* iov

    flags = kwargs.pop('flags', 0)

    if 'source' in kwargs:
        kwargs['from'] = kwargs.pop('source')

    i = 0
    iov = <defs.iovec*>malloc(cython.sizeof(defs.iovec) * len(kwargs) * 2)
    for k, v in kwargs.items():
        k = k.encode('ascii', 'ignore')
        iov[i].iov_base = <void*>(<char*>k)
        iov[i].iov_len = len(k) + 1
        i += 1

        v = k.encode('ascii', 'ignore')
        iov[i].iov_base = <void*>(<char*>v)
        iov[i].iov_len = len(v) + 1
        i += 1

    if defs.nmount(iov, i, flags) != 0:
        raise OSError(errno, strerror(errno))

    free(iov)


def unmount(dir, flags=0):
    if defs.unmount(dir, flags) != 0:
        raise OSError(errno, strerror(errno))


def kinfo_getproc(pid):
    cdef Process ret
    cdef defs.kinfo_proc* proc

    proc = defs.kinfo_getproc(pid)
    if proc == NULL:
        raise LookupError("PID {0} not found".format(pid))

    ret = Process.__new__(Process)
    ret.proc = proc
    return ret



def bitmask_to_set(n, enumeration):
    result = set()
    while n:
        b = n & (~n+1)
        try:
            result.add(enumeration(b))
        except ValueError:
            pass

        n ^= b

    return result


def set_to_bitmask(value):
    result = 0
    for i in value:
        result |= int(i)

    return result


cdef double convert_timeval(defs.timeval* tv):
    return tv.tv_sec + tv.tv_usec * 1e-6
