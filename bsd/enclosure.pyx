# cython: language_level=3, c_string_type=unicode, c_string_encoding=default

from . cimport ses

from posix.ioctl cimport ioctl
from posix.fcntl cimport open, O_RDWR
from posix.unistd cimport close
from posix.strings cimport bzero
from libc.stdlib cimport calloc, free
from libc.stdint cimport UINT16_MAX


cdef class Enclosure(object):

    cdef const char* enc  # /dev/ses device passed to us
    cdef int enc_fd  # file descriptor for enclosure device

    def __cinit__(self, enc):
        self.enc = enc
        self.enc_fd = -1
        with nogil:
            self.enc_fd = open(self.enc, O_RDWR)
            if self.enc_fd == -1:
                raise RuntimeError('Failed to open device')

    def __init__(self, enc):
        self.enc = enc

    def __dealloc__(self):
        with nogil:
            if self.enc_fd >= 0:
                close(self.enc_fd)

    def __status__(self):
        cdef ses.encioc_string_t enc_name
        cdef ses.encioc_string_t enc_id
        cdef ses.encioc_element_t * objp = NULL
        cdef ses.encioc_elm_status_t ob
        cdef ses.encioc_elm_desc_t objd
        cdef ses.encioc_elm_devnames_t objdn
        cdef unsigned char _enc_name[32]
        cdef unsigned char _enc_id[32]
        cdef int res = -1
        cdef int num_elms = 0
        cdef int elm_name_size = 128
        cdef ses.u_char estat

        enc_info = {'name': '', 'id': '', 'status': [], 'elements': {}}

        # enclosure name
        enc_name.bufsiz = sizeof(_enc_name)
        enc_name.buf = &_enc_name[0]
        res = ioctl(self.enc_fd, ses.ENCIOC_GETENCNAME, <ses.caddr_t>&enc_name)
        if res != 0:
            raise RuntimeError('ioctl failed to get enclosure name')
        else:
            enc_info['name'] = enc_name.buf.strip()

        # enclosure id
        enc_id.bufsiz = sizeof(_enc_id)
        enc_id.buf = &_enc_id[0]
        res = ioctl(self.enc_fd, ses.ENCIOC_GETENCID, <ses.caddr_t>&enc_id)
        if res != 0:
            raise RuntimeError('ioctl failed to get enclosure id')
        else:
            enc_info['id'] = enc_id.buf.strip()

        # enclosure status
        res = ioctl(self.enc_fd, ses.ENCIOC_GETENCSTAT, <ses.caddr_t>&estat)
        if res != 0:
            raise RuntimeError('ioctl failed to get enclosure status')
        else:
            if estat == 0:
                enc_info['status'].append('OK')
            else:
                if (estat & ses.SES_ENCSTAT_INFO):
                    enc_info['status'].append('INFO')
                if (estat & ses.SES_ENCSTAT_NONCRITICAL):
                    enc_info['status'].append('NONCRITICAL')
                if (estat & ses.SES_ENCSTAT_CRITICAL):
                    enc_info['status'].append('CRITICAL')
                if (estat & ses.SES_ENCSTAT_UNRECOV):
                    enc_info['status'].append('UNRECOV')

        # query all elements returned by ses device
        res = ioctl(self.enc_fd, ses.ENCIOC_GETNELM, <ses.caddr_t>&num_elms)
        if res < 0:
            raise RuntimeError('ioctl failed to get number of elements')

        objp = <ses.encioc_element_t*>calloc(num_elms, sizeof(ses.encioc_element_t))
        if not objp:
            raise MemoryError('calloc objp failed')

        res = ioctl(self.enc_fd, ses.ENCIOC_GETELMMAP, <ses.caddr_t>objp)
        if res < 0:
            raise RuntimeError('ioctl failed to get enclosure element map')

        # we've got number of elements and mapped them, now iterate through
        # them and get their information
        for i in range(num_elms):
            ob.elm_idx = objp[i].elm_idx
            res = ioctl(self.enc_fd, ses.ENCIOC_GETELMSTAT, <ses.caddr_t>&ob)
            if res < 0:
                raise RuntimeError('ioctl failed to get element status')

            element = {
                ob.elm_idx: {
                    'type': objp[i].elm_type,
                    'status': [ob.cstat[j] for j in range(4)],
                    'descriptor': '',
                    'dev': '',
                }
            }

            # element descriptor info
            bzero(&objd, sizeof(objd))
            objd.elm_idx = objp[i].elm_idx
            objd.elm_desc_len = UINT16_MAX
            objd.elm_desc_str = <char*>calloc(UINT16_MAX, sizeof(char))
            res = ioctl(self.enc_fd, ses.ENCIOC_GETELMDESC, <ses.caddr_t>&objd)
            if res < 0:
                raise RuntimeError('ioctl failed to get element description')
            else:
                element[ob.elm_idx]['descriptor'] = objd.elm_desc_str.strip()
                free(objd.elm_desc_str)

            # devices connected to element
            bzero(&objdn, sizeof(objdn))
            objdn.elm_idx = objp[i].elm_idx
            objdn.elm_names_size = elm_name_size
            objdn.elm_devnames = <char*>calloc(elm_name_size, sizeof(char))
            ioctl(self.enc_fd, ses.ENCIOC_GETELMDEVNAMES, <ses.caddr_t>&objdn)
            element[ob.elm_idx]['dev'] = objdn.elm_devnames.strip()
            free(objdn.elm_devnames)

            # update the final dict
            enc_info['elements'].update(element)

        free(objp)
        return enc_info

    cdef int setobj(self, long element, unsigned char *action) except -1:
        cdef ses.encioc_elm_status_t obj
        cdef int res = -1

        obj.elm_idx = element
        obj.cstat = action
        with nogil:
            res = ioctl(self.enc_fd, ses.ENCIOC_SETELMSTAT, <ses.caddr_t>&obj)
            if res < 0:
                raise RuntimeError('ioctl failed to set element status')

        return res

    def identify(self, element):
        cdef unsigned char[4] cstat = [128, 0, 2, 0]
        return self.setobj(<long>element, cstat)

    def clear(self, element):
        cdef unsigned char[4] cstat = [128, 0, 0, 0]
        return self.setobj(<long>element, cstat)

    def fault(self, element):
        cdef unsigned char[4] cstat = [128, 0, 0, 32]
        return self.setobj(<long>element, cstat)

    def status(self):
      return self.__status__()
