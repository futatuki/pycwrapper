#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import os.path
import sys
import getopt
import io
import codecs
import subprocess
import re
import datetime

# temporary, read setting as a module
import kw_conf

#
# absorb Python 2 incompatibilities
#

try:
    PathLike = os.PathLike
except AttributeError:
    class PathLike(object):
        pass

try:
    UTC = datetime.timezone.utc
except AttributeError:
    class _UTC(datetime.tzinfo):
        def utcoffset(self, dt):
            return datetime.dimedelta(0)
        def dst(self, dt):
            return None
        def tzname(self, dt):
            return 'UTC'
        def fromutc(self, dt):
            return dt
    UTC = _UTC()

try:
    fixedtimezone = datetime.timezone
except AttributeError:
    class fixedtimezone(datetime.tzinfo):
        def __init__(self, offset, name=None):
            if isinstance(offset, int):
                self._offset = datetime.timedelta(minutes=offset)
            elif isinstance(offset, datetime.timedelta):
                self._offset = offset
            self._name=name
        def utcoffset(self, dt):
            return self._offset
        def dst(self, dt):
            return None
        def tzname(self, dt):
            if self._name:
                return self._name
            if self._offset == datetime.timedelta(0):
                return 'UTC'
            elif self._offset > datetime.timedelta(0):
                return 'UTC+%02d%02d'% (self._offset.seconds // 3600,
                                        self._offset.seconds % 3600)
            else:
                return 'UTC-%02d%02d'% ((- self._offset.seconds) // 3600,
                                        (- self._offset.seconds) % 3600)

def parse_iso8601(dtstr):
    try:
        dt = datetime.datetime.strptime(dtstr, '%Y-%m-%d %H:%M:%S %z')
    except ValueError:
        dt = datetime.datetime.strptime(dtstr[0:19], '%Y-%m-%d %H:%M:%S')
        if dtstr[20] == '-':
            td = - datetime.timedelta(hours=int(dtstr[21:23]),
                                      minutes=int(dtstr[23:25]))
        else:
            assert(dtstr[20] == '+')
            td = datetime.timedelta(hours=int(dtstr[21:23]),
                                    minutes=int(dtstr[23:25]))
        dt = dt.replace(tzinfo=fixedtimezone(td))
    return dt

_default_encoding = sys.getdefaultencoding()

def setdefaultencoding(enc):
    codecs.lookup(enc)
    _default_encoding = enc
    return

def _norm(s, encoding=_default_encoding, errors='strict'):
    return (s.decode(encoding, errors)
                if not isinstance(s, str) and isinstance(s, bytes) else s)

#

class NoLog(Exception): pass
class FormatError(Exception): pass


def get_git_prefix():
    return _norm(subprocess.check_output(
                                [b'git', b'rev-parse',
                                 b'--show-prefix'])[:-1])
def get_git_topdir():
    return _norm(subprocess.check_output(
                                [b'git', b'rev-parse',
                                 b'--show-toplevel'])[:-1])

def get_git_log_attrs(path, isfilter=True):
    arg = [b'git', b'log', b'-1',
           b'--format=%H%x00%an%x00%ae%x00%ai%x00%cn%x00%ce%x00%ci%x00%s']
    if isinstance(path, bytes):
        arg  += [b'--', path]
    elif isinstance(path, str):
        arg  += [b'--', path.encode()]
    elif isinstance(paths, PathLike):
        p = path.__fspath__()
        if isinstance(p, bytes):
            arg += [b'--', p]
        elif isinstance(p, str):
            arg += [b'--', p.encode()]
        else:
            # foolproof
            raise AttributeError('unknown PathLike object {0}'.format(repr(p)))
    op = subprocess.check_output(arg)
    if not op:
        raise NoLog
    gldic = dict(zip(['H', 'an', 'ae', 'ai', 'cn', 'ce', 'ci', 's'],
                      map(_norm, re.split(b'\0', op[:-1]))))
    gldic['ad'] = parse_iso8601(gldic['ai'])
    gldic['cd'] = parse_iso8601(gldic['ci'])
    if isfilter:
        gldic['gt'] = os.getcwd()
        gldic['gp'] = ''
    else:
        gldic['gt'] = get_git_topdir()
        gldic['gp'] = get_git_prefix()
    return gldic


_f = { 'a' : (lambda pt, gd: '<' + gd['ae'] + '>'),
       'b' : (lambda pt, gd: os.path.basename(pt)),
       'd' : (lambda pt, gd:
                gd['ad'].astimezone(UTC).strftime('%Y-%m-%d %H:%M:%SZ')),
       'D' : (lambda pt, gd:
                gd['ad'].strftime('%Y-%m-%d %H:%M:%S %z (%a, %d %b %Y)')),
       'P' : (lambda pt, gd: os.path.join(gd['gp'], pt)),
       'r' : (lambda pt, gd: gd['H'][0:7]),
       'R' : (lambda pt, gd: gd['gt']),
       'u' : (lambda pt, gd: os.path.join(gd['gt'], gd['gp'], pt)),
       '_' : (lambda pt, gd: ' '),
       '%' : (lambda pt, gd: '%'),
       'H' : (lambda pt, gd:
                ' '.join(map((lambda p: _f[p](pt, gd)),
                             ['P', 'r', 'd', 'a']))),
       'I' : (lambda pt, gd:
                ' '.join(map((lambda p: _f[p](pt, gd)),
                             ['b', 'r', 'd', 'a'])))}

def compose_repl_str(path, gd, format):
    rep = ''
    sp = False
    for c in format:
        if sp:
            rep += _f[c](path, gd)
            sp = False
        elif c != '%':
            rep += c
        else:
            sp = True
    if sp:
        raise FormatError()
    return rep

def substkw(ist, ost, kwdict):
    for line in ist:
        elms = line.split('$')
        if len(elms) < 3:
            ost.write(line)
            continue
        oelms = elms[0:1]
        pelm = None
        pkw = None
        pmatch = False
        for elm in elms[1:]:
            if pmatch:
                oelms.append(pkw)
                oelms.append(elm)
                pmatch = False
                continue
            for kw in kwdict.keys():
                if elm.startswith(kw):
                    klen = len(kw)
                    if (    elm == kw
                         or elm == kw + ':'
                         or (elm[klen:klen+2] == ': ' and elm[-1] == ' ')):
                        pelm = elm
                        pkw = kw + ': ' + kwdict[kw] + ' '
                        pmatch = True
                        break
                    elif elm[klen:klen+3] == ':: ' and elm[-1] in ' #':
                        plen = len(elm) - klen - 3
                        if plen >= 0:
                            pelm = elm
                            slen = len(kwdict[kw])
                            if plen > slen:
                                pkw = (kw + ':: ' + kwdict[kw]
                                          + ' ' * (plen - slen))
                            else:
                                pkw = kw + ':: ' + kwdict[kw][0:plen-1] + '#'
                            pmatch = True
                            break
            if not pmatch:
                oelms.append(elm)
        # if last element is matched, it is not added in oelms, and
        # it should not to be unexpanded
        if pmatch:
            oelms.append(pelm)
        ost.write('$'.join(oelms))
    return

def unsubstkw(ist, ost, kwdict):
    for line in ist:
        elms = line.split('$')
        if len(elms) < 3:
            ost.write(line)
            continue
        oelms = elms[0:1]
        pelm = None
        pkw = None
        pmatch = False
        for elm in elms[1:]:
            if pmatch:
                oelms.append(pkw)
                oelms.append(elm)
                pmatch = False
                continue
            for kw in kwdict.keys():
                if elm.startswith(kw):
                    klen = len(kw)
                    if (    elm == kw
                         or elm == kw + ':'
                         or (elm[klen:klen+2] == ': ' and elm[-1] == ' ')):
                        pelm = elm
                        pkw = kw
                        pmatch = True
                        break
                    elif elm[klen:klen+3] == ':: ' and elm[-1] in ' #':
                        plen = len(elm) - klen - 3
                        if plen >= 0:
                            pelm = elm
                            pkw = kw + ':: ' + ' ' * plen
                            pmatch = True
                            break
            if not pmatch:
                oelms.append(elm)
        # if last element is matched, it is not added in oelms, and
        # it should not to be unexpanded
        if pmatch:
            oelms.append(pelm)
        ost.write('$'.join(oelms))
    return

_default_kw = { 'Date'               : '%D',
                'LastChangeDate'     : '%D',
                'Revision'           : '%r',
                'LastChangeRevision' : '%r',
                'Rev'                : '%r',
                'Author'             : '%a',
                'LastChangedBy'      : '%a',
                'HeadURL'            : '%u',
                'URL'                : '%u',
                'Id'                 : '%I',
                'Header'             : '%H'}

def read_conf(path):
    try:
        return kw_conf.custom_kw[path]
    except KeyError:
        return _default_kw

def expand_kwdic(path, kwdic):
    gldic = get_git_log_attrs(path)
    return dict([(kw, compose_repl_str(path, gldic, kwdic[kw]))
                    for kw in kwdic.keys()])

#
# main() ... entry point
#
def main():
    def usage():
        sys.stderr.write(
"""usage: {0} [[-e|encoding <encoding>] -c|--clean|-s|--smudge] path
""".format(sys.argv[0]))
        return
    # end of usage()

    # main function body
    try:
        opts, args = getopt.getopt(
                sys.argv[1:], "ce:hs", ['clean', 'encoding', 'smudge', 'help'])
    except getopt.GetoptErrror as err:
        sys.stderr.write(str(err))
        usage()
        sys.exit(2)

    smudge = True
    enc = None
    hf = False
    for (o, a) in opts:
        if o in ('-c', '--clean'):
            smudge = False
        elif o in ('-e', '--encoding'):
            enc = a
        elif o in ('-h', '--help'):
            hf = True
        elif o in ('-s', '--smudge'):
            smudge = True
        else:
            assert False, "unhandled option {0}".format(o)

    if hf:
        usage()
        sys.exit(0)

    if len(args) != 1:
        sys.stderr.write('error:just one file path is needed')
        usage()
        sys.exit(1)

    if enc is not None:
        setdefaultencoding(enc)

    if isinstance(sys.stdin, io.TextIOWrapper):
        try:
            sys.stdin.reconfigure(
                    encoding=_default_encoding, errors='surrogateescape')
            sys.stdout.reconfigure(
                    encoding=_default_encoding, errors='surrogateescape')
            stdin  = sys.stdin
            stdout = sys.stdout
        except AttributeError:
            stdin  = codecs.getreader(_default_encoding)(sys.stdin.buffer,
                                                         'surrogateescape')
            stdout = codecs.getwriter(_default_encoding)(sys.stdout.buffer,
                                                         'surrogateescape')
    else:
        stdin  = sys.stdin
        stdout = sys.stdout

    if smudge:
        substkw(stdin, stdout, expand_kwdic(args[0], read_conf(args[0])))
    else:
        unsubstkw(stdin, stdout, read_conf(args[0]))

# end of main()

if __name__ == "__main__":
    main()
