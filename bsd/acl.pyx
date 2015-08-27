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
import pwd
import grp
from libc.string cimport strerror
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
    SYNCHRONIZE = defs.ACL_SYNCHRONIZE


cdef class ACL(object):
    cdef defs.acl_t acl
    cdef readonly path
    cdef readonly type

    def __init__(self, path=None, text=None, acltype=ACLType.NFS4):
        self.type = acltype

        if path:
            self.path = file
            self.acl = defs.acl_get_file(path, acltype)
            return

        if text:
            self.text = text
            return

    def apply(self, path=None):
        if not path and self.path:
            path = self.path

        if not path:
            raise ValueError('Please specify path')

        if defs.acl_set_file(path, self.type, self.acl) != 0:
            raise OSError(errno, strerror(errno))

    property brand:
        def __get__(self):
            cdef int brand

            if defs.acl_get_brand_np(self.acl, &brand) != 0:
                raise OSError(errno, strerror(errno))

            return ACLBrand(brand)

    property entries:
        def __get__(self):
            cdef ACLEntry ret
            cdef defs.acl_entry_t entry
            cdef int err

            err = defs.acl_get_entry(self.acl, defs.ACL_FIRST_ENTRY, &entry)
            while err != 0:
                ret = ACLEntry.__new__(ACLEntry)
                ret.parent = self
                ret.entry = entry
                yield ret

                err = defs.acl_get_entry(self.acl, defs.ACL_NEXT_ENTRY, &entry)

    property text:
        def __get__(self):
            return defs.acl_to_text(self.acl, NULL)

        def __set__(self, text):
            self.acl = defs.acl_from_text(text)

    property valid:
        def __get__(self):
            if defs.acl_valid(self.acl) != 0:
                return True

            return False


cdef class ACLEntry(object):
    cdef readonly ACL parent
    cdef defs.acl_entry_t entry

    def __str__(self):
        return "<bsd.acl.ACLEntry type '{0}'>".format(self.tag.name)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'tag': self.tag,
            'id': self.id,
            'name': self.name,
            'perms': {k.name: v for k, v in self.perms.items()}
        }

    property tag:
        def __get__(self):
            cdef defs.acl_tag_t tag

            if defs.acl_get_tag_type(self.entry, &tag) != 0:
                raise OSError(errno, strerror(errno))

            return ACLEntryTag(tag)

    property id:
        def __get__(self):
            cdef int* qualifier

            if self.tag not in (ACLEntryTag.USER, ACLEntryTag.GROUP):
                return None

            qualifier = <int*>defs.acl_get_qualifier(self.entry)
            if qualifier is NULL:
                raise OSError(errno, strerror(errno))

            return qualifier[0]

        def __set__(self, value):
            cdef int qualifier = value

            if self.tag not in (ACLEntryTag.USER, ACLEntryTag.GROUP):
                raise ValueError('Cannot set id on ACL of that type')

            if defs.acl_set_qualifier(self.entry, &qualifier) != 0:
                raise OSError(errno, strerror(errno))

    property name:
        def __get__(self):
            try:
                if self.tag == ACLEntryTag.USER:
                    return pwd.getpwuid(self.id).pw_name

                if self.tag == ACLEntryTag.GROUP:
                    return grp.getgrgid(self.id).gr_name
            except KeyError:
                return None

            return None

        def __set__(self, value):
            if self.tag == ACLEntryTag.USER:
                uid = pwd.getpwnam(value).pw_uid
                self.id = uid
                return

            if self.tag == ACLEntryTag.GROUP:
                gid = pwd.getpwnam(value).pw_gid
                self.id = gid
                return

            raise ValueError('Cannot set name on ACL of that type')

    property perms:
        def __get__(self):
            cdef ACLPermissionSet result
            cdef defs.acl_permset_t permset

            if defs.acl_get_permset(self.entry, &permset) != 0:
                raise OSError(errno, strerror(errno))

            if self.parent.brand == ACLBrand.NFS4:
                perm_enum = NFS4Perm

            if self.parent.brand == ACLBrand.POSIX:
                perm_enum = POSIXPerm

            result = ACLPermissionSet.__new__(ACLPermissionSet)
            result.permset = permset
            result.parent = self
            result.perm_enum = perm_enum

            return result


cdef class ACLPermissionSet(object):
    cdef defs.acl_permset_t permset
    cdef readonly ACLEntry parent
    cdef object perm_enum

    def __getitem__(self, item):
        if item not in self.perm_enum:
            raise KeyError('Invalid permission identifier')

        return <bint>defs.acl_get_perm_np(self.permset, item.value)

    def __setitem__(self, key, value):
        if key not in self.perm_enum:
            raise KeyError('Invalid permission identifier')

        if value is True:
            if defs.acl_add_perm(self.permset, key.value) != 0:
                raise OSError(errno, strerror(errno))

            return

        if value is False:
            if defs.acl_delete_perm(self.permset, key.value) != 0:
                raise OSError(errno, strerror(errno))

            return

        raise ValueError('Value must be either True or False')

    def __iter__(self):
        return iter(self.perm_enum)

    def clear(self):
        if defs.acl_clear_perms(self.permset) != 0:
            raise OSError(errno, strerror(errno))

    def keys(self):
        return list(self.perm_enum)

    def items(self):
        for i in self.perm_enum:
            yield (i, self[i])
