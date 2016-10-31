# cython: c_string_type=unicode, c_string_encoding=utf-8
from __future__ import print_function
import os
import sys
import cython
import pwd
import grp
import logging

logger = logging.getLogger(__name__)

"""
This offers a series of python bindings for NIS/YP.
The NIS() object allows you to connect with a specific
domain name and/or server; if either is None, it will attempt
to use the defaults.  Note that if server is None, then
ypbind needs to be running on localhost.
"""

from libc.stdlib cimport free
from libc.string cimport strerror, strlen
from libc.errno cimport *
cimport defs

cdef extern from "errno.h":
    extern int errno
    
cdef extern from "pwd.h":
    ctypedef int time_t
    ctypedef int uid_t
    ctypedef int gid_t
    
    cdef struct passwd:
        char	*pw_name
        char	*pw_passwd
        uid_t	pw_uid
        gid_t	pw_gid
        time_t	pw_change
        char	*pw_class
        char	*pw_gecos
        char	*pw_dir
        char	*pw_shell
        time_t	pw_expire
        int	pw_fields
        
cdef extern from "yp_client.h" nogil:
    enum:
        YP_CLIENT_SUCCESS
        YP_CLIENT_NOMATCH
        YP_CLIENT_NODOMAIN
        YP_CLIENT_YPBIND
        YP_CLIENT_RPCERROR
        YP_CLIENT_AUTHERR
        YP_CLIENT_TIMEOUT
        YP_CLIENT_NOHOST
        YP_CLIENT_ENOMEM
        YP_CLIENT_CONNERR
        YP_CLIENT_BADARG
        YP_CLIENT_ERRNO
        
    cdef extern const char *yp_client_errstr(unsigned int error)
    cdef extern void *yp_client_init(const char *domain, const char *server, int *errorp)
    cdef extern void yp_client_close(void *context)
    cdef extern int yp_client_error(void *context)
    cdef extern const char *yp_client_domain(void *context)
    cdef extern const char *yp_client_server(void *context)
    cdef extern int yp_client_match(void *context,
                                    const char *inmap, const char *inkey, size_t inkeylen,
                                    char **outval, size_t *outvallen)
    cdef extern int yp_client_first(void *context, const char *inmap,
                                    const char **outkey, size_t *outkeylen,
                                    const char **outval, size_t *outvallen)
    cdef extern int yp_client_next(void *context, const char *inmap,
                                   const char *inkey, size_t inkeylen,
                                   const char **outkey, size_t *outkeylen,
                                   const char **outval, size_t *outvallen)
    cdef extern int yp_client_update_pwent(void *context,
                                           const char *old_password,
                                           const passwd *pwent)

def _make_pwent(pw):
    return "{}:{}:{}:{}:{}:{}:{}".format(
        pw.pw_name, pw.pw_passwd, pw.pw_uid,
        pw.pw_gid, pw.pw_gecos, pw.pw_dir,
        pw.pw_shell)

def _make_gr(entry):
    fields = entry.split(':')
    return grp.struct_group((fields[0], fields[1], int(fields[2]),
                             fields[3].split(',')))

cdef _make_pw(entry):
    fields = entry.split(':')
    pw_name = fields[0]
    pw_passwd = fields[1]
    pw_uid = int(fields[2])
    pw_gid = int(fields[3])
    if len(fields) == 7:
        pw_gecos = fields[4]
        pw_dir = fields[5]
        pw_shell = fields[6]
    elif len(fields) == 10:
        # We get different fields for root vs non-root
        pw_gecos = fields[7]
        pw_dir = fields[8]
        pw_shell = fields[9]
    else:
        raise ValueError("Invald password entry string")
    retval = pwd.struct_passwd((pw_name, pw_passwd, pw_uid, pw_gid,
                                pw_gecos, pw_dir, pw_shell))
    return retval

class NISError(Exception):
    def __init__(self, code=0, exp=None):
        print("NISError(code={}, exp={})".format(code, exp), file=sys.stderr)
        if code == YP_CLIENT_ERRNO:
            raise OSError(errno, os.strerror(errno))
        else:
            self.code = code
            if exp is None:
                if code is YP_CLIENT_YPBIND:
                    exp = "Could not connect to ypbind on localhost"
                elif code is YP_CLIENT_ENOMEM:
                    exp = "Unable to allocate memory"
                elif code is YP_CLIENT_CONNERR:
                    exp = "Unable to connect to ypserv on remote host"
                elif code is YP_CLIENT_RPCERROR:
                    exp = "RPC Error"
                else:
                    exp = "Generic YP error?"
            self.explanation = exp
    def __str__(self):
        return "NISError(code={}, explanation={})".format(yp_client_errstr(self.code), self.explanation)

cdef class NIS(object):
    cdef void *ctx
    cdef const char *domain
    cdef const char *server
    def __init__(self, domain=None, server=None):
        stupid_temp_domain = domain.encode('utf-8') if domain else None
        stupid_temp_server = server.encode('utf-8') if server else None
        cdef const char *c_domain = stupid_temp_domain or <const char*>NULL
        cdef const char *c_server = stupid_temp_server or <const char *>NULL
        cdef int error
        
        with nogil:
            self.ctx = yp_client_init(c_domain, c_server, &error)
        if self.ctx == NULL:
            raise NISError(error)
        
        self.domain = c_domain
        self.server = c_server
        return

    def __del__(self):
        if self.ctx:
            with nogil:
                yp_client_close(self.ctx)
        # Do I need to call object's destructor?
        
    def _getpw(self, const char *c_mapname, const char *c_keyvalue):
        cdef char *pw_ent = NULL
        cdef size_t pw_ent_len
        cdef int rv

        with nogil:
            rv = yp_client_match(self.ctx, c_mapname, c_keyvalue, strlen(c_keyvalue), &pw_ent, &pw_ent_len)
        if rv != 0:
            print("_getpw(self, {}, {}): rv = {}, yp_client_error(self.ctx) = {}".format(
                c_mapname, c_keyvalue, rv, yp_client_error(self.ctx)), file=sys.stderr)
            raise NISError(yp_client_error(self.ctx), "Unable to find {} in map {}".format(c_keyvalue, c_mapname))
        
        retval = _make_pw(pw_ent)
        free(pw_ent)
        if retval:
            return retval
        raise OSError(ENOENT, "Cannot find key {} in map {}".format(c_keyvalue, c_mapname))
        
    def _get_entries(self, mapname, cracker):
        """
        Generic function to get multiple entries (e.g., getpwent and getgrent).
        This is slightly different from the libc routines, in that
        we simply call yp_client_first() for the proper map, and then
        yield results until yp_client_next() returns an error.
        Note that mapname is a string, converted to bytes because reasons.
        """
        cdef const char *first_key = NULL
        cdef const char *next_key = NULL
        cdef const char *out_value = NULL
        cdef size_t first_keylen, next_keylen, out_len
        stupid_temp_mapname = mapname.encode('utf-8')
        cdef const char *c_mapname = stupid_temp_mapname
        cdef int rv
        
        try:
            with nogil:
                rv = yp_client_first(self.ctx, c_mapname,
                                     &next_key, &next_keylen,
                                     &out_value, &out_len)
            while rv == 0:
                retval = cracker(out_value)
                free(<void*>out_value)
                free(<void*>first_key)
                first_key = next_key
                first_keylen = next_keylen
                next_key = NULL
                next_keylen = 0
                yield retval
                with nogil:
                    rv = yp_client_next(self.ctx, c_mapname,
                                        first_key, first_keylen,
                                        &next_key, &next_keylen,
                                        &out_value, &out_len)
                if rv == 0 and next_key == NULL:
                    # This means we've run out of keys
                    break
            if rv != 0:
                raise NISError(yp_client_error(self.ctx))
 
        finally:
            if first_key:
                free(<void*>first_key)
            if next_key:
                free(<void*>next_key)

    def getpwent(self):
        if os.geteuid() == 0:
            mapname = "master.passwd.byname"
        else:
            mapname = "passwd.byname"

        return self._get_entries(mapname, _make_pw)
            
    def getpwnam(self, name):
        if os.geteuid() == 0:
            mapname = b"master.passwd.byname"
        else:
            mapname = b"passwd.byname"
            
        return self._getpw(mapname, name.encode('utf-8'))

    def getpwuid(self, uid):
        if os.geteuid() == 0:
            mapname = b"master.passwd.byuid"
        else:
            mapname = b"passwd.byuid"
            
        return self._getpw(mapname, str(uid).encode('utf-8'))

    def _getgr(self, const char *c_mapname, const char *c_keyvalue):
        cdef char *gr_ent = NULL
        cdef size_t gr_ent_len
        cdef int rv
        
        with nogil:
            rv = yp_client_match(self.ctx, c_mapname, c_keyvalue, strlen(c_keyvalue), &gr_ent, &gr_ent_len)

        if rv != 0:
            raise NISError(yp_client_error(self.ctx), "Unable to find {} in map {}".format(c_keyvalue, c_mapname))
        
        retval = _make_gr(gr_ent)
        free(gr_ent)
        if retval:
            return retval
        raise OSError(ENOENT, "Cannot find key {} in map {}".format(c_keyvalue, c_mapname))

    def getgrnam(self, grpname):
        if grpname is None:
            raise ValueError("grpname must be defined")
        return self._getgr(b"group.byname", grpname.encode('utf-8'))

    def getgrgid(self, guid):
        return self._getgr(b"group.bygid", str(guid).encode('utf-8'))
	
    def getgrent(self):
        return self._get_entries("group.byname", _make_gr)

    def update_pwent(self, old_password, new_pwent):
        cdef passwd pwent_copy
        stupid_temp_old_password = old_password.encode('utf-8')
        cdef const char *c_oldpassword = stupid_temp_old_password
        pwent_copy.pw_name = new_pwent.pw_name
        pwent_copy.pw_passwd = new_pwent.pw_passwd
        pwent_copy.pw_uid = new_pwent.pw_uid
        pwent_copy.pw_gid = new_pwent.pw_gid
        pwent_copy.pw_gecos = new_pwent.pw_gecos
        pwent_copy.pw_dir = new_pwent.pw_dir
        pwent_copy.pw_shell = new_pwent.pw_shell
        pwent_copy.pw_fields = 1

        try:
            pwent_copy.pw_change = new_pwent.pw_change
        except:
            pwent_copy.pw_change = 0
        try:
            pwent_copy.pw_class = new_pwent.pw_class
            if pwent_copy.pw_class == NULL:
                pwent_copy.pw_class = ""
        except:
            pwent_copy.pw_class = ""
        try:
            pwent_copy.pw_expire = new_pwent.pw_expire
        except:
            pwent_copy.pw_exire = 0

        with nogil:
            rv = yp_client_update_pwent(self.ctx, c_oldpassword, &pwent_copy)
        
        return
