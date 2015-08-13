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


import sysctl
from xml.etree import ElementTree as etree


_classes = {}
_geoms = {}


class GEOMBase(object):
    def __init__(self, xml):
        self.xml = xml

    @property
    def id(self):
        return self.xml.attrib['id']


class GEOMClass(GEOMBase):
    @property
    def name(self):
        return self.xml.find('name').text

    @property
    def geoms(self):
        for i in self.xml.findall('geom'):
            yield GEOMObject(i)

    def geom_by_name(self, name):
        ret = list(filter(lambda g: g.name == name, self.geoms))
        return ret[0] if len(ret) > 0 else None

    def __str__(self):
        return "<geom.GEOMClass name '{0}' id '{1}'>".format(self.name, self.id)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'name': self.name,
            'geoms': [x.__getstate__() for x in self.geoms]
        }


class GEOMObject(GEOMBase):
    @property
    def name(self):
        return self.xml.find('name').text

    @property
    def rank(self):
        return int(self.xml.find('rank').text)

    @property
    def clazz(self):
        return class_by_id(self.xml.find('class').attrib['ref'])

    @property
    def providers(self):
        for i in self.xml.findall('provider'):
            yield GEOMProvider(i)

    @property
    def consumers(self):
        for i in self.xml.findall('consumer'):
            yield GEOMConsumer(i)

    @property
    def config(self):
        config = self.xml.find('config')
        if config is not None:
            return {i.tag: i.text for i in config}

        return None

    def __str__(self):
        return "<geom.GEOMObject name '{0}' id '{1}'>".format(self.name, self.id)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'id': self.id,
            'name': self.name,
            'class_id': self.clazz.id,
            'config': self.config,
            'providers': [x.__getstate__() for x in self.providers],
            'consumers': [x.__getstate__() for x in self.consumers]
        }


class GEOMProvider(GEOMBase):
    @property
    def geom(self):
        return geom_by_id(self.xml.find('geom').attrib['ref'])

    @property
    def mode(self):
        return self.xml.find('mode').text

    @property
    def name(self):
        return self.xml.find('name').text

    @property
    def mediasize(self):
        return int(self.xml.find('mediasize').text)

    @property
    def sectorsize(self):
        return int(self.xml.find('sectorsize').text)

    @property
    def stripesize(self):
        return int(self.xml.find('stripesize').text)

    @property
    def stripeoffset(self):
        return int(self.xml.find('stripeoffset').text)

    @property
    def config(self):
        config = self.xml.find('config')
        if config is not None:
            return {i.tag: i.text for i in config}

        return None

    def __str__(self):
        return "<geom.GEOMProvider name '{0}' id '{1}'>".format(self.name, self.id)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'name': self.name,
            'mode': self.mode,
            'geom_id': self.geom.id,
            'mediasize': self.mediasize,
            'sectorsize': self.sectorsize,
            'stripesize': self.stripesize,
            'stripeoffset': self.stripeoffset,
            'config': self.config
        }


class GEOMConsumer(GEOMBase):
    @property
    def geom(self):
        return geom_by_id(self.xml.find('geom').attrib['ref'])

    @property
    def mode(self):
        return self.xml.find('mode').text

    def __str__(self):
        return "<geom.GEOMConsumer id '{0}'>".format(self.id)

    def __repr__(self):
        return str(self)

    def __getstate__(self):
        return {
            'geom_id': self.geom.id
        }


def scan():
    confxml = sysctl.sysctlbyname('kern.geom.confxml').strip('\x00')
    tree = etree.fromstring(confxml)

    for i in tree.findall('class'):
        cls = GEOMClass(i)
        _classes[cls.id] = cls
        for g in cls.geoms:
            _geoms[g.id] = g


def classes():
    return _classes.values()


def geoms():
    return _geoms.values()


def class_by_id(ident):
    return _classes[ident]


def class_by_name(name):
    ret = list(filter(lambda g: g.name == name, _classes.values()))
    return ret[0] if len(ret) > 0 else None


def geom_by_id(ident):
    return _geoms[ident]


# Do initial scan at module load time
scan()
