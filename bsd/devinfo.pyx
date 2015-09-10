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
cimport defs


class ResourceManagers(dict):

    def append(self, rman):
        self[rman.desc] = rman

RESOURCE_MANAGERS = ResourceManagers()


cdef class ResourceManager(dict):
    cdef readonly object desc
    cdef readonly object start
    cdef readonly object size

    def __init__(self):
        raise RuntimeError('ResourceManager cannot be instantiated by the user')

    def __repr__(self):
        return '<ResourceManager: {0}>'.format(self.desc)

    def append(self, dev):
        entry = self.get(dev.name)
        if entry is None:
            self[dev.name] = [dev]
        elif isinstance(entry, list):
            entry.append(dev)
        else:
            self[dev.name] = [entry, dev]


cdef class Device(object):
    cdef readonly object name
    cdef readonly object desc
    cdef readonly object drivername
    cdef readonly object location
    cdef readonly object start
    cdef readonly object size

    def __init__(self):
        raise RuntimeError('Device cannot be instantiated by the user')

    def __repr__(self):
        return '<Device: {0}>'.format(self.name)


cdef class DevInfo(object):

    def __cinit__(self):
        defs.devinfo_init()

    def __dealloc__(self):
        defs.devinfo_free()

    property resource_managers:
        def __get__(self):
            global RESOURCE_MANAGERS
            RESOURCE_MANAGERS.clear()
            defs.devinfo_foreach_rman(&resource_manager, <void *>None)
            return RESOURCE_MANAGERS


cdef int rman_resource(defs.devinfo_res *res, void *unused):
    cdef defs.devinfo_dev* dev
    cdef defs.devinfo_rman* rman
    cdef Device device
    global RESOURCE_MANAGERS

    rman = defs.devinfo_handle_to_rman(res.dr_rman)
    if rman == NULL:
        return 0

    dev = defs.devinfo_handle_to_device(res.dr_device)
    if dev == NULL or len(dev.dd_name) == 0:
        return 0

    device = Device.__new__(Device)
    device.name = dev.dd_name
    device.desc = dev.dd_desc
    device.drivername = dev.dd_drivername
    device.location = dev.dd_location
    device.start = res.dr_start
    device.size = res.dr_size
    RESOURCE_MANAGERS[rman.dm_desc].append(device)


cdef int resource_manager(defs.devinfo_rman *rman, void *unused):
    global RESOURCE_MANAGERS
    cdef ResourceManager resourcemanager
    resourcemanager = ResourceManager.__new__(ResourceManager)
    resourcemanager.desc = rman.dm_desc
    resourcemanager.start = rman.dm_start
    resourcemanager.size = rman.dm_size
    RESOURCE_MANAGERS.append(resourcemanager)
    defs.devinfo_foreach_rman_resource(rman, &rman_resource, <void *>None);


