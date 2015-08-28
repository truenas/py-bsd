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
import cython
import pwd
import grp
from libc.string cimport strerror, memcpy
from libc.errno cimport errno
from libc.stdlib cimport malloc, free
cimport defs

USER = defs.EXTATTR_NAMESPACE_USER_STRING
SYSTEM = defs.EXTATTR_NAMESPACE_SYSTEM_STRING
_namespaces = {
    USER : defs.EXTATTR_NAMESPACE_USER,
    SYSTEM : defs.EXTATTR_NAMESPACE_SYSTEM,
}

def Get(fobj, namespace = USER, attrname = None, follow = True):
    """Wrapper for extattr_get(3) API.

    :Parameters:
	- fobj (file, str, int):  the file object upon which to operate.
		If a string, this is the path; if a file, the file object
		on which to operate; if an integer, the file descriptor.
	- namespace (string):  The namespace to use.  Currently, either
		extattr.USER or extattr.SYSTEM (defaults to extattr.USER).
	- attrname (str):  the extended attribute to get.  If None, it
		will return all extended attributes for the given
		file and namespace.
    	- follow (bool):  If the file is a pathname, and is a symbolic link,
		follow (or do not follow) the link.  Default is to not follow.

    :Raises:
	OSError:  the corresponding extattr_get system call failed.
	MemoryError:  ran out of memory.
	ValueError:  a parameter had a bad value.

    :Returns:
	A dictionary mapping the name to value.
    """
    cdef:
        char *ns_pointer
        char *ea_name
        char *data_buffer
        size_t nbytes

    if namespace not in _namespaces:
        raise ValueError("Invalid namespace %s" % namespace)
    else:
        ns = _namespaces[namespace]
        
    if attrname is None:
        attrs = List(fobj, namespace, follow)
    else:
        attrs = [attrname]
    retval = {}

    for ea in attrs:
        ea_name = ea
        try:
            if type(fobj) is file:
                kr = defs.extattr_get_fd(fobj.fileno(), ns, ea_name, NULL, 0)
            elif type(fobj) is int:
                kr = defs.extattr_get_fd(fobj, ns, ea_name, NULL, 0)
            elif type(fobj) is str:
                pname = fobj
                if follow:
                    kr = defs.extattr_get_file(pname, ns, ea_name, NULL, 0)
                else:
                    kr = defs.extattr_get_link(pname, ns, ea_name, NULL, 0)
            else:
                raise ValueError("Unknown file type")

            if kr == -1:
                raise OSError(errno, os.strerror(errno))
            if kr > 0:
                nbytes = kr
                data_buffer = <char*>malloc(nbytes)
                if not data_buffer:
                    raise MemoryError()

                if type(fobj) is file:
                    kr = defs.extattr_get_fd(fobj.fileno(), ns, ea_name, data_buffer, nbytes)
                elif type(fobj) is int:
                    kr = defs.extattr_get_fd(fobj, ns, ea_name, data_buffer, nbytes)
                elif type(fobj) is str:
                    if follow:
                        kr = defs.extattr_get_file(pname, ns, ea_name, data_buffer, nbytes)
                    else:
                        kr = defs.extattr_get_link(pname, ns, ea_name, data_buffer, nbytes)
                # No need to check for another type, because the first pass would have caught it
                if kr == -1:
                    raise OSError(errno, os.strerror(errno))
                # Now, data_buffer contains the EA value.
                # This may be binary data, or it may be a string.
                # So let's try converting it to a utf-8 string.
                try:
                    retval[ea] = str(data_buffer[:nbytes], "utf-8")
                except:
                    retval[ea] = bytes(data_buffer[:nbytes])
                free(data_buffer)
                data_buffer = NULL

        finally:
            if data_buffer:
                free(data_buffer)

    return retval

def Delete(fobj, namespace = USER, attrname = None, follow = True):
    """Wrapper for extattr_delete(3) API.

    :Parameters:
	- fobj (file, str, int):  the file object upon which to operate.
		If a string, this is the path; if a file, the file object
		on which to operate; if an integer, the file descriptor.
	- namespace (string):  The namespace to use.  Currently, either
		extattr.USER or extattr.SYSTEM (defaults to extattr.USER).
	- attrname (str):  the extended attribute to delete.  If None, it
		will delete all extended attributes for the given
		file and namespace.
    	- follow (bool):  If the file is a pathname, and is a symbolic link,
		follow (or do not follow) the link.  Default is to not follow.

    :Raises:
	OSError:  the corresponding extattr_get system call failed.
        ValueError:  One of the parameters had a bad value
        MemoryError:  Out of memory

    :Returns:
        True if it succeeds.  (An error is raised otherwise.)
    """
    cdef:
        char *ea_name

    if namespace not in _namespaces:
        raise ValueError("Invalid namespace %s" % namespace)
    else:
        ns = _namespaces[namespace]
        
    if attrname is None:
        attrs = List(fobj, namespace, follow)
    else:
        attrs = [attrname]
    retval = {}

    for ea in attrs:
        ea_name = ea
        if type(fobj) is file:
            kr = defs.extattr_delete_fd(fobj.fileno(), ns, ea_name)
        elif type(fobj) is int:
            kr = defs.extattr_delete_fd(fobj, ns, ea_name)
        elif type(fobj) is str:
            pname = fobj
            if follow:
                kr = defs.extattr_delete_file(pname, ns, ea_name)
            else:
                kr = defs.extattr_delete_link(pname, ns, ea_name)
        else:
            raise ValueError("Unknown file type")

        if kr == -1:
            raise OSError(errno, os.strerror(errno))

    return True

def List(fobj, namespace = USER, follow = True):
    """Wrapper for extattr_list(3) API.

    :Parameters:
	- fobj (file, str, int):  the file object upon which to operate.
		If a string, this is the path; if a file, the file object
		on which to operate; if an integer, the file descriptor.
	- namespace (string):  The namespace to use.  Currently, either
		extattr.USER or extattr.SYSTEM (defaults to extattr.USER).
    	- follow (bool):  If the file is a pathname, and is a symbolic link,
		follow (or do not follow) the link.  Default is to not follow.

    :Raises:
	OSError:  the corresponding extattr_get system call failed.
	ValueError:  An invalid namespace was given.
	MemoryError:  Out of memory

    :Returns:
	A list of attributes for the given file and namespace.
    """
    cdef:
        char *pname
        char *data_buffer
        size_t nbytes
        ssize_t kr
        unsigned char *ptr
        int ns
        
    retval = []
    pname = NULL
    data_buffer = NULL
    
    if namespace not in _namespaces:
        raise ValueError("Invalid namespace %s" % namespace)
    else:
        ns = _namespaces[namespace]
        
    try:
        if type(fobj) is file:
            kr = defs.extattr_list_fd(fobj.fileno(), ns, data_buffer, 0)
        elif type(fobj) is int:
            kr = defs.extattr_list_fd(fobj, ns, data_buffer, 0)
        elif type(fobj) is str:
            pname = fobj
            if follow:
                kr = defs.extattr_list_file(pname, ns, NULL, 0)
            else:
                kr = defs.extattr_list_link(pname, ns, NULL, 0)
        else:
            raise ValueError("Unknown file type")
        
        if kr == -1:
            raise OSError(errno, os.strerror(errno))

        if kr > 0:
            nbytes = kr
            data_buffer = <char*>malloc(nbytes)
            if not data_buffer:
                raise MemoryError()
        
            if type(fobj) is file:
                kr = defs.extattr_list_file(fobj.fileno(), ns, data_buffer, nbytes)
            elif type(fobj) is int:
                kr = defs.exattr_list_file(fobj, ns, data_buffer, nbytes)
            elif type(fobj) is str:
                if follow:
                    kr = defs.extattr_list_file(pname, ns, data_buffer, nbytes)
                else:
                    kr = defs.extattr_list_link(pname, ns, data_buffer, nbytes)

            if kr == -1:
                raise OSError(errno, os.strerror(errno))

            # At this point, data_buffer has the list of names
            ptr = <unsigned char*>data_buffer
            while ptr < <unsigned char*>(data_buffer + nbytes):
                eaname_len = ptr[0]
                eaname = (ptr+1)[:eaname_len]
                retval.append(eaname)
                ptr += eaname_len + sizeof(unsigned char)

        return retval

    finally:
        if data_buffer:
            free(data_buffer)
            
