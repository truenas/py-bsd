# cython: language_level=3, c_string_type=unicode, c_string_encoding=default

from . cimport ses

from libc.stdint cimport uint16_t
from posix.ioctl cimport ioctl
from posix.fcntl cimport open, O_RDWR
from posix.unistd cimport close
from posix.strings cimport bzero
from libc.stdlib cimport calloc, free
from libc.stdint cimport UINT16_MAX
from libc.string cimport strdup


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
        cdef ses.encioc_element_t * objp
        cdef ses.encioc_elm_status_t ob
        cdef ses.encioc_elm_desc_t objd
        cdef ses.encioc_elm_devnames_t objdn
        cdef unsigned char _enc_name[32]
        cdef unsigned char _enc_id[32]
        cdef int res = -1
        cdef int num_elms = 0
        cdef int elm_name_size = 128
        cdef ses.u_char estat
        cdef ses.elm_info_t * elm_info

        enc_name.bufsiz = sizeof(_enc_name)
        enc_name.buf = &_enc_name[0]
        enc_id.bufsiz = sizeof(_enc_id)
        enc_id.buf = &_enc_id[0]
        with nogil:
            # enclosure name
            res = ioctl(self.enc_fd, ses.ENCIOC_GETENCNAME, <ses.caddr_t>&enc_name)
            if res != 0:
                raise RuntimeError('ioctl failed to get enclosure name')

            # enclosure id
            res = ioctl(self.enc_fd, ses.ENCIOC_GETENCID, <ses.caddr_t>&enc_id)
            if res != 0:
                raise RuntimeError('ioctl failed to get enclosure id')

            # number of enclosure elements
            res = ioctl(self.enc_fd, ses.ENCIOC_GETNELM, <ses.caddr_t>&num_elms)
            if res < 0:
                raise RuntimeError('ioctl failed to get number of elements')

            # enclosure status
            res = ioctl(self.enc_fd, ses.ENCIOC_GETENCSTAT, <ses.caddr_t>&estat)
            if res != 0:
                raise RuntimeError('ioctl failed to get enclosure status')

            objp = <ses.encioc_element_t*>calloc(num_elms, sizeof(ses.encioc_element_t))
            if not objp:
                raise MemoryError('calloc objp failed')

            res = ioctl(self.enc_fd, ses.ENCIOC_GETELMMAP, <ses.caddr_t>objp)
            if res < 0:
                raise RuntimeError('ioctl failed to get enclosure element map')

            elm_info = <ses.elm_info_t*>calloc(num_elms, sizeof(ses.elm_info_t))
            if not elm_info:
                raise MemoryError('calloc elm_info failed')

            # get each elements status and store in an array
            for i in range(num_elms):
                ob.elm_idx = objp[i].elm_idx
                res = ioctl(self.enc_fd, ses.ENCIOC_GETELMSTAT, <ses.caddr_t>&ob)
                if res < 0:
                    raise RuntimeError('ioctl failed to get element status')

                # copy out element id
                elm_info[i].idx = ob.elm_idx

                # copy out element type
                elm_info[i].elm_type = objp[i].elm_type

                # copy out element status (always size 4)
                elm_info[i].cstat[0] = ob.cstat[0]
                elm_info[i].cstat[1] = ob.cstat[1]
                elm_info[i].cstat[2] = ob.cstat[2]
                elm_info[i].cstat[3] = ob.cstat[3]

                bzero(&objd, sizeof(objd))
                objd.elm_idx = objp[i].elm_idx
                objd.elm_desc_len = UINT16_MAX
                objd.elm_desc_str = <char*>calloc(UINT16_MAX, sizeof(char))
                if not objd.elm_desc_str:
                    raise MemoryError('calloc objd.elm_desc_str failed')

                elm_info[i].elm_desc_str = <char*>calloc(UINT16_MAX, sizeof(char))
                if not elm_info[i].elm_desc_str:
                    raise MemoryError('calloc elm_info.elm_desc_str failed')

                res = ioctl(self.enc_fd, ses.ENCIOC_GETELMDESC, <ses.caddr_t>&objd)
                if res < 0:
                    raise RuntimeError('ioctl failed to get element description')

                bzero(&objdn, sizeof(objdn))
                objdn.elm_idx = objp[i].elm_idx
                objdn.elm_names_size = elm_name_size
                objdn.elm_devnames = <char*>calloc(elm_name_size, sizeof(char))
                if not objdn.elm_devnames:
                    raise MemoryError('calloc elm_devnames failed')

                elm_info[i].elm_devnames = <char*>calloc(elm_name_size, sizeof(char))
                if not elm_info[i].elm_devnames:
                    raise MemoryError('calloc elm_info.elm_devnames failed')

                # apparently this isn't critical and can return -1
                # so we ignore the returned value
                ioctl(self.enc_fd, ses.ENCIOC_GETELMDEVNAMES, <ses.caddr_t>&objdn)
                if objd.elm_desc_len:
                    elm_info[i].elm_desc_str = objd.elm_desc_str
                if objdn.elm_names_len:
                    elm_info[i].elm_devnames = objdn.elm_devnames

        enc_info = {
            'name': '',
            'id': '',
            'status': set(),
            'elements': {},
        }

        # pull out enclosure name and id
        enc_info['name'] = enc_name.buf.strip()
        enc_info['id'] = enc_id.buf.strip()

        # pull out enclosure status
        if estat == 0:
            enc_info['status'].add('OK')
        else:
            if (estat & ses.SES_ENCSTAT_INFO):
                enc_info['status'].add('INFO')
            if (estat & ses.SES_ENCSTAT_NONCRITICAL):
                enc_info['status'].add('NONCRITICAL')
            if (estat & ses.SES_ENCSTAT_CRITICAL):
                enc_info['status'].add('CRITICAL')
            if (estat & ses.SES_ENCSTAT_UNRECOV):
                enc_info['status'].add('UNRECOV')

        # pull out enclosure element info
        for i in range(num_elms):
            # element index
            idx = elm_info[i].idx

            # element type
            _type = elm_info[i].elm_type

            # element status (always size of 4)
            status = [
                elm_info[i].cstat[0],
                elm_info[i].cstat[1],
                elm_info[i].cstat[2],
                elm_info[i].cstat[3],
            ]

            desc = elm_info[i].elm_desc_str
            dev = elm_info[i].elm_devnames

            # free it while we're here
            free(elm_info[i].elm_desc_str)
            free(elm_info[i].elm_devnames)

            enc_info['elements'].update({
                idx: {
                'type': _type,
                'status': status,
                'descriptor': desc.strip(),
                'dev': dev,
                }
            })

        with nogil:
            # clean it all up
            free(objdn.elm_devnames)
            free(objp)
            free(elm_info)

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
        try:
            return self.setobj(<long>element, cstat)
        except RuntimeError:
            raise

    def clear(self, element):
        cdef unsigned char[4] cstat = [128, 0, 0, 0]
        try:
            return self.setobj(<long>element, cstat)
        except RuntimeError:
            raise

    def fault(self, element):
        cdef unsigned char[4] cstat = [128, 0, 0, 32]
        try:
            return self.setobj(<long>element, cstat)
        except RuntimeError:
            raise

    def status(self):
      return self.__status__()
