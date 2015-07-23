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

from libc.stdint cimport *


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
        MNT_SUIDDIR
        MNT_SOFTDEP
        MNT_NOSYMFOLLOW
        MNT_GJOURNAL
        MNT_MULTILABEL
        MNT_ACLS
        MNT_NOATIME
        MNT_NOCLUSTERR
        MNT_NOCLUSTERW
        MNT_SUJ
        MNT_AUTOMOUNTED

    ctypedef struct fsid_t:
        int32_t val[2]

    ctypedef int uid_t

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