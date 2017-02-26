#-
# Copyright (c) 2014 iXsystems, Inc.
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

import Cython.Compiler.Options
Cython.Compiler.Options.annotate = True
from distutils.core import setup
from Cython.Build import cythonize
from Cython.Distutils.extension import Extension
from Cython.Distutils import build_ext
import six


extensions = [
    Extension("bsd._bsd", ["bsd/_bsd.pyx"], extra_compile_args=["-g", "-O0"], extra_link_args=["-lutil", "-lprocstat"]),
    Extension("bsd.sysctl", ["bsd/sysctl.pyx"], extra_compile_args=["-g", "-O0"]),
    Extension("bsd.dialog", ["bsd/dialog.pyx"], extra_compile_args=["-g", "-O0"], extra_link_args=["-ldialog"]),
    Extension("bsd.kld", ["bsd/kld.pyx"], extra_compile_args=["-g", "-O0"]),
    Extension("bsd.acl", ["bsd/acl.pyx"], extra_compile_args=["-g", "-O0"]),
    Extension("bsd.extattr", ["bsd/extattr.pyx"], extra_compile_args=["-g", "-O0"], cython_compile_time_env={'PY2': six.PY2}),
    Extension("bsd.devinfo", ["bsd/devinfo.pyx"], extra_compile_args=["-g", "-O0"], extra_link_args=["-ldevinfo"]),
    Extension("bsd.bpf", ["bsd/bpf.pyx"], extra_compile_args=["-g", "-O0"]),
    Extension("bsd.nis", ["bsd/nis.pyx", "bsd/yp_client.c"], extra_compile_args=["-g", "-O0"], extra_link_args=["-g", "-O0", "-lypclnt"]),
]


setup(
    name='bsd',
    version='1.0',
    packages=['bsd'],
    package_dir={'bsd' : 'bsd'},
    package_data={'bsd': ['*.html', '*.c']},
    cmdclass={'build_ext': build_ext},
    ext_modules=extensions,
)
