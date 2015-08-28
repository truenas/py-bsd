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


cdef extern from "sys/acl.h":
    enum:
        ACL_BRAND_UNKNOWN
        ACL_BRAND_POSIX
        ACL_BRAND_NFS4

    enum:
        ACL_TYPE_ACCESS
        ACL_TYPE_DEFAULT
        ACL_TYPE_NFS4

    enum:
        ACL_FIRST_ENTRY
        ACL_NEXT_ENTRY

    enum:
        ACL_USER_OBJ
        ACL_USER
        ACL_GROUP_OBJ
        ACL_GROUP
        ACL_MASK
        ACL_OTHER
        ACL_EVERYONE

    enum:
        ACL_ENTRY_TYPE_ALLOW
        ACL_ENTRY_TYPE_DENY

    enum:
        ACL_ENTRY_FILE_INHERIT
        ACL_ENTRY_DIRECTORY_INHERIT
        ACL_ENTRY_NO_PROPAGATE_INHERIT
        ACL_ENTRY_INHERIT_ONLY

    ctypedef enum acl_perm_t:
        ACL_EXECUTE
        ACL_WRITE
        ACL_READ
        ACL_READ_DATA
        ACL_LIST_DIRECTORY
        ACL_WRITE_DATA
        ACL_ADD_FILE
        ACL_APPEND_DATA
        ACL_ADD_SUBDIRECTORY
        ACL_READ_NAMED_ATTRS
        ACL_WRITE_NAMED_ATTRS
        ACL_EXECUTE
        ACL_DELETE_CHILD
        ACL_READ_ATTRIBUTES
        ACL_WRITE_ATTRIBUTES
        ACL_DELETE
        ACL_READ_ACL
        ACL_WRITE_ACL
        ACL_SYNCHRONIZE

    ctypedef struct acl_t:
        pass

    ctypedef struct acl_entry_t:
        pass

    ctypedef unsigned int acl_tag_t
    ctypedef unsigned int acl_perm_t
    ctypedef unsigned short acl_entry_type_t
    ctypedef unsigned short acl_flag_t
    ctypedef int acl_type_t
    ctypedef int* acl_permset_t
    ctypedef unsigned short* acl_flagset_t

    int	acl_add_flag_np(acl_flagset_t _flagset_d, acl_flag_t _flag)
    int	acl_add_perm(acl_permset_t _permset_d, acl_perm_t _perm)
    int	acl_calc_mask(acl_t *_acl_p)
    int	acl_clear_flags_np(acl_flagset_t _flagset_d)
    int	acl_clear_perms(acl_permset_t _permset_d)
    int	acl_copy_entry(acl_entry_t _dest_d, acl_entry_t _src_d)
    ssize_t	acl_copy_ext(void *_buf_p, acl_t _acl, ssize_t _size)
    acl_t acl_copy_int(const void *_buf_p)
    int	acl_create_entry(acl_t *_acl_p, acl_entry_t *_entry_p)
    int	acl_create_entry_np(acl_t *_acl_p, acl_entry_t *_entry_p, int _index)
    int	acl_delete_entry(acl_t _acl, acl_entry_t _entry_d)
    int	acl_delete_entry_np(acl_t _acl, int _index)
    int	acl_delete_fd_np(int _filedes, acl_type_t _type)
    int	acl_delete_file_np(const char *_path_p, acl_type_t _type)
    int	acl_delete_link_np(const char *_path_p, acl_type_t _type)
    int	acl_delete_def_file(const char *_path_p)
    int	acl_delete_def_link_np(const char *_path_p)
    int	acl_delete_flag_np(acl_flagset_t _flagset_d, acl_flag_t _flag)
    int	acl_delete_perm(acl_permset_t _permset_d, acl_perm_t _perm)
    acl_t acl_dup(acl_t _acl)
    int	acl_free(void *_obj_p)
    acl_t acl_from_text(const char *_buf_p)
    int	acl_get_brand_np(acl_t _acl, int *_brand_p)
    int	acl_get_entry(acl_t _acl, int _entry_id, acl_entry_t *_entry_p)
    acl_t acl_get_fd(int _fd)
    acl_t acl_get_fd_np(int fd, acl_type_t _type)
    acl_t acl_get_file(const char *_path_p, acl_type_t _type)
    int	acl_get_entry_type_np(acl_entry_t _entry_d, acl_entry_type_t *_entry_type_p)
    acl_t acl_get_link_np(const char *_path_p, acl_type_t _type)
    void* acl_get_qualifier(acl_entry_t _entry_d)
    int	acl_get_flag_np(acl_flagset_t _flagset_d, acl_flag_t _flag)
    int	acl_get_perm_np(acl_permset_t _permset_d, acl_perm_t _perm)
    int	acl_get_flagset_np(acl_entry_t _entry_d, acl_flagset_t *_flagset_p)
    int	acl_get_permset(acl_entry_t _entry_d, acl_permset_t *_permset_p)
    int	acl_get_tag_type(acl_entry_t _entry_d, acl_tag_t *_tag_type_p)
    acl_t acl_init(int _count)
    int	acl_set_fd(int _fd, acl_t _acl)
    int	acl_set_fd_np(int _fd, acl_t _acl, acl_type_t _type)
    int	acl_set_file(const char *_path_p, acl_type_t _type, acl_t _acl)
    int	acl_set_entry_type_np(acl_entry_t _entry_d, acl_entry_type_t _entry_type)
    int	acl_set_link_np(const char *_path_p, acl_type_t _type, acl_t _acl)
    int	acl_set_flagset_np(acl_entry_t _entry_d, acl_flagset_t _flagset_d)
    int	acl_set_permset(acl_entry_t _entry_d, acl_permset_t _permset_d)
    int	acl_set_qualifier(acl_entry_t _entry_d, const void *_tag_qualifier_p)
    int	acl_set_tag_type(acl_entry_t _entry_d, acl_tag_t _tag_type)
    ssize_t	acl_size(acl_t _acl)
    char* acl_to_text(acl_t _acl, ssize_t *_len_p)
    char* acl_to_text_np(acl_t _acl, ssize_t *_len_p, int _flags)
    int	acl_valid(acl_t _acl)
    int	acl_valid_fd_np(int _fd, acl_type_t _type, acl_t _acl)
    int	acl_valid_file_np(const char *_path_p, acl_type_t _type, acl_t _acl)
    int	acl_valid_link_np(const char *_path_p, acl_type_t _type, acl_t _acl)
    int	acl_is_trivial_np(const acl_t _acl, int *_trivialp)
    acl_t acl_strip_np(const acl_t _acl, int recalculate_mask)
