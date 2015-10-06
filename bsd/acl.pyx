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
    SYNCHRONIZE = defs.ACL_SYNCHRONIZE


class NFS4Flag(enum.IntEnum):
    FILE_INHERIT = defs.ACL_ENTRY_FILE_INHERIT
    DIRECTORY_INHERIT = defs.ACL_ENTRY_DIRECTORY_INHERIT
    NO_PROPAGATE_INHERIT = defs.ACL_ENTRY_NO_PROPAGATE_INHERIT
    INHERIT_ONLY = defs.ACL_ENTRY_INHERIT_ONLY


cdef class ACL(object):
    cdef defs.acl_t acl
    cdef readonly fobj
    cdef readonly type
    cdef object _link
    
    def __init__(self, file=None, text=None, acltype=ACLType.NFS4, follow_links=False):
        from sys import stderr as ref_file
        self.type = acltype
        self._link = follow_links
        
        if file:
            self.fobj = file
            
        if self.fobj and text:
            raise ValueError("Only one of file/path and text may be given")
        
        if self.fobj:
            if isinstance(self.fobj, basestring):
                if self._link:
                    self.acl = defs.acl_get_link_np(self.fobj, acltype)
                else:
                    self.acl = defs.acl_get_file(self.fobj, acltype)
            elif type(self.fobj) is type(ref_file):
                self.acl = defs.acl_get_fd_np(self.fobj.fileno(), acltype)
            elif type(self.fobj) is int:
                self.acl = defs.acl_get_fd_np(self.fobj, acltype)
            else:
                raise ValueError("Invalid type for path")

            return

        if text:
            self.text = text
            return

        self.acl = defs.acl_init(0)

    def __getstate__(self):
        return [i.__getstate__() for i in self.entries]

    def __setstate__(self, value):
        self.clear()
        for e in value:
            entry = self.add()
            entry.__setstate__(e)

    def apply(self, file=None):
        from sys import stderr as ref_file
        
        if not file and self.fobj:
            file = self.fobj

        if not file:
            raise ValueError('Please specify path')

        if type(file) is str:
            if self._link:
                rv = defs.acl_set_link_np(file, self.type, self.acl)
            else:
                rv = defs.acl_set_file(file, self.type, self.acl)
        elif type(file) is type(ref_file):
            rv = defs.acl_set_fd_np(file.fileno(), self.acl, self.type)
        elif type(file) is int:
            rv = defs.acl_set_fd_np(file, self.acl, self.type)
        else:
            raise ValueError("Invalid type for file parameter")
        
        if rv != 0:
            raise OSError(errno, strerror(errno))

    def add(self, index=None):
        cdef ACLEntry ret
        cdef defs.acl_entry_t entry

        if index:
            if defs.acl_create_entry_np(&self.acl, &entry, index) != 0:
                raise OSError(errno, strerror(errno))
        else:
            if defs.acl_create_entry(&self.acl, &entry) != 0:
                raise OSError(errno, strerror(errno))

        ret = ACLEntry.__new__(ACLEntry)
        ret.parent = self
        ret.entry = entry
        return ret

    def delete(self, index):
        if defs.acl_delete_entry_np(self.acl, index) != 0:
            raise OSError(errno, strerror(errno))

    def clear(self):
        for i in self.entries:
            i.delete()

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

            result = []
            err = defs.acl_get_entry(self.acl, defs.ACL_FIRST_ENTRY, &entry)
            while err != 0:
                ret = ACLEntry.__new__(ACLEntry)
                ret.parent = self
                ret.entry = entry
                result.append(ret)

                err = defs.acl_get_entry(self.acl, defs.ACL_NEXT_ENTRY, &entry)

            return result

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
            'tag': self.tag.name,
            'id': self.id,
            'name': self.name,
            'type': self.type.name,
            'perms': {k.name: v for k, v in self.perms.items()},
            'flags': {k.name: v for k, v in self.flags.items()},
            'text': self.text
        }

    def __setstate__(self, obj):
        if 'text' in obj:
            self.text = obj['text']

        if 'id' in obj:
            self.id = obj['id']

        if 'name' in obj:
            self.name = obj['name']

        if 'type' in obj:
            self.type = obj['type']

        if 'perms' in obj:
            for k, v in obj['perms']:
                self.perms[k] = v

        if 'flags' in obj:
            for k, v in obj['flags']:
                self.flags[k] = v


    def delete(self):
        if defs.acl_delete_entry(self.parent.acl, self.entry) != 0:
            raise OSError(errno, strerror(errno))

    property tag:
        def __get__(self):
            cdef defs.acl_tag_t tag

            if defs.acl_get_tag_type(self.entry, &tag) != 0:
                raise OSError(errno, strerror(errno))

            return ACLEntryTag(tag)

        def __set__(self, value):
            cdef defs.acl_tag_t tag

            tag = value.value
            if defs.acl_set_tag_type(self.entry, tag) != 0:
                raise OSError(errno, strerror(errno))

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

        def __set__(self, ACLPermissionSet value):
            pass

    property flags:
        def __get__(self):
            cdef ACLFlagSet result
            cdef defs.acl_flagset_t flagset

            if defs.acl_get_flagset_np(self.entry, &flagset) != 0:
                raise OSError(errno, strerror(errno))

            result = ACLFlagSet.__new__(ACLFlagSet)
            result.flagset = flagset
            result.parent = self
            return result

        def __set__(self, ACLFlagSet value):
            pass

    property type:
        def __get__(self):
            cdef defs.acl_entry_type_t typ

            if defs.acl_get_entry_type_np(self.entry, &typ) != 0:
                raise OSError(errno, strerror(errno))

            return ACLEntryType(typ)

        def __set__(self, value):
            pass

    property text:
        def __get__(self):
            cdef defs.acl_t acl
            cdef defs.acl_entry_t entry
            cdef char* result

            acl = defs.acl_init(0)

            if <void*>acl == NULL:
                raise OSError(errno, strerror(errno))

            if defs.acl_create_entry(&acl, &entry) != 0:
                defs.acl_free(<void*>acl)
                raise OSError(errno, strerror(errno))

            if defs.acl_copy_entry(entry, self.entry) != 0:
                defs.acl_free(<void*>acl)
                raise OSError(errno, strerror(errno))

            result = defs.acl_to_text(acl, NULL)
            if result == NULL:
                defs.acl_free(<void*>acl)
                raise OSError(errno, strerror(errno))

            defs.acl_free(<void*>acl)
            return result.strip()

        def __set__(self, value):
            cdef defs.acl_t acl
            cdef defs.acl_entry_t entry
            cdef int brand

            acl = defs.acl_from_text(value)

            if <void*>acl == NULL:
                raise OSError(errno, strerror(errno))

            if defs.acl_get_entry(acl, defs.ACL_FIRST_ENTRY, &entry) == -1:
                defs.acl_free(<void*>acl)
                raise OSError(errno, strerror(errno))

            if defs.acl_get_brand_np(acl, &brand) != 0:
                defs.acl_free(<void*>acl)
                raise OSError(errno, strerror(errno))

            if defs.acl_copy_entry(self.entry, entry) != 0:
                defs.acl_free(<void*>acl)
                raise OSError(errno, strerror(errno))

            defs.acl_free(<void*>acl)


cdef class ACLPermissionSet(object):
    cdef defs.acl_permset_t permset
    cdef readonly ACLEntry parent
    cdef object perm_enum

    def __init__(self):
        self.permset = <defs.acl_permset_t>malloc(cython.sizeof(defs.acl_permset_t))

    def __getitem__(self, item):
        if isinstance(item, basestring):
            item = getattr(self.perm_enum, item)

        if item not in self.perm_enum:
            raise KeyError('Invalid permission identifier')

        return <bint>defs.acl_get_perm_np(self.permset, item.value)

    def __setitem__(self, key, value):
        if isinstance(key, basestring):
            key = getattr(self.perm_enum, key)

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


cdef class ACLFlagSet(object):
    cdef defs.acl_flagset_t flagset
    cdef readonly ACLEntry parent

    def __getitem__(self, item):
        if isinstance(item, basestring):
            item = getattr(NFS4Flag, item)

        if item not in NFS4Flag:
            raise KeyError('Invalid flag')

        return <bint>defs.acl_get_flag_np(self.flagset, item.value)

    def __setitem__(self, key, value):
        if isinstance(key, basestring):
            key = getattr(NFS4Flag, key)

        if key not in NFS4Flag:
            raise KeyError('Invalid flag')

        if value is True:
            if defs.acl_add_flag_np(self.flagset, key.value) != 0:
                raise OSError(errno, strerror(errno))

            return

        if value is False:
            if defs.acl_delete_flag_np(self.flagset, key.value) != 0:
                raise OSError(errno, strerror(errno))

            return

        raise ValueError('Value must be either True or False')

    def __iter__(self):
        return iter(NFS4Flag)

    def clear(self):
        if defs.acl_clear_flags_np(self.flagset) != 0:
            raise OSError(errno, strerror(errno))

    def keys(self):
        return list(NFS4Flag)

    def items(self):
        for i in NFS4Flag:
            yield (i, self[i])
