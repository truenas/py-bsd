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
# OR SERVICES
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

from libc.stdint cimport *
from posix.types cimport *


cdef extern from "sys/uio.h":
    cdef struct iovec:
        void* iov_base
        size_t iov_len


cdef extern from "sys/param.h":
    enum:
        MAXPATHLEN


cdef extern from "sys/types.h":
    ctypedef unsigned char u_char
    ctypedef unsigned short u_short
    ctypedef unsigned int u_int
    ctypedef uint64_t u_int64_t
    ctypedef int lwpid_t
    ctypedef uintptr_t segsz_t
    ctypedef uintptr_t vm_size_t
    ctypedef char* caddr_t


cdef extern from "sys/mount.h":
    enum:
        MNAMELEN
        MFSNAMELEN
        MNT_WAIT
        
    enum:
        MNT_RDONLY
        MNT_SYNCHRONOUS
        MNT_NOEXEC
        MNT_NOSUID
        MNT_NFS4ACLS
        MNT_UNION
        MNT_ASYNC
        MNT_FORCE
        MNT_SUIDDIR
        MNT_SOFTDEP
        MNT_NOSYMFOLLOW
        MNT_GJOURNAL
        MNT_MULTILABEL
        MNT_ACLS
        MNT_NOATIME
        MNT_NOCLUSTERR
        MNT_NOCLUSTERW

    ctypedef struct fsid_t:
        int32_t val[2]

    ctypedef int uid_t
    ctypedef unsigned int u_int

    cdef struct statfs:
        uint32_t f_version
        uint32_t f_type
        uint64_t f_flags
        uint64_t f_bsize
        uint64_t f_iosize
        uint64_t f_blocks
        uint64_t f_bfree
        int64_t  f_bavail
        uint64_t f_files
        int64_t  f_ffree
        uint64_t f_syncwrites
        uint64_t f_asyncwrites
        uint64_t f_syncreads
        uint64_t f_asyncreads
        uint64_t f_spare[10]
        uint32_t f_namemax
        uid_t f_owner
        fsid_t f_fsid
        char f_charspare[80]
        char f_fstypename[MFSNAMELEN]
        char f_mntfromname[MNAMELEN]
        char f_mntonname[MNAMELEN]

    int getmntinfo(statfs** mntbufp, int flags)
    int c_statfs "statfs" (const char* path, statfs* buf)
    int nmount(iovec* iov, u_int niov, int flags)
    int unmount(const char* dir, int flags)


cdef extern from "sys/time.h":
    cdef struct timeval:
        time_t tv_sec
        suseconds_t tv_usec


cdef extern from "sys/resource.h":
    cdef struct rusage:
        timeval ru_utime
        timeval ru_stime
        long ru_maxrss
        long ru_ixrss
        long ru_idrss
        long ru_isrss
        long ru_minflt
        long ru_majflt
        long ru_nswap
        long ru_inblock
        long ru_oublock
        long ru_msgsnd
        long ru_msgrcv
        long ru_nsignals
        long ru_nvcsw
        long ru_nivcsw


cdef extern from "sys/user.h":
    enum:
        WMESGLEN
        LOCKNAMELEN
        TDNAMLEN
        COMMLEN
        KI_EMULNAMELEN
        KI_NGROUPS
        LOGNAMELEN
        LOGINCLASSLEN

    cdef struct kinfo_proc:
        int	ki_structsize
        int	ki_layout
        void	*ki_wchan
        pid_t	ki_pid
        pid_t	ki_ppid
        pid_t	ki_pgid
        pid_t	ki_tpgid
        pid_t	ki_sid
        pid_t	ki_tsid
        short	ki_jobc
        short	ki_spare_short1
        dev_t	ki_tdev
        sigset_t ki_siglist
        sigset_t ki_sigmask
        sigset_t ki_sigignore
        sigset_t ki_sigcatch
        uid_t	ki_uid
        uid_t	ki_ruid
        uid_t	ki_svuid
        gid_t	ki_rgid
        gid_t	ki_svgid
        short	ki_ngroups
        short	ki_spare_short2
        gid_t	ki_groups[KI_NGROUPS]
        vm_size_t ki_size
        segsz_t ki_rssize
        segsz_t ki_swrss
        segsz_t ki_tsize
        segsz_t ki_dsize
        segsz_t ki_ssize
        u_short	ki_xstat
        u_short	ki_acflag
        u_int	ki_estcpu
        u_int	ki_slptime
        u_int	ki_swtime
        u_int	ki_cow
        u_int64_t ki_runtime
        timeval ki_start
        timeval ki_childtime
        long	ki_flag
        long	ki_kiflag
        int	ki_traceflag
        char	ki_stat
        signed char ki_nice
        char	ki_lock
        char	ki_rqindex
        u_char	ki_oncpu
        u_char	ki_lastcpu
        char	ki_tdname[TDNAMLEN+1]
        char	ki_wmesg[WMESGLEN+1]
        char	ki_login[LOGNAMELEN+1]
        char	ki_lockname[LOCKNAMELEN+1]
        char	ki_comm[COMMLEN+1]
        char	ki_emul[KI_EMULNAMELEN+1]
        char	ki_loginclass[LOGINCLASSLEN+1]
        int	ki_flag2
        int	ki_fibnum
        u_int	ki_cr_flags
        int	ki_jid
        int	ki_numthreads
        lwpid_t	ki_tid
        rusage ki_rusage
        rusage ki_rusage_ch
        void	*ki_kstack
        void	*ki_udata
        long	ki_sflag
        long	ki_tdflags


cdef extern from "libutil.h":
    kinfo_proc* kinfo_getproc(pid_t pid)


cdef extern from "sys/sysctl.h":
    int sysctl(int *name, unsigned int namelen, void *oldp, size_t *oldlenp,
        void *newp, size_t newlen)
    int sysctlbyname(char *name, void *oldp, size_t *oldlenp, void *newp,
        size_t newlen)
    int sysctlnametomib(char *name, void *mibp, size_t *sizep)


cdef extern from "sys/linker.h":
    cdef struct kld_file_stat:
        int version
        char name[MAXPATHLEN]
        int refs
        int id
        caddr_t address
        size_t size
        char pathname[MAXPATHLEN]


    int kldload(const char* file)
    int kldunload(int fileid)
    int kldnext(int fileid)
    int kldstat(int fileid, kld_file_stat* stat)