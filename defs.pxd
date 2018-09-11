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
from libc.stdio cimport *

cdef extern from "limits.h":
    enum:
        _POSIX2_LINE_MAX


cdef extern from "unistd.h" nogil:
    enum:
        SEEK_SET
        SEEK_CUR
        SEEK_END
        SEEK_HOLE
        SEEK_DATA

    void closefrom(int lowfd)
    void setproctitle(const char *fmt, ...)


cdef extern from "fnmatch.h" nogil:
    enum:
        FNM_NOESCAPE
        FNM_PATHNAME
        FNM_PERIOD
        FNM_LEADING_DIR
        FNM_CASEFOLD

    enum:
        FNM_NOMATCH

    int fnmatch(const char *pattern, const char *string, int flags)


cdef extern from "sys/uio.h":
    cdef struct iovec:
        void* iov_base
        size_t iov_len


cdef extern from "sys/param.h":
    enum:
        MAXPATHLEN
        SPECNAMELEN


cdef extern from "sys/types.h":
    ctypedef unsigned char u_char
    ctypedef unsigned short u_short
    ctypedef unsigned int u_int
    ctypedef uint64_t u_int64_t
    ctypedef int lwpid_t
    ctypedef uintptr_t segsz_t
    ctypedef uintptr_t vm_size_t
    ctypedef char* caddr_t
    ctypedef short in_port_t
    ctypedef int in_addr


cdef extern from "sys/socket.h":
    ctypedef int sa_family_t

    cdef struct sockaddr_storage:
        unsigned char ss_len
        sa_family_t ss_family


cdef extern from "netinet/in.h":
    ctypedef struct in_addr_t:
        uint32_t s_addr

    cdef struct sockaddr_in:
        uint8_t sin_len
        sa_family_t sin_family
        in_port_t sin_port
        in_addr_t sin_addr
        char sin_zero[8]

    cdef struct in6_addr:
        uint8_t s6_addr[16]

    cdef struct sockaddr_in6:
        uint8_t sin6_len
        sa_family_t sin6_family
        in_port_t sin6_port
        uint32_t sin6_flowinfo
        in6_addr sin6_addr
        uint32_t sin6_scope_id


cdef extern from "sys/mount.h" nogil:
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


cdef extern from "time.h" nogil:
    ctypedef int clockid_t

    cdef struct timespec:
        time_t tv_sec
        long tv_nsec

    enum:
        CLOCK_REALTIME
        CLOCK_REALTIME_PRECISE
        CLOCK_REALTIME_FAST
        CLOCK_MONOTONIC
        CLOCK_MONOTONIC_PRECISE
        CLOCK_MONOTONIC_FAST
        CLOCK_UPTIME
        CLOCK_UPTIME_PRECISE
        CLOCK_UPTIME_FAST

    int clock_gettime(clockid_t clock_id, timespec *tp)
    int clock_settime(clockid_t clock_id, timespec *tp)


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


cdef extern from "libutil.h" nogil:
    kinfo_proc* kinfo_getproc(pid_t pid)


cdef extern from "libprocstat.h" nogil:
    enum:
        PS_FST_TYPE_VNODE
        PS_FST_TYPE_FIFO
        PS_FST_TYPE_SOCKET
        PS_FST_TYPE_PIPE
        PS_FST_TYPE_PTS
        PS_FST_TYPE_KQUEUE
        PS_FST_TYPE_CRYPTO
        PS_FST_TYPE_MQUEUE
        PS_FST_TYPE_SHM
        PS_FST_TYPE_SEM
        PS_FST_TYPE_UNKNOWN
        PS_FST_TYPE_NONE

    enum:
        PS_FST_VTYPE_VNON
        PS_FST_VTYPE_VREG
        PS_FST_VTYPE_VDIR
        PS_FST_VTYPE_VBLK
        PS_FST_VTYPE_VCHR
        PS_FST_VTYPE_VLNK
        PS_FST_VTYPE_VSOCK
        PS_FST_VTYPE_VFIFO
        PS_FST_VTYPE_VBAD
        PS_FST_VTYPE_UNKNOWN

    enum:
        PS_FST_FFLAG_READ
        PS_FST_FFLAG_WRITE
        PS_FST_FFLAG_NONBLOCK
        PS_FST_FFLAG_APPEND
        PS_FST_FFLAG_SHLOCK
        PS_FST_FFLAG_EXLOCK
        PS_FST_FFLAG_ASYNC
        PS_FST_FFLAG_SYNC
        PS_FST_FFLAG_NOFOLLOW
        PS_FST_FFLAG_CREAT
        PS_FST_FFLAG_TRUNC
        PS_FST_FFLAG_EXCL
        PS_FST_FFLAG_DIRECT
        PS_FST_FFLAG_EXEC
        PS_FST_FFLAG_HASLOCK

    enum:
        PS_FST_UFLAG_RDIR
        PS_FST_UFLAG_CDIR
        PS_FST_UFLAG_JAIL
        PS_FST_UFLAG_TRACE
        PS_FST_UFLAG_TEXT
        PS_FST_UFLAG_MMAP
        PS_FST_UFLAG_CTTY

    cdef struct procstat:
        pass

    cdef struct stailq_entry:
        filestat *stqe_next

    cdef struct filestat:
        int fs_type
        int fs_flags
        int fs_fflags
        int fs_uflags
        int fs_fd
        int fs_ref_count
        off_t fs_offset
        void *fs_typedep
        char *fs_path
        stailq_entry next

    cdef struct filestat_list:
        filestat *stqh_first
        filestat **stqh_last

    cdef struct pipestat:
        pass

    cdef struct ptsstat:
        pass

    cdef struct semstat:
        pass

    cdef struct shmstat:
        pass

    cdef struct sockstat:
        uint64_t inp_ppcb
        uint64_t so_addr
        uint64_t so_pcb
        uint64_t unp_conn
        int dom_family
        int proto
        int	so_rcv_sb_state
        int	so_snd_sb_state
        sockaddr_storage sa_local
        sockaddr_storage sa_peer
        int	type
        char dname[32]

    cdef struct vnstat:
        uint64_t vn_fileid
        uint64_t vn_size
        char *vn_mntdir
        uint32_t vn_dev
        uint32_t vn_fsid
        int	vn_type
        uint16_t vn_mode
        char vn_devname[SPECNAMELEN + 1]

    void procstat_close(procstat *procstat)
    void procstat_freeargv(procstat *procstat)
    void procstat_freeenvv(procstat *procstat)
    void procstat_freegroups(procstat *procstat, gid_t *groups)
    void procstat_freeprocs(procstat *procstat, kinfo_proc *p)
    void procstat_freefiles(procstat *procstat,  filestat_list *head)
    filestat_list *procstat_getfiles(procstat *procstat, kinfo_proc *kp, int mmapped)
    kinfo_proc *procstat_getprocs(procstat *procstat, int what, int arg, unsigned int *count)
    int	procstat_get_pipe_info(procstat *procstat, filestat *fst, pipestat *pipe, char *errbuf)
    int	procstat_get_pts_info(procstat *procstat, filestat *fst, ptsstat *pts, char *errbuf)
    int	procstat_get_sem_info(procstat *procstat, filestat *fst, semstat *sem, char *errbuf)
    int	procstat_get_shm_info(procstat *procstat, filestat *fst, shmstat *shm, char *errbuf)
    int	procstat_get_socket_info(procstat *procstat, filestat *fst, sockstat *sock, char *errbuf)
    int	procstat_get_vnode_info(procstat *procstat, filestat *fst, vnstat *vn, char *errbuf)
    char **procstat_getargv(procstat *procstat, kinfo_proc *p, size_t nchr)
    char **procstat_getenvv(procstat *procstat, kinfo_proc *p, size_t nchr)
    int	procstat_getpathname(procstat *procstat, kinfo_proc *kp, char *pathname, size_t maxlen)
    procstat *procstat_open_sysctl()
    procstat *procstat_open_core(const char *filename)


cdef extern from "sys/sysctl.h" nogil:
    enum:
        KERN_PROC_ALL
        KERN_PROC_PID
        KERN_PROC_PGRP
        KERN_PROC_SESSION
        KERN_PROC_TTY
        KERN_PROC_UID
        KERN_PROC_RUID
        KERN_PROC_PROC
        KERN_PROC_RGID
        KERN_PROC_GID
        KERN_PROC_INC_THREAD

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


cdef extern from "sys/extattr.h" nogil:
    enum:
        EXTATTR_NAMESPACE_EMPTY
        EXTATTR_NAMESPACE_USER
        EXTATTR_NAMESPACE_SYSTEM

    char *EXTATTR_NAMESPACE_EMPTY_STRING
    char *EXTATTR_NAMESPACE_USER_STRING
    char *EXTATTR_NAMESPACE_SYSTEM_STRING
    
    ssize_t extattr_get_fd(int fd, int attrnamespace, const char *attrname, void *data, size_t nbytes)
    ssize_t extattr_set_fd(int fd, int attrnamespace, const char *attrname, const void *data, size_t nbytes)
    int extattr_delete_fd(int fd, int attrnamespace, const char *attrname)
    ssize_t extattr_list_fd(int fd, int attrnamespace, void *data, size_t nbytes)

    ssize_t extattr_get_file(const char *path, int attrnamespace, const char *attrname, void *data, size_t nbytes)
    ssize_t extattr_set_file(const char *path, int attrnamespace, const char *attrname, const void *data, size_t nbytes)
    ssize_t extattr_delete_file(const char *path, int attrnamespace, const char *attrname)
    ssize_t extattr_list_file(const char *path, int attrnamespace, void *data, size_t nbytes)

    ssize_t extattr_get_link(const char *path, int attrnamespace, const char *attrname, void *data, size_t nbytes)
    ssize_t extattr_set_link(const char *path, int attrnamespace, const char *attrname, void *data, size_t nbytes)
    ssize_t extattr_delete_link(const char *path, int attrnamespace, const char *attrname)
    ssize_t extattr_list_link(const char *path, int attrnamespace, void *data, size_t nbytes)


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
        ACL_ENTRY_INHERITED

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


cdef extern from "sys/bus.h":
    cdef enum device_state:
        DS_NOTPRESENT = 10
        DS_ALIVE = 20
        DS_ATTACHING = 25
        DS_ATTACHED = 30
        DS_BUSY = 40
    ctypedef device_state device_state_t


cdef extern from "sys/syslog.h":
    enum:
        LOG_EMERG
        LOG_ALERT
        LOG_CRIT
        LOG_ERR
        LOG_WARNING
        LOG_NOTICE
        LOG_INFO
        LOG_DEBUG

    enum:
        LOG_KERN
        LOG_USER
        LOG_MAIL
        LOG_DAEMON
        LOG_AUTH
        LOG_SYSLOG
        LOG_LPR
        LOG_NEWS
        LOG_UUCP
        LOG_CRON
        LOG_AUTHPRIV
        LOG_FTP
        LOG_NTP
        LOG_SECURITY
        LOG_CONSOLE
        LOG_LOCAL0
        LOG_LOCAL1
        LOG_LOCAL2
        LOG_LOCAL3
        LOG_LOCAL4
        LOG_LOCAL5
        LOG_LOCAL6
        LOG_LOCAL7


cdef extern from "devinfo.h":
    ctypedef uintptr_t devinfo_handle_t
    ctypedef device_state_t devinfo_state_t

    cdef struct devinfo_dev:
        devinfo_handle_t dd_handle
        devinfo_handle_t dd_parent
        char *dd_name
        char *dd_desc
        char *dd_drivername
        char *dd_pnpinfo
        char *dd_location
        uint32_t dd_devflags
        uint16_t dd_flags
        devinfo_state_t dd_state

    cdef struct devinfo_rman:
        devinfo_handle_t dm_handle
        unsigned long dm_start
        unsigned long dm_size
        char *dm_desc

    cdef struct devinfo_res:
        devinfo_handle_t dr_handle
        devinfo_handle_t dr_rman
        devinfo_handle_t dr_device
        unsigned long dr_start
        unsigned long dr_size

    int devinfo_init()
    int devinfo_free()
    int devinfo_foreach_rman(int (* fn)(devinfo_rman *rman, void *arg), void *arg)
    int devinfo_foreach_rman_resource(devinfo_rman *rman, int (* fn)(devinfo_res *res, void *arg), void *arg)
    devinfo_dev *devinfo_handle_to_device(devinfo_handle_t handle)
    devinfo_res *devinfo_handle_to_resource(devinfo_handle_t handle)
    devinfo_rman *devinfo_handle_to_rman(devinfo_handle_t handle)


cdef extern from "libutil.h" nogil:
    int login_tty(int fd);
    # expose pidfile_* functions?


cdef extern from "kvm.h" nogil:
    ctypedef struct kvm_t:
        pass

    cdef struct kvm_swap:
        char ksw_devname[32]
        int ksw_used
        int ksw_total
        int ksw_flags

    int	kvm_dpcpu_setcpu(kvm_t *, unsigned int)
    char **kvm_getargv(kvm_t *, const kinfo_proc *, int)
    int	kvm_getcptime(kvm_t *, long *)
    char **kvm_getenvv(kvm_t *, const kinfo_proc *, int)
    char *kvm_geterr(kvm_t *)
    char *kvm_getfiles(kvm_t *, int, int, int *)
    int	kvm_getloadavg(kvm_t *, double [], int)
    int	kvm_getmaxcpu(kvm_t *)
    void *kvm_getpcpu(kvm_t *, int)
    kinfo_proc *kvm_getprocs(kvm_t *, int, int, int *)
    int	kvm_getswapinfo(kvm_t *, kvm_swap *, int, int)
    kvm_t *kvm_open(const char *, const char *, const char *, int, const char *)
    kvm_t *kvm_openfiles(const char *, const char *, const char *, int, char *)
    ssize_t	kvm_read(kvm_t *, unsigned long, void *, size_t)
    ssize_t	kvm_uread(kvm_t *, const kinfo_proc *, unsigned long, char *, size_t)
    ssize_t	kvm_write(kvm_t *, unsigned long, const void *, size_t)
    int kvm_close(kvm_t *);


cdef extern from "net/if.h":
    enum:
        IFNAMSIZ

    cdef struct ifreq:
        char ifr_name[IFNAMSIZ]


cdef extern from "net/bpf.h":
    enum:
        BIOCGBLEN
        BIOCSBLEN
        BIOCSETF
        BIOCFLUSH
        BIOCPROMISC
        BIOCGDLT
        BIOCGETIF
        BIOCSETIF
        BIOCSRTIMEOUT
        BIOCGRTIMEOUT
        BIOCGSTATS
        BIOCIMMEDIATE
        BIOCVERSION
        BIOCGRSIG
        BIOCSRSIG
        BIOCGHDRCMPLT
        BIOCSHDRCMPLT
        BIOCGDIRECTION
        BIOCSDIRECTION
        BIOCSDLT
        BIOCGDLTLIST
        BIOCLOCK
        BIOCSETWF
        BIOCFEEDBACK
        BIOCGETBUFMODE
        BIOCSETBUFMODE
        BIOCGETZMAX
        BIOCROTZBUF
        BIOCSETZBUF
        BIOCSETFNR
        BIOCGTSTAMP
        BIOCSTSTAMP

    enum:
        BPF_LD
        BPF_LDX
        BPF_ST
        BPF_STX
        BPF_ALU
        BPF_JMP
        BPF_RET
        BPF_MISC

    enum:
        BPF_W
        BPF_H
        BPF_B

    enum:
        BPF_IMM
        BPF_ABS
        BPF_IND
        BPF_MEM
        BPF_LEN
        BPF_MSH

    enum:
        BPF_ADD
        BPF_SUB
        BPF_MUL
        BPF_DIV
        BPF_OR
        BPF_AND
        BPF_LSH
        BPF_RSH
        BPF_NEG
        BPF_JA
        BPF_JEQ
        BPF_JGT
        BPF_JGE
        BPF_JSET

    enum:
        BPF_K
        BPF_X

    enum:
        BPF_A

    enum:
        BPF_TAX
        BPF_TXA

    enum bpf_direction:
        BPF_D_IN
        BPF_D_OUT
        BPF_D_INOUT

    cdef struct bpf_ts:
        int64_t bs_sec
        uint64_t bt_frac

    cdef struct bpf_xhdr:
        bpf_ts bh_tstamp
        uint32_t bh_caplen
        uint32_t bh_datalen
        u_short bh_hdrlen

    cdef struct bpf_insn:
        u_short code
        u_char jt
        u_char jf
        uint32_t k

    cdef struct bpf_program:
        int bf_len
        bpf_insn *bf_insns

    int BPF_WORDALIGN(int x)

cdef extern from "dlg_keys.h":
    cdef int dlg_parse_bindkey(char *binding)

cdef extern from "dialog.h" nogil:
    enum:
        DLG_EXIT_ESC
        DLG_EXIT_ERROR
        DLG_EXIT_OK
        DLG_EXIT_CANCEL

    enum:
        FLAG_CHECK
        FLAG_RADIO
        
    ctypedef struct DIALOG_LISTITEM:
        char *name
        char *text
        char *help
        int state
        
    ctypedef struct DIALOG_FORMITEM:
        unsigned type
        char *name
        char *help
        char *text
        int name_len, name_x, name_y, name_free
        int text_len, text_x, text_y, text_flen, text_ilen, text_free
        int help_free
        
    ctypedef struct DIALOG_WINDOWS:
        pass
    ctypedef struct DIALOG_STATE:
        FILE *input
        FILE *pipe_input
        FILE  *output
        int visit_items
        int visit_cols
        
    ctypedef struct DIALOG_VARS:
        int formitem_type
        int defaultno
        int default_button
        char *yes_label
        char *no_label
        char *ok_label
        char *cancel_label
        int insecure

    DIALOG_STATE dialog_state
    DIALOG_VARS dialog_vars
    
    ctypedef int (*DIALOG_INPUTMENU)(DIALOG_LISTITEM *, int, char *)
    cdef int dlg_dummy_menutext(DIALOG_LISTITEM *, int, char*)
    
    cdef void init_dialog(FILE *, FILE *)
    cdef void end_dialog()
    
    cdef void dlg_put_backtitle()
    cdef void dlg_clear()
    
    cdef int dlg_form(const char *title, const char *prompt, int height, int width,
                      int form_height, int item_no, DIALOG_FORMITEM *items,
                      int *current_item)
    cdef int dlg_menu(const char *title, const char *prompt, int height, int width,
                      int menu_heitht, int item_no, DIALOG_LISTITEM *items,
                      int *current_item, DIALOG_INPUTMENU rename_menutext)
    
    cdef void *dlg_allocate_gauge(const char *title, const char *prompt, int height, int width, int pct)
    cdef void dlg_update_gauge(void *gauge, int pct)
    cdef void dlg_free_gauge(void *gauge)
    
    cdef int dialog_msgbox(const char *title, const char *prompt, int height, int width, int pauseopt)
    cdef int dlg_checklist(const char *title, const char *prompt, int height, int width,
                           int list_height, int item_no, DIALOG_LISTITEM *items,
                           const char *states, int flag, int *current_item)
    cdef int dialog_yesno(const char *title, const char *prompt, int height, int width)
cdef extern from "sys/event.h" nogil:
    enum:
        EVFILT_READ
        EVFILT_WRITE
        EVFILT_AIO
        EVFILT_VNODE
        EVFILT_PROC
        EVFILT_SIGNAL
        EVFILT_TIMER
        EVFILT_PROCDESC
        EVFILT_FS
        EVFILT_LIO
        EVFILT_USER
        EVFILT_SENDFILE

    enum:
        EV_ADD
        EV_DELETE
        EV_ENABLE
        EV_DISABLE
        EV_FORCEONESHOT
        EV_ONESHOT
        EV_CLEAR
        EV_RECEIPT
        EV_DISPATCH
        EV_SYSFLAGS
        EV_DROP
        EV_FLAG1
        EV_FLAG2
        EV_EOF
        EV_ERROR

    enum:
        NOTE_FFNOP
        NOTE_FFAND
        NOTE_FFOR
        NOTE_FFCOPY
        NOTE_FFCTRLMASK
        NOTE_FFLAGSMASK
        NOTE_TRIGGER
        NOTE_LOWAT
        NOTE_FILE_POLL
        NOTE_DELETE
        NOTE_WRITE
        NOTE_EXTEND
        NOTE_ATTRIB
        NOTE_LINK
        NOTE_RENAME
        NOTE_REVOKE
        NOTE_OPEN
        NOTE_CLOSE
        NOTE_CLOSE_WRITE
        NOTE_READ
        NOTE_EXIT
        NOTE_FORK
        NOTE_EXEC
        NOTE_PCTRLMASK
        NOTE_PDATAMASK
        NOTE_TRACK
        NOTE_TRACKERR
        NOTE_CHILD
        NOTE_SECONDS	
        NOTE_MSECONDS	
        NOTE_USECONDS	
        NOTE_NSECONDS	

    cdef struct kevent_s "kevent":
        uintptr_t ident
        short filter
        u_short flags
        u_int fflags
        intptr_t data
        void *udata

    int kqueue()
    int kevent(int kq, const kevent_s *changelist, int nchanges, kevent_s *eventlist, int nevents, timespec *timeout)
    void EV_SET(kevent_s *kev, uintptr_t ident, short filter, u_short flags, u_int fflags, intptr_t data, void *udata)
