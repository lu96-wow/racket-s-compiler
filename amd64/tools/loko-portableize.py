r"""Convert Loko's printed assembler s-expressions to Racket-readable s-expressions.

Loko and Racket disagree on a few printed forms:
  #{gensym |unique|}   -> loko-gensym-N (stable by printed identity)
  #vu8(1 2 3)          -> #"\x01\x02\x03"
  #<rtd name>          -> loko-rtd-name
  #\alarm/#\esc/#\delete -> #\u...
  #\xNN                -> #\uNN
  "\xNN;"              -> "\xNN" (Loko's semicolon terminates the escape)

Run:
  python3 tools/loko-portableize.py dump.sexp [more.sexp ...]
Each input is written to <input>.p.
"""

import re, sys
gensym = re.compile(r'#\{([^|}]*)\|([^|}]*)\|\}')
vu8 = re.compile(r'#vu8\(([0-9 ]*)\)')
rtd = re.compile(r'#<rtd ([^>]*)>')
hexchar = re.compile(r'#\\x([0-9a-fA-F]+)(?![0-9A-Za-z])')
namedchar = {'alarm': '7', 'esc': '1b', 'delete': '7f'}
m = {}; n = 0
def rep(mo):
    global n
    key = mo.group(0)
    v = m.get(key)
    if v is None:
        v = 'loko-gensym-%d' % n; n += 1; m[key] = v
    return v
def rep8(mo):
    nums = mo.group(1).split()
    return '#"' + ''.join('\\x%02x' % int(x) for x in nums) + '"'
def rep_rtd(mo):
    name = re.sub(r'[^A-Za-z0-9_.+*/<>=!?-]', '_', mo.group(1))
    return 'loko-rtd-' + name
def transform_segment(s):
    s = gensym.sub(rep, s)
    s = vu8.sub(rep8, s)
    s = rtd.sub(rep_rtd, s)
    for k, v in namedchar.items():
        s = s.replace('#\\' + k, '#\\u' + v)
    s = hexchar.sub(lambda mo: '#\\u' + mo.group(1), s)
    return s
def transform_line(line):
    out = []; cur = []; in_str = False; i = 0; L = len(line)
    def flush_str():
        if cur:
            out.append(('str', ''.join(cur))); cur.clear()
    def flush_code():
        if cur:
            out.append(('code', ''.join(cur))); cur.clear()
    while i < L:
        c = line[i]
        if in_str:
            cur.append(c)
            if c == '\\' and i + 1 < L:
                cur.append(line[i+1]); i += 2; continue
            if c == '"':
                in_str = False; flush_str()
            i += 1
        else:
            if c == '"':
                flush_code(); cur.append(c); in_str = True; i += 1
            elif c == '#' and i + 1 < L and line[i+1] == '\\':
                cur.append('#\\'); i += 2
                if i < L:
                    if line[i].isalpha():
                        j = i
                        while j < L and (line[j].isalnum() or line[j] in '-'):
                            j += 1
                        cur.append(line[i:j]); i = j
                    else:
                        cur.append(line[i]); i += 1
            else:
                cur.append(c); i += 1
    if cur: out.append(('str' if in_str else 'code', ''.join(cur)))
    def fix_escape(mo):
        digits = mo.group(1)
        n = int(digits, 16)
        if len(digits) <= 2:
            return '\\x' + digits
        if len(digits) <= 4:
            return '\\u' + digits
        if n <= 0x10FFFF:
            return '\\U%08x' % n
        raise ValueError('character escape out of range: \\x%s;' % digits)

    def fix_string(seg):
        # Loko writes \xHEX; (the semicolon terminates the escape).  Racket's
        # \x consumes exactly two hex digits and keeps the semicolon, so drop
        # the terminator and choose a Racket escape that keeps the value.
        return re.sub(r'\\x([0-9a-fA-F]+);', fix_escape, seg)
    return ''.join(transform_segment(x) if k == 'code' else fix_string(x)
                   for k, x in out)
if len(sys.argv) == 1:
    sys.exit(__doc__.strip())

for src in sys.argv[1:]:
    dst = src + '.p'
    with open(src, 'r', encoding='utf-8', errors='surrogateescape') as f, \
         open(dst, 'w', encoding='utf-8', errors='surrogateescape') as g:
        for line in f:
            g.write(transform_line(line))
    print(src, '->', dst)
print('gensyms:', n)
