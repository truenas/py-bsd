#+
# Copyright 2015 iXsystems, Inc.
# All rights reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted providing that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#####################################################################

import os
import errno
import shutil
import bsd.extattr
from ._bsd import SeekConstants

def count_files(directory):
    files = []
    for path, dirs, filenames in os.walk(directory):
        files.extend(filenames)

    return len(files)


# Perhaps this should move to **kwargs
def copytree(src, dst,
             symlinks=False,
             progress_callback=None,
             xattr=False,
             xattr_filter=None,
             xattr_error_callback=None,
             exclude=None,
             error_cb=None,
             badfile_cb=None,
             ):
    """
    :Paramaters:
    src (str):  Source filesystem object to copy.
    dst (str):  Destination for copy.
    symlinks (bool):  If True, copy a symbolic link;
        if False, copy what it points to.  Defaults to False.
    progress_callback (callable):  Called with src and dst for each file
        (not each filesystem object).  Defaults to None.
    xattr (object):  Whether or not to copy extended attributes.
        If a boolean, True or False indicates whether to copy;
        if a string, or list, indicates which namespaces to attempt to copy.
        When True, it will attempt to copy all extattr namespaces.
        Defaults to False.
    xattr_filter (callable):  A callable object that takes the src, namespace and name
        (three parameters) of the extended attribute being considered.  Return True to copy,
        and False to skip.  Defaults to None.
    xattr_error_callback (callable):  A callable object that takes the name of the filesystem
        object, namespace, name, and OSError exception (as four parameters) in the event
        of an error getting or setting the named EA.  Return True to ignore the error and
        continue, and False to allow it to raise the OSError exception.  Defaults to None.
            If the name of the EA argument (third argument) is None, the error occurred getting
        the list of EA names.
    exclude (list): List of names at src path to be excluded from the copy
    error_cb (callable): When defined, takes src, dst and reason and call callback instead of
        raising OSError and shutil.error errors
    badfile_cb (callable):  When defined, takes src, which is the path to an incompatible file.
        (Only files, directories, and symlinks can be copied.)  Callback is expected to examine
        the file itself, and raise an exception to indicate error, otherwise it will simply be
        skipped. When not defined, an error will be raised.
    """
    def call_error_cb(*args):
        for arg in args:
            if isinstance(arg, shutil.Error):
                call_error_cb(*arg.args[0])

            elif isinstance(arg, (tuple, list)):
                if len(arg) == 3 and not any(isinstance(a, (tuple, list, shutil.Error)) for a in arg):
                    error_cb(*arg)
                else:
                    call_error_cb(*arg)

    if symlinks and os.path.islink(src):
        names = [src]
        directory = False
    elif os.path.isfile(src):
        names = [src]
        directory = False
    elif os.path.isdir(src):
        directory = True
        names = os.listdir(src)
        try:
            os.makedirs(dst)
        except OSError as err:
            if err.errno == errno.EEXIST:
                pass

    errors = []

    names = [name for name in names if not exclude or name not in exclude]

    for name in names:
        if directory:
            srcname = os.path.join(src, name)
            dstname = os.path.join(dst, name)
        else:
            srcname = name
            dstname = dst
            
        try:
            if symlinks and os.path.islink(srcname):
                linkto = os.readlink(srcname)
                os.symlink(linkto, dstname)
            elif os.path.isdir(srcname):
                copytree(srcname, dstname, symlinks,
                         progress_callback=progress_callback,
                         xattr=xattr,
                         xattr_filter=xattr_filter,
                         xattr_error_callback=xattr_error_callback,
                         exclude=exclude,
                         error_cb=error_cb,
                         badfile_cb=badfile_cb)
            elif not os.path.islink(srcname) \
                and not os.path.isdir(srcname) \
                and not os.path.isfile(srcname):
                if badfile_cb:
                    badfile_cb(srcname)
                    continue
                else:
                    raise OSError(errno.EPERM, errno.errorcode[errno.EPERM], srcname)
            else:
                if progress_callback:
                    progress_callback(srcname, dstname)

                with open(srcname, "rb") as infile:
                    end_pos = os.fstat(infile.fileno()).st_size
                    cur_pos = 0
                    if os.path.isdir(dstname):
                        dstname = os.path.join(dstname, os.path.basename(srcname))
                    with open(dstname, "wb") as outfile:
                        while cur_pos < end_pos:
                            # Find the first data position.
                            # This will raise ENXIO if there isn't one
                            try:
                                start_pos = os.lseek(infile.fileno(), cur_pos, SeekConstants.SEEK_DATA)
                            except OSError as e:
                                if e.errno == errno.ENXIO:
                                    # Go to the end of the file, essentially
                                    start_pos = end_pos
                                elif e.errno == errno.ENOTTY:
                                    # The filesystem doesn't support holes
                                    start_pos = cur_pos
                                else:
                                    raise

                            try:
                                next_pos = os.lseek(infile.fileno(), start_pos, SeekConstants.SEEK_HOLE)
                            except OSError as e:
                                if e.errno == errno.ENXIO or e.errno == errno.ENOTTY:
                                    # No more holes left, so next_pos = end of file
                                    next_pos = end_pos
                                else:
                                    raise

                            cur_pos = start_pos
                            while cur_pos < next_pos:
                                # Read 1mbyte at most
                                to_read = min(next_pos - cur_pos, 1024 * 1024)
                                os.lseek(infile.fileno(), cur_pos, SeekConstants.SEEK_SET)
                                buffer = os.read(infile.fileno(), to_read)
                                os.lseek(outfile.fileno(), cur_pos, SeekConstants.SEEK_SET)
                                os.write(outfile.fileno(), buffer)
                                cur_pos += to_read
                
                        os.ftruncate(outfile.fileno(), end_pos)
                            
                # Now for any eas!
                if xattr is True:
                    # Copy all the EAs!
                    ea_namespaces = bsd.extattr.get_namespace()
                elif type(xattr) in (str, list):
                    ea_namespaces = bsd.extattr.get_namespace(xattr)
                else:
                    ea_namespaces = None

                if ea_namespaces:
                    for ns_name, ns_id in ea_namespaces.items():
                        # First, we get all the EAs
                        try:
                            ea_names = bsd.extattr.list(srcname, namespace=ns_id, follow=symlinks)
                        except OSError as e:
                            if xattr_error_callback:
                                if xattr_error_callback(srcname, ns_name, None, e) is False:
                                    raise e
                                else:
                                    continue
                            else:
                                raise e
                        # Now we try copying them
                        for ea in ea_names:
                            if xattr_filter:
                                if xattr_filter(srcname, ns_name, ea) is False:
                                    continue
                            try:
                                ea_data = bsd.extattr.get(srcname, ns_id, ea, follow=symlinks)
                            except OSError as e:
                                if xattr_error_callback:
                                    if xattr_error_callback(srcname, ns_name, None, e) is False:
                                        raise e
                                    else:
                                        continue
                                else:
                                    raise e
                            try:
                                bsd.extattr.set(dstname, namespace=ns_id, attr={ea: ea_data}, follow=symlinks)
                            except OSError as e:
                                if xattr_error_callback:
                                    if xattr_error_callback(srcname, ns_name, None, e) is False:
                                        raise e
                                    else:
                                        continue
                                else:
                                    raise e

            try:
                if symlinks or not os.path.islink(srcname):
                    shutil.copystat(srcname, dstname)
            except OSError as why:
                if error_cb:
                    call_error_cb(srcname, dstname, why)
                else:
                    errors.extend((srcname, dstname, why))

        # XXX What about devices, sockets etc.?
        except (IOError, os.error) as why:
            if error_cb:
                call_error_cb(src, dstname, why)
            else:
                errors.append((srcname, dstname, why))

        # catch the Error from the recursive copytree so that we can
        # continue with other files
        except shutil.Error as err:
            if error_cb:
                call_error_cb(src, dstname, err.args[0])
            else:
                errors.extend(err.args[0])

    if errors and not error_cb:
        raise shutil.Error(errors)
