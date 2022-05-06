# cython: language_level=3, c_string_type=unicode, c_string_encoding=default

from cython import size_t
from libc.stdint cimport uint8_t, uint16_t


cdef extern from "sys/types.h":
    ctypedef long caddr_t
    ctypedef unsigned char u_char


cdef extern from "cam/scsi/scsi_ses.h":
    cdef enum:
        SES_ENCSTAT_INFO
        SES_ENCSTAT_NONCRITICAL
        SES_ENCSTAT_CRITICAL
        SES_ENCSTAT_UNRECOV


cdef extern from "cam/scsi/scsi_enc.h":
    cdef enum:
        ENCIOC_GETNELM
        ENCIOC_GETELMMAP
        ENCIOC_GETENCSTAT
        ENCIOC_SETENCSTAT
        ENCIOC_GETELMSTAT
        ENCIOC_SETELMSTAT
        ENCIOC_GETTEXT
        ENCIOC_INIT
        ENCIOC_GETELMDESC
        ENCIOC_GETELMDEVNAMES
        ENCIOC_GETSTRING
        ENCIOC_SETSTRING
        ENCIOC_GETENCNAME
        ENCIOC_GETENCID

    ctypedef enum elm_type_t:
        ELMTYP_UNSPECIFIED =    0x00
        ELMTYP_DEVICE =         0x01
        ELMTYP_POWER =          0x02
        ELMTYP_FAN =            0x03
        ELMTYP_THERM =          0x04
        ELMTYP_DOORLOCK =       0x05
        ELMTYP_ALARM =          0x06
        ELMTYP_ESCC =           0x07
        ELMTYP_SCC =            0x08
        ELMTYP_NVRAM =          0x09
        ELMTYP_INV_OP_REASON =  0x0a
        ELMTYP_UPS =            0x0b
        ELMTYP_DISPLAY =        0x0c
        ELMTYP_KEYPAD =         0x0d
        ELMTYP_ENCLOSURE =      0x0e
        ELMTYP_SCSIXFR =        0x0f
        ELMTYP_LANGUAGE =       0x10
        ELMTYP_COMPORT =        0x11
        ELMTYP_VOM =            0x12
        ELMTYP_AMMETER =        0x13
        ELMTYP_SCSI_TGT =       0x14
        ELMTYP_SCSI_INI =       0x15
        ELMTYP_SUBENC =         0x16
        ELMTYP_ARRAY_DEV =      0x17
        ELMTYP_SAS_EXP =        0x18
        ELMTYP_SAS_CONN =       0x19
        ELMTYP_LAST =           ELMTYP_SAS_CONN

    ctypedef struct encioc_string_t:
        size_t bufsiz
        uint8_t * buf

    ctypedef struct encioc_element_t:
        unsigned int elm_idx
        unsigned int elm_subenc_id
        elm_type_t elm_type

    ctypedef struct encioc_elm_status_t:
        unsigned int elm_idx
        unsigned char cstat[4]

    ctypedef struct encioc_elm_desc_t:
        unsigned int elm_idx
        uint16_t elm_desc_len
        char * elm_desc_str

    ctypedef struct encioc_elm_devnames_t:
        unsigned int elm_idx
        size_t elm_names_size
        size_t elm_names_len
        char * elm_devnames
