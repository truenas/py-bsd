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
import cython
import os
import pwd
import grp
from libc.errno cimport errno
from libc.stdlib cimport malloc, free
cimport defs


class ACLType(enum.IntEnum):
    ACCESS = defs.ACL_TYPE_ACCESS
    DEFAULT = defs.ACL_TYPE_DEFAULT
    NFS4 = defs.ACL_TYPE_NFS4


class ACLBrand(enum.IntEnum):
    UNKNOWN = defs.ACL_BRAND_UNKNOWN
    POSIX = defs.ACL_BRAND_POSIX
    NFS4 = defs.ACL_BRAND_NFS4


class ACLEntryTag(enum.IntEnum):
    USER_OBJ = defs.ACL_USER_OBJ
    USER = defs.ACL_USER
    GROUP_OBJ = defs.ACL_GROUP_OBJ
    GROUP = defs.ACL_GROUP
    MASK = defs.ACL_MASK
    OTHER = defs.ACL_OTHER
    EVERYONE = defs.ACL_EVERYONE


class ACLEntryType(enum.IntEnum):
    ALLOW = defs.ACL_ENTRY_TYPE_ALLOW
    DENY = defs.ACL_ENTRY_TYPE_DENY


class POSIXPerm(enum.IntEnum):
    EXECUTE = defs.ACL_EXECUTE
    WRITE = defs.ACL_WRITE
    READ = defs.ACL_READ


class NFS4Perm(enum.IntEnum):
    READ_DATA = defs.ACL_READ_DATA
    LIST_DIRECTORY = defs.ACL_LIST_DIRECTORY
    WRITE_DATA = defs.ACL_WRITE_DATA
    ADD_FILE = defs.ACL_ADD_FILE
    APPEND_DATA = defs.ACL_APPEND_DATA
    ADD_SUBDIRECTORY = defs.ACL_ADD_SUBDIRECTORY
    READ_NAMED_ATTRS = defs.ACL_READ_NAMED_ATTRS
    WRITE_NAMED_ATTRS = defs.ACL_WRITE_NAMED_ATTRS
    EXECUTE = defs.ACL_EXECUTE
    DELETE_CHILD = defs.ACL_DELETE_CHILD
    READ_ATTRIBUTES = defs.ACL_READ_ATTRIBUTES
    WRITE_ATTRIBUTES = defs.ACL_WRITE_ATTRIBUTES
    DELETE = defs.ACL_DELETE
    READ_ACL = defs.ACL_READ_ACL
    WRITE_ACL = defs.ACL_WRITE_ACL
    WRITE_OWNER = defs.ACL_WRITE_OWNER
    SYNCHRONIZE = defs.ACL_SYNCHRONIZE


class NFS4BasicPermset(enum.IntEnum):
    NOPERMS = 0
    FULL_CONTROL = defs.ACL_FULL_SET
    MODIFY = defs.ACL_MODIFY_SET
    READ = defs.ACL_READ_SET|defs.ACL_EXECUTE
    TRAVERSE = defs.ACL_EXECUTE|defs.ACL_READ_NAMED_ATTRS|defs.ACL_READ_ATTRIBUTES|defs.ACL_READ_ACL


class NFS4BasicFlagset(enum.IntEnum):
    NOINHERIT = 0
    INHERIT = defs.ACL_ENTRY_FILE_INHERIT|defs.ACL_ENTRY_DIRECTORY_INHERIT


class NFS4Flag(enum.IntEnum):
    FILE_INHERIT = defs.ACL_ENTRY_FILE_INHERIT
    DIRECTORY_INHERIT = defs.ACL_ENTRY_DIRECTORY_INHERIT
    NO_PROPAGATE_INHERIT = defs.ACL_ENTRY_NO_PROPAGATE_INHERIT
    INHERIT_ONLY = defs.ACL_ENTRY_INHERIT_ONLY
    INHERITED = defs.ACL_ENTRY_INHERITED


cdef class ACL(object):
    cdef defs.acl_t acl
    cdef readonly fobj
    cdef readonly type
    cdef object _link

    def __init__(self, file=None, acltype=ACLType.NFS4, follow_links=False):
        """
        :file: use acl_get_* syscalls, which returns a pointer to the ACL that was retrieved
        On failure, a value of (acl_t)NULL is returned, and errno set to indicate error.

        If file not set, then call acl_init() to allocate and initialize an ACL.
        In all cases this will allocate memory, which must be freed via acl_free.
        """
        from sys import stderr as ref_file
        self.type = acltype
        self._link = follow_links
        cdef defs.acl_type_t aclt
        cdef int fd
        cdef char *fn
        aclt = acltype

        if file:
            self.fobj = file

        if self.fobj:
            if isinstance(self.fobj, str):
                file = file.encode('UTF-8')
                fn = file 
                if self._link:
                    with nogil:
                        self.acl = defs.acl_get_link_np(fn, aclt)
                else:
                    with nogil:
                        self.acl = defs.acl_get_file(fn, aclt)

            elif type(self.fobj) is type(ref_file):
                fd = self.fobj.fileno()
                with nogil:
                    self.acl = defs.acl_get_fd_np(fd, aclt)
            elif type(self.fobj) is int:
                fd = self.fobj
                with nogil:
                    self.acl = defs.acl_get_fd_np(fd, aclt)
            else:
                raise ValueError("Invalid type for path")

            if self.acl is None:
                raise OSError(errno, os.strerror(errno))

            return

        self.acl = defs.acl_init(0)

    def __dealloc__(self):
        defs.acl_free(<void *>self.acl)

    def __getstate__(self):
        return [i.__getstate__() for i in self.entries]

    def __setstate__(self, value):
        self.clear()
        for e in value:
            entry = self.add()
            entry.__setstate__(e)

    def apply(self, file=None):
        from sys import stderr as ref_file
        cdef int rv, fd
        cdef defs.acl_type_t aclt
        cdef defs.acl_t newacl
        cdef char *fn

        if not file and self.fobj:
            file = self.fobj

        if not file:
            raise ValueError('Please specify path')

        aclt = self.type
        newacl = self.acl

        if isinstance(file, str):
            file = file.encode('UTF-8')
            fn = file
            if self._link:
                with nogil:
                    rv = defs.acl_set_link_np(fn, aclt, newacl)
            else:
                with nogil:
                    rv = defs.acl_set_file(fn, aclt, newacl)

        elif type(file) is type(ref_file):
            fd = file.fileno()
            with nogil:
                rv = defs.acl_set_fd_np(fd, newacl, aclt)

        elif type(file) is int:
            fd = file
            with nogil:
                rv = defs.acl_set_fd_np(fd, newacl, aclt)
        else:
            raise ValueError("Invalid type for file parameter")

        if rv != 0:
            raise OSError(errno, os.strerror(errno))

    def add(self, index=None):
        cdef int rv, idx
        cdef ACLEntry ret
        cdef defs.acl_entry_t entry

        if index:
            idx = index
            with nogil:
                rv = defs.acl_create_entry_np(&self.acl, &entry, idx)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))
        else:
            with nogil:
                rv = defs.acl_create_entry(&self.acl, &entry)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

        ret = ACLEntry.__new__(ACLEntry)
        ret.parent = self
        ret.entry = entry
        return ret

    def delete(self, index):
        if defs.acl_delete_entry_np(self.acl, index) != 0:
            raise OSError(errno, os.strerror(errno))

    def clear(self):
        while len(self.entries) > 0:
            self.delete(0)

    def strip(self):
        """
        Strip extended ACL entries from the ACL. acl_strip_np() allocates
        memory. Free the memory of the original ACL before updating self.acl.
        Returns a pointer to a trivial ACL computed from initial ACL.
        ACL is trivial if it can be fully expressed as a file mode without losing
        any access rules.
        """
        cdef int rv
        cdef defs.acl_t newacl 
        with nogil:
            newacl = defs.acl_strip_np(self.acl, True)
        if newacl is None: 
            raise OSError(errno, os.strerror(errno))

        with nogil:
            rv = defs.acl_free(<void *>self.acl)
        if rv != 0:
            raise OSError(errno, os.strerror(errno))

        self.acl = newacl

    property is_trivial:
        def __get__(self):
            """
            ACL is trivial if it can be fully expressed as a file mode without losing
            any access rules.
            """
            cdef int rv
            cdef int trivial
            with nogil:
                rv = defs.acl_is_trivial_np(self.acl, &trivial)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return <bint>trivial

    property brand:
        def __get__(self):
            cdef int brand, ret

            with nogil:
                ret = defs.acl_get_brand_np(self.acl, &brand)

            if ret != 0:
                raise OSError(errno, os.strerror(errno))

            return ACLBrand(brand)

    property entries:
        def __get__(self):
            cdef ACLEntry ret
            cdef defs.acl_entry_t entry
            cdef int err

            result = []
            with nogil:
                err = defs.acl_get_entry(self.acl, defs.ACL_FIRST_ENTRY, &entry)
            if err != 1:
                return []

            while True:
                ret = ACLEntry.__new__(ACLEntry)
                ret.parent = self
                ret.entry = entry
                result.append(ret)
                with nogil:
                    err = defs.acl_get_entry(self.acl, defs.ACL_NEXT_ENTRY, &entry)
                if err != 1:
                    break

            return result

    property is_valid:
        def __get__(self):
            """
            Original version used acl_valid(), returns -1 with errno EINVAL if brand is not ACL_BRAND_POSIX
            we should use acl_valid_fd_np(), acl_valid_file_np(), etc to allow ACL_BRAND_NFS4
            zfs_freebsd_aclcheck() always returns EOPNOTSUPP. This may change in the future, but for now 
            we return True in this case.
            """
            cdef int ret, fd
            cdef char *fn
            cdef defs.acl_type_t aclt
            aclt = self.type
            from sys import stderr as ref_file

            if isinstance(self.fobj, str):
                file = self.fobj.encode('UTF-8')
                fn = file 
                if self._link:
                    with nogil:
                        ret = defs.acl_valid_link_np(fn, aclt, self.acl)
                else:
                    with nogil:
                        ret = defs.acl_valid_file_np(fn, aclt, self.acl)
            elif type(self.fobj) is type(ref_file):
                fd = self.fobj.fileno()
                with nogil:
                    ret = defs.acl_valid_fd_np(fd, aclt, self.acl)
            elif type(self.fobj) is int:
                fd = self.fobj
                with nogil:
                    ret = defs.acl_valid_fd_np(fd, aclt, self.acl)
            else:
                raise ValueError("ACL validation requires a file path or fd.")

            if ret != 0 and errno != 45:
                raise OSError(errno, os.strerror(errno))

            return True 


cdef class ACLEntry(object):
    cdef readonly ACL parent
    cdef defs.acl_entry_t entry

    def __str__(self):
        return "<bsd.acl.ACLEntry type '{0}'>".format(self.tag.name)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'tag': self.tag.name,
            'id': self.id,
            'type': self.type.name,
            'perms': {k.name: v for k, v in self.perms.items()},
            'flags': {k.name: v for k, v in self.flags.items()},
        }

    def __setstate__(self, obj):
        if 'tag' in obj:
            self.tag = obj['tag']

        if obj.get('id') is not None:
            self.id = obj['id']

        if 'type' in obj:
            self.type = obj['type']

        if 'perms' in obj:
            self.perms = obj['perms']

        if 'flags' in obj:
            self.flags = obj['flags']

    def delete(self):
        cdef int ret
        with nogil:
            ret = defs.acl_delete_entry(self.parent.acl, self.entry)
        if ret != 0:
            raise OSError(errno, os.strerror(errno))

    property tag:
        def __get__(self):
            cdef int rv
            cdef defs.acl_tag_t tag

            with nogil:
                rv = defs.acl_get_tag_type(self.entry, &tag)

            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return ACLEntryTag(tag)

        def __set__(self, value):
            cdef int rv
            cdef defs.acl_tag_t tag
            tag = ACLEntryTag[value]

            with nogil:
                rv = defs.acl_set_tag_type(self.entry, tag)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

    property id:
        def __get__(self):
            cdef int* qualifier

            if self.tag not in (ACLEntryTag.USER, ACLEntryTag.GROUP):
                return None
            with nogil:
                qualifier = <int*>defs.acl_get_qualifier(self.entry)
            if qualifier is NULL:
                raise OSError(errno, os.strerror(errno))

            return qualifier[0]

        def __set__(self, value):
            cdef int rv
            cdef int qualifier = value

            if self.tag not in (ACLEntryTag.USER, ACLEntryTag.GROUP):
                raise ValueError('Cannot set id on ACL of that type')

            with nogil:
                rv = defs.acl_set_qualifier(self.entry, &qualifier)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

    property perms:
        def __get__(self):
            cdef int rv
            cdef ACLPermissionSet result
            cdef defs.acl_permset_t permset

            with nogil:
                rv = defs.acl_get_permset(self.entry, &permset)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            if self.parent.brand == ACLBrand.NFS4:
                perm_enum = NFS4Perm

            if self.parent.brand == ACLBrand.POSIX:
                perm_enum = POSIXPerm

            result = ACLPermissionSet.__new__(ACLPermissionSet)
            result.permset = permset
            result.parent = self
            result.perm_enum = perm_enum

            return result

        def __set__(self, value):
            cdef int rv
            cdef defs.acl_perm_t perm
            cdef defs.acl_permset_t permset

            with nogil:
                rv = defs.acl_get_permset(self.entry, &permset)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            for k, v in value.items():
                if v:
                    perm = NFS4Perm[k]
                    with nogil:
                        rv = defs.acl_add_perm(permset, perm)
                    if rv != 0:
                        raise OSError(errno, os.strerror(errno))

    property flags:
        def __get__(self):
            cdef int rv
            cdef ACLFlagSet result
            cdef defs.acl_flagset_t flagset

            with nogil:
                rv = defs.acl_get_flagset_np(self.entry, &flagset)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            result = ACLFlagSet.__new__(ACLFlagSet)
            result.flagset = flagset
            result.parent = self
            return result

        def __set__(self, value):
            cdef int rv
            cdef defs.acl_flag_t flag
            cdef defs.acl_flagset_t flagset
            with nogil:
                rv = defs.acl_get_flagset_np(self.entry, &flagset)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            for k, v in value.items():
                if v:
                    flag = NFS4Flag[k]
                    with nogil:
                        rv = defs.acl_add_flag_np(flagset, flag)
                    if rv != 0:
                        raise OSError(errno, os.strerror(errno))

    property type:
        def __get__(self):
            cdef int rv
            cdef defs.acl_entry_type_t typ

            with nogil:
                rv = defs.acl_get_entry_type_np(self.entry, &typ)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return ACLEntryType(typ)

        def __set__(self, value):
            cdef int rv
            cdef int acl_type
            if ACLEntryType[value] not in (ACLEntryType.ALLOW, ACLEntryType.DENY):
                raise ValueError('Unsupported ACL type.')

            acl_type = ACLEntryType[value]

            with nogil:
                rv = defs.acl_set_entry_type_np(self.entry, acl_type)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))


cdef class ACLPermissionSet(object):
    cdef defs.acl_permset_t permset
    cdef readonly ACLEntry parent
    cdef object perm_enum
    cdef int rv

    def __getitem__(self, item):
        cdef defs.acl_perm_t perm
        if isinstance(item, str):
            item = getattr(self.perm_enum, item)

        if item not in self.perm_enum:
            raise KeyError('Invalid permission identifier')

        perm = item.value
        with nogil:
            rv = defs.acl_get_perm_np(self.permset, perm)
        if rv == -1:
            raise OSError(errno, os.strerror(errno))

        return <bint>rv

    def __setitem__(self, key, value):
        cdef defs.acl_perm_t perm
        if isinstance(key, str):
            key = getattr(self.perm_enum, key)

        if key not in self.perm_enum:
            raise KeyError('Invalid permission identifier')

        perm = key.value
        if value is True:
            with nogil:
                rv = defs.acl_add_perm(self.permset, perm)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return

        if value is False:
            with nogil:
                rv = defs.acl_delete_perm(self.permset, perm)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return

        raise ValueError('Value must be either True or False')

    def __iter__(self):
        return iter(self.perm_enum)

    def clear(self):
        with nogil:
            rv = defs.acl_clear_perms(self.permset)
        if rv != 0:
            raise OSError(errno, os.strerror(errno))

    def keys(self):
        return list(self.perm_enum)

    def items(self):
        for i in self.perm_enum:
            yield (i, self[i])


cdef class ACLFlagSet(object):
    cdef defs.acl_flagset_t flagset
    cdef readonly ACLEntry parent
    cdef int rv

    def __getitem__(self, item):
        cdef defs.acl_flag_t flag
        if isinstance(item, str):
            item = getattr(NFS4Flag, item)

        if item not in NFS4Flag:
            raise KeyError('Invalid flag')

        flag = item.value
        with nogil:
            rv = defs.acl_get_flag_np(self.flagset, flag)
        if rv == -1:
            raise OSError(errno, os.strerror(errno))

        return <bint>rv

    def __setitem__(self, key, value):
        cdef defs.acl_flag_t flag
        if isinstance(key, str):
            key = getattr(NFS4Flag, key)

        if key not in NFS4Flag:
            raise KeyError('Invalid flag')

        flag = key.value
        if value is True:
            with nogil:
                rv = defs.acl_add_flag_np(self.flagset, flag)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return

        if value is False:
            with nogil:
                rv = defs.acl_delete_flag_np(self.flagset, flag)
            if rv != 0:
                raise OSError(errno, os.strerror(errno))

            return

        raise ValueError('Value must be either True or False')

    def __iter__(self):
        return iter(NFS4Flag)

    def clear(self):
        with nogil:
            rv = defs.acl_clear_flags_np(self.flagset)
        if rv != 0:
            raise OSError(errno, os.strerror(errno))

    def keys(self):
        return list(NFS4Flag)

    def items(self):
        for i in NFS4Flag:
            yield (i, self[i])
