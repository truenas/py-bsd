from array import array
from struct import unpack
from fcntl import ioctl

from . cimport disk_ioctl


def get_size_with_name(disk):
    """
    Get size of disk in bytes.

    `disk` must be a string and can be `/dev/da1` or just `da1`
    """
    disk = disk.removeprefix('/dev/')
    with open(f'/dev/{disk}', 'rb') as f:
        return get_size_with_file(f)


def get_size_with_file(f):
    """
    Get size of disk in bytes.

    `disk` must be a python file object.
    """
    _buffer = array('B', range(0, 8))
    ioctl(f.fileno(), disk_ioctl.DIOCGMEDIASIZE, _buffer, 1)
    return unpack('q', _buffer)[0]


def get_ident_with_name(disk):
    """
    Get ident of disk.

    `disk` must be a string and can be `/dev/da1` or just `da1`
    """
    disk = disk.removeprefix('/dev/')
    with open(f'/dev/{disk}', 'rb') as f:
        return get_ident_with_file(f)


def get_ident_with_file(f):
    """
    Get ident of disk.

    `disk` must be a python file object.
    """
    _buffer = array('B', range(0, 256))  # max ident size
    ioctl(f.fileno(), disk_ioctl.DIOCGIDENT, _buffer, 1)
    return unpack('<256s', _buffer)[0].decode().strip('\x00')
