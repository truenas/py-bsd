# cython: c_string_type=unicode, c_string_encoding=utf-8
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

import os
import enum
import math
import cython
from libc.errno cimport errno
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from posix.stat cimport *
cimport defs


class MountFlags(enum.IntEnum):
    RDONLY = defs.MNT_RDONLY
    SYNCHRONOUS = defs.MNT_SYNCHRONOUS
    NOEXEC = defs.MNT_NOEXEC
    NOSUID = defs.MNT_NOSUID
    NFS4ACLS = defs.MNT_NFS4ACLS
    UNION = defs.MNT_UNION
    ASYNC = defs.MNT_ASYNC
    FORCE = defs.MNT_FORCE
    SUIDDIR = defs.MNT_SUIDDIR
    SOFTDEP = defs.MNT_SOFTDEP
    NOSYMFOLLOW = defs.MNT_NOSYMFOLLOW
    GJOURNAL = defs.MNT_GJOURNAL
    MULTILABEL = defs.MNT_MULTILABEL
    ACLS = defs.MNT_ACLS
    NOATIME = defs.MNT_NOATIME
    NOCLUSTERR = defs.MNT_NOCLUSTERR
    NOCLUSTERW = defs.MNT_NOCLUSTERW
    
    
class ClockType(enum.IntEnum):
    REALTIME = defs.CLOCK_REALTIME
    REALTIME_PRECISE = defs.CLOCK_REALTIME_PRECISE
    REALTIME_FAST = defs.CLOCK_REALTIME_FAST
    MONOTONIC = defs.CLOCK_MONOTONIC
    MONOTONIC_PRECISE = defs.CLOCK_MONOTONIC_PRECISE
    MONOTONIC_FAST = defs.CLOCK_MONOTONIC_FAST
    UPTIME = defs.CLOCK_UPTIME
    UPTIME_PRECISE = defs.CLOCK_UPTIME_PRECISE
    UPTIME_FAST = defs.CLOCK_UPTIME_FAST


class DescriptorType(enum.IntEnum):
    VNODE = defs.PS_FST_TYPE_VNODE
    FIFO = defs.PS_FST_TYPE_FIFO
    SOCKET = defs.PS_FST_TYPE_SOCKET
    PIPE = defs.PS_FST_TYPE_PIPE
    PTS = defs.PS_FST_TYPE_PTS
    KQUEUE = defs.PS_FST_TYPE_KQUEUE
    CRYPTO = defs.PS_FST_TYPE_CRYPTO
    MQUEUE = defs.PS_FST_TYPE_MQUEUE
    SHM = defs.PS_FST_TYPE_SHM
    SEM = defs.PS_FST_TYPE_SEM
    UNKNOWN = defs.PS_FST_TYPE_UNKNOWN
    NONE = defs.PS_FST_TYPE_NONE


class DescriptorFlags(enum.IntEnum):
    READ = defs.PS_FST_FFLAG_READ
    WRITE = defs.PS_FST_FFLAG_WRITE
    NONBLOCK = defs.PS_FST_FFLAG_NONBLOCK
    APPEND = defs.PS_FST_FFLAG_APPEND
    SHLOCK = defs.PS_FST_FFLAG_SHLOCK
    EXLOCK = defs.PS_FST_FFLAG_EXLOCK
    ASYNC = defs.PS_FST_FFLAG_ASYNC
    SYNC = defs.PS_FST_FFLAG_SYNC
    NOFOLLOW = defs.PS_FST_FFLAG_NOFOLLOW
    CREAT = defs.PS_FST_FFLAG_CREAT
    TRUNC = defs.PS_FST_FFLAG_TRUNC
    EXCL = defs.PS_FST_FFLAG_EXCL
    DIRECT = defs.PS_FST_FFLAG_DIRECT
    EXEC = defs.PS_FST_FFLAG_EXEC
    HASLOCK = defs.PS_FST_FFLAG_HASLOCK


class DescriptorUseFlags(enum.IntEnum):
    RDIR = defs.PS_FST_UFLAG_RDIR
    CDIR = defs.PS_FST_UFLAG_CDIR
    JAIL = defs.PS_FST_UFLAG_JAIL
    TRACE = defs.PS_FST_UFLAG_TRACE
    TEXT = defs.PS_FST_UFLAG_TEXT
    MMAP = defs.PS_FST_UFLAG_MMAP
    CTTY = defs.PS_FST_UFLAG_CTTY


class VnodeType(enum.IntEnum):
    VNON = defs.PS_FST_VTYPE_VNON
    VREG = defs.PS_FST_VTYPE_VREG
    VDIR = defs.PS_FST_VTYPE_VDIR
    VBLK = defs.PS_FST_VTYPE_VBLK
    VCHR = defs.PS_FST_VTYPE_VCHR
    VLNK = defs.PS_FST_VTYPE_VLNK
    VSOCK = defs.PS_FST_VTYPE_VSOCK
    VFIFO = defs.PS_FST_VTYPE_VFIFO
    VBAD = defs.PS_FST_VTYPE_VBAD
    UNKNOWN = defs.PS_FST_VTYPE_UNKNOWN


class ProcessLookupPredicate(enum.IntEnum):
    ALL = defs.KERN_PROC_ALL
    PID = defs.KERN_PROC_PID
    PGRP = defs.KERN_PROC_PGRP
    SESSION = defs.KERN_PROC_SESSION
    TTY = defs.KERN_PROC_TTY
    UID = defs.KERN_PROC_UID
    RUID = defs.KERN_PROC_RUID
    PROC = defs.KERN_PROC_PROC
    RGID = defs.KERN_PROC_RGID
    GID = defs.KERN_PROC_GID
    INC_THREAD = defs.KERN_PROC_INC_THREAD


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


cdef class OpenFile(object):
    cdef defs.procstat* ps
    cdef defs.filestat* fs

    cdef init(self):
        pass

    def __repr__(self):
        return str(self)

    def __str__(self):
        return "<bsd.OpenFile path '{0}' type {1}>".format(
            self.path,
            str(self.type)
        )

    def __getstate__(self):
        return {
            'type': self.type.name,
            'flags': [i.name for i in self.fflags],
            'uflags': [i.name for i in self.uflags],
            'fd': self.fd,
            'path': self.path,
            'refcount': self.refcount
        }

    property type:
        def __get__(self):
            return DescriptorType(self.fs.fs_type)

    property fflags:
        def __get__(self):
            return bitmask_to_set(self.fs.fs_fflags, DescriptorFlags)

    property uflags:
        def __get__(self):
            return bitmask_to_set(self.fs.fs_uflags, DescriptorUseFlags)

    property fd:
        def __get__(self):
            return self.fs.fs_fd

    property path:
        def __get__(self):
            return self.fs.fs_path or None

    property refcount:
        def __get__(self):
            return self.fs.fs_ref_count


cdef class OpenVnode(OpenFile):
    cdef defs.vnstat vn

    cdef init(self):
        cdef char errbuf[defs._POSIX2_LINE_MAX];

        err = defs.procstat_get_vnode_info(self.ps, self.fs, &self.vn, errbuf)
        if err != 0:
            pass

    def __getstate__(self):
        d = super(OpenVnode, self).__getstate__()
        d.update({
            'devname': self.devname,
            'mntdir': self.mntdir,
            'dev': self.dev,
            'fsid': self.fsid
        })

        return d

    property devname:
        def __get__(self):
            return self.vn.vn_devname or None

    property mntdir:
        def __get__(self):
            return self.vn.vn_mntdir or None

    property dev:
        def __get__(self):
            return self.vn.vn_dev

    property fsid:
        def __get__(self):
            return self.vn.vn_fsid


cdef class Process(object):
    cdef defs.kinfo_proc* proc
    cdef bint free

    def __cinit__(self):
        self.free = False

    def __dealloc__(self):
        if self.free:
            free(self.proc)

    def __repr__(self):
        return str(self)

    def __str__(self):
        return "<bsd.Process '{0}' pid {1}>".format(self.command, self.pid)

    def __getstate__(self):
        return {
            'pid': self.pid,
            'ppid': self.ppid,
            'command': self.command,
            'files': [i.__getstate__() for i in self.files]
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
            ret = <object>self.proc.ki_rusage
            ret.update({
                'ru_utime': convert_timeval(&self.proc.ki_rusage.ru_utime),
                'ru_stime': convert_timeval(&self.proc.ki_rusage.ru_stime),
            })

            return ret

    property files:
        def __get__(self):
            cdef OpenFile file
            cdef defs.procstat* ps
            cdef defs.filestat_list* fs_list
            cdef defs.filestat* fs

            ps = defs.procstat_open_sysctl()
            if ps == NULL:
                raise OSError(errno, os.strerror(errno))

            fs_list = defs.procstat_getfiles(ps, self.proc, 0)
            fs = fs_list.stqh_first

            type_mapping = {
                defs.PS_FST_TYPE_VNODE: OpenVnode
            }

            while fs != NULL:
                cls = type_mapping.get(fs.fs_type, OpenFile)
                file = cls.__new__(cls)
                file.ps = ps
                file.fs = fs
                file.init()
                yield file

                fs = fs.next.stqe_next

            defs.procstat_close(ps)


def getmntinfo():
    cdef MountPoint mnt
    cdef defs.statfs* mntbuf

    count = defs.getmntinfo(&mntbuf, defs.MNT_WAIT)
    if count == 0:
        raise OSError(errno, os.strerror(errno))

    for i in range(0, count):
        mnt = MountPoint.__new__(MountPoint)
        mnt.statfs = &mntbuf[i]
        yield mnt


def statfs(path):
    cdef MountPoint mnt
    cdef defs.statfs* statfs

    statfs = <defs.statfs*>malloc(cython.sizeof(defs.statfs))

    if defs.c_statfs(path, statfs) != 0:
        raise OSError(errno, os.strerror(errno))

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
    args = []
    iov = <defs.iovec*>malloc(cython.sizeof(defs.iovec) * len(kwargs) * 2)

    for k, v in kwargs.items():
        args.append(k.encode('ascii', 'ignore'))
        args.append(v.encode('ascii', 'ignore'))

    for i in range(0, len(args)):
        iov[i].iov_base = <void*>(<char*>args[i])
        iov[i].iov_len = len(args[i]) + 1

    if defs.nmount(iov, i + 1, flags) != 0:
        free(iov)
        raise OSError(errno, os.strerror(errno))

    free(iov)


def unmount(dir, flags=0):
    if defs.unmount(dir, flags) != 0:
        raise OSError(errno, os.strerror(errno))


def kinfo_getproc(pid):
    cdef Process ret
    cdef defs.kinfo_proc* proc

    proc = defs.kinfo_getproc(pid)
    if proc == NULL:
        raise LookupError("PID {0} not found".format(pid))

    ret = Process.__new__(Process)
    ret.proc = proc
    return ret


def getprocs(predicate, arg=0):
    cdef Process proc
    cdef defs.procstat *ps
    cdef defs.kinfo_proc *ret
    cdef defs.kinfo_proc *tmp
    cdef unsigned int count
    cdef int c_predicate = 0
    cdef int c_arg = 0

    if not isinstance(predicate, ProcessLookupPredicate):
        raise ValueError('predicate must be ProcessLookupPredicate')

    c_predicate = predicate
    c_arg = arg

    ps = defs.procstat_open_sysctl()
    if ps == NULL:
        raise OSError(errno, os.strerror(errno))

    with nogil:
        ret = defs.procstat_getprocs(ps, c_predicate, c_arg, &count)

    if ret == NULL:
        raise OSError(errno, os.strerror(errno))

    for i in range(0, count):
        tmp = <defs.kinfo_proc *>malloc(sizeof(defs.kinfo_proc))
        memcpy(tmp, &ret[i], sizeof(defs.kinfo_proc))

        proc = Process.__new__(Process)
        proc.proc = tmp
        proc.free = True
        yield proc

    defs.procstat_freeprocs(ps, ret)
    defs.procstat_close(ps)


def clock_gettime(clock):
    cdef defs.timespec tp

    if defs.clock_gettime(clock, &tp) != 0:
        raise OSError(errno, os.strerror(errno))

    return tp.tv_sec + tp.tv_nsec * 1e-9


def clock_settime(clock, value):
    cdef defs.timespec tp

    frac, rest = math.modf(value)
    tp.tv_sec = rest
    tp.tv_nsec = frac * 1e9

    if defs.clock_settime(clock, &tp) != 0:
        raise OSError(errno, os.strerror(errno))


def lchown(path, uid=-1, gid=-1, recursive=False):
    os.lchown(path, uid, gid)
    if not recursive:
        return

    for root, dirs, files in os.walk(path):
        for n in files:
            os.lchown(os.path.join(root, n), uid, gid)

        for n in dirs:
            os.lchown(os.path.join(root, n), uid, gid)


def lchmod(path, mode, recursive=False):
    os.lchmod(path, mode)
    if not recursive:
        return

    for root, dirs, files in os.walk(path):
        for n in files:
            os.lchmod(os.path.join(root, n), mode)

        for n in dirs:
            os.lchmod(os.path.join(root, n), mode)


def login_tty(fd):
    if defs.login_tty(fd) == -1:
        raise OSError(errno, os.strerror(errno))


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
