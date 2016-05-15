#
# Copyright 2016 iXsystems, Inc.
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
import enum
import struct
import fcntl
from posix.ioctl cimport ioctl
from libc.errno cimport errno
from libc.string cimport strncpy
cimport defs


class InstructionClass(enum.IntEnum):
    LD = defs.BPF_LD
    LDX = defs.BPF_LDX
    ST = defs.BPF_ST
    STX = defs.BPF_STX
    ALU = defs.BPF_ALU
    JMP = defs.BPF_JMP
    RET = defs.BPF_RET
    MISC = defs.BPF_MISC


class OperandSize(enum.IntEnum):
    W = defs.BPF_W
    H = defs.BPF_H
    B = defs.BPF_B


class OperandMode(enum.IntEnum):
    IMM = defs.BPF_IMM
    ABS = defs.BPF_ABS
    IND = defs.BPF_IND
    MEM = defs.BPF_MEM
    LEN = defs.BPF_LEN
    MSH = defs.BPF_MSH


class Opcode(enum.IntEnum):
    ADD = defs.BPF_ADD
    SUB = defs.BPF_SUB
    MUL = defs.BPF_MUL
    DIV = defs.BPF_DIV
    OR = defs.BPF_OR
    AND = defs.BPF_AND
    LSH = defs.BPF_LSH
    RSH = defs.BPF_RSH
    NEG = defs.BPF_NEG
    JA = defs.BPF_JA
    JEQ = defs.BPF_JEQ
    JGT = defs.BPF_JGT
    JGE = defs.BPF_JGE
    JSET = defs.BPF_JSET
    TAX = defs.BPF_TAX
    TXA = defs.BPF_TXA


class Source(enum.IntEnum):
    K = defs.BPF_K
    X = defs.BPF_X
    A = defs.BPF_A


class Statement(object):
    def __init__(self, code, k):
        self.code = code
        self.k = k

    def __bytes__(self):
        return struct.pack('HBBI', self.code, self.k, 0, 0)


class Jump(object):
    def __init__(self, code, k, jt, jf):
        self.code = code
        self.k = k
        self.jt = jt
        self.jf = jf

    def __bytes__(self):
        return struct.pack('HBBI', self.code, self.jt, self.jf, self.k)


cdef class BPF(object):
    cdef object fd

    def __init__(self):
        self.fd = None

    def __enter__(self):
        self.open()

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    property buffer_size:
        def __get__(self):
            cdef int value

            if ioctl(self.fd.fileno(), defs.BIOCGBLEN, &value) != 0:
                raise OSError(errno, os.strerror(errno))

            return value

        def __set__(self, buffer_size):
            cdef int value = <int>value

            if ioctl(self.fd.fileno(), defs.BIOCSBLEN, &value) != 0:
                raise OSError(errno, os.strerror(errno))

    property interface:
        def __get__(self):
            cdef defs.ifreq ifr

            if ioctl(self.fd.fileno(), defs.BIOCGETIF, <void *>&ifr) != 0:
                raise OSError(errno, os.strerror(errno))

            return ifr.ifr_name

        def __set__(self, value):
            cdef defs.ifreq ifr

            strncpy(ifr.ifr_name, value, defs.IFNAMSIZ)
            if ioctl(self.fd.fileno(), defs.BIOCSETIF, <void *>&ifr) != 0:
                raise OSError(errno, os.strerror(errno))

    property immediate:
        def __set__(self, immediate):
            cdef int value = <int>immediate

            if ioctl(self.fd.fileno(), defs.BIOCIMMEDIATE, &value) != 0:
                raise OSError(errno, os.strerror(errno))

    def open(self):
        self.fd = open('/dev/bpf', 'r+b', buffering=0)

    def close(self):
        self.fd.close()

    def apply_filter(self):
        pass

    def read(self):
        return os.read(self.fd.fileno(), self.buffer_size)

    def write(self, data):
        os.write(self.fd.fileno(), data)
