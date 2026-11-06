#!/usr/bin/env python3
"""Split an arm64 Mach-O's __text into functions and fingerprint each one.

Function boundaries: LC_FUNCTION_STARTS (cross-checked against dyld_info).
Disassembly: Apple's llvm-objdump. Pointer slots: Apple's `dyld_info -fixups`.

Every instruction is kept (opcode, registers, ordinary immediates). Anything
that is an *address* is replaced by a label naming what it points at, so the
label survives layout changes between builds but changes if the target does:

  call to an import      -> call:<symbol>            (via __stubs + GOT bind)
  objc_msgSend stub      -> msg:<selector>            (via __objc_stubs + selref)
  load/lea of a string   -> str:<the string text>     (cstring-like sections, CFString)
  load from a GOT/ptr    -> sym:<symbol> or what the rebase target resolves to
  Swift mangled typeref  -> typeref:<mangled name>
  branch inside function -> L+<offset from function start>
  call to own function   -> fn:<callee's pass-1 fingerprint>   (second pass)
  anything else          -> sect:<segment,section>

Linker-hint (LOH) rewrites are canonicalised: adrp lines and nops are dropped,
and `adr X, T` == `adrp X; add X, X, lo(T)`; `ldr X, =T` == `adrp; ldr X, [Y, lo(T)]`.

Usage: functions.py <binary> <out.json> [--dump-dir DIR]
  --dump-dir writes each function's normalised text, for spot checks and diffs.
"""
import bisect
import hashlib
import json
import os
import re
import struct
import subprocess
import sys

LC_SEGMENT_64 = 0x19
LC_FUNCTION_STARTS = 0x26

STRING_SECTS = {"__cstring", "__objc_classname", "__objc_methname", "__objc_methtype",
                "__swift5_reflstr", "__oslogstring", "__ustring"}
BRANCHES = {"b", "bl", "cbz", "cbnz", "tbz", "tbnz"}
LINE = re.compile(r"\s*([0-9a-f]+):\s+(\S+)\s*(.*)$")
ANNOT = re.compile(r"\s*<[^>]*>")
HEXNUM = re.compile(r"0x[0-9a-f]+")


class MachO:
    def __init__(self, path):
        self.path = path
        self.data = open(path, "rb").read()
        d = self.data
        magic, _, _, _, ncmds, _, _, _ = struct.unpack_from("<IiiIIIII", d, 0)
        assert magic == 0xFEEDFACF, "not a thin 64-bit Mach-O"
        self.segments, self.sections, self.fstarts_cmd = [], [], None
        off = 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from("<II", d, off)
            if cmd == LC_SEGMENT_64:
                segname = d[off + 8:off + 24].rstrip(b"\0").decode()
                vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<QQQQ", d, off + 24)
                self.segments.append((vmaddr, vmsize, fileoff, filesize, segname))
                nsects = struct.unpack_from("<I", d, off + 64)[0]
                s = off + 72
                for _ in range(nsects):
                    sect = d[s:s + 16].rstrip(b"\0").decode()
                    seg = d[s + 16:s + 32].rstrip(b"\0").decode()
                    addr, size = struct.unpack_from("<QQ", d, s + 32)
                    reserved2 = struct.unpack_from("<I", d, s + 72)[0]
                    self.sections.append((addr, size, seg, sect, reserved2))
                    s += 80
            elif cmd == LC_FUNCTION_STARTS:
                self.fstarts_cmd = struct.unpack_from("<II", d, off + 8)
            off += cmdsize
        self.sections.sort()
        self._sect_addrs = [s[0] for s in self.sections]

    def section(self, name, seg="__TEXT"):
        for s in self.sections:
            if s[2] == seg and s[3] == name:
                return s
        return None

    def section_at(self, addr):
        i = bisect.bisect_right(self._sect_addrs, addr) - 1
        if i >= 0:
            a, size, seg, sect, _ = self.sections[i]
            if a <= addr < a + size:
                return seg, sect
        return None

    def read(self, addr, n):
        for vmaddr, vmsize, fileoff, filesize, _ in self.segments:
            if vmaddr <= addr < vmaddr + filesize:
                o = fileoff + addr - vmaddr
                return self.data[o:o + n]
        return b""

    def cstring(self, addr, limit=4096):
        raw = self.read(addr, limit)
        return raw.split(b"\0", 1)[0].decode("utf-8", "backslashreplace")

    def function_starts(self):
        text_vmaddr = next(s[0] for s in self.segments if s[4] == "__TEXT")
        dataoff, datasize = self.fstarts_cmd
        blob = self.data[dataoff:dataoff + datasize]
        addrs, addr, i = [], text_vmaddr, 0
        while i < len(blob):
            val, shift = 0, 0
            while True:
                byte = blob[i]
                i += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not byte & 0x80:
                    break
            if val == 0:
                break
            addr += val
            addrs.append(addr)
        return addrs


def load_fixups(path):
    out = subprocess.run(["xcrun", "dyld_info", "-fixups", path],
                         capture_output=True, text=True, check=True).stdout
    fx = {}
    for line in out.splitlines():
        p = line.split()
        if len(p) >= 5 and p[2].startswith("0x"):
            addr = int(p[2], 16)
            if p[3] == "bind":
                fx[addr] = ("bind", p[4].split("/", 1)[-1])
            elif p[3] == "rebase":
                fx[addr] = ("rebase", int(p[4], 16))
    return fx


def disassemble(path, start, end):
    out = subprocess.run(
        ["xcrun", "llvm-objdump", "-d", "--no-show-raw-insn", "--triple=arm64-apple-ios",
         f"--start-address={start:#x}", f"--stop-address={end:#x}", path],
        capture_output=True, text=True, check=True).stdout
    insns = []
    for line in out.splitlines():
        m = LINE.match(line)
        if m:
            ops = ANNOT.sub("", m.group(3).split(";", 1)[0]).strip()
            insns.append((int(m.group(1), 16), m.group(2), ops))
    return insns


def split_ops(ops):
    """Split operands on top-level commas (not inside [ ])."""
    parts, depth, cur = [], 0, ""
    for ch in ops:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def imm(s):
    s = s.strip().lstrip("#")
    return int(s, 16) if s.startswith(("0x", "-0x")) else int(s)


class Resolver:
    def __init__(self, mo, fixups, fstarts):
        self.mo, self.fx = mo, fixups
        self.fset = set(fstarts)
        self.stubs = {}
        for name, step, reg in (("__stubs", None, "x16"), ("__objc_stubs", 32, "x1")):
            sec = mo.section(name)
            if sec:
                self._index_stubs(sec, step or sec[4] or 12, name == "__objc_stubs")

    def _index_stubs(self, sec, step, objc):
        addr, size = sec[0], sec[1]
        pages = {}
        for a, mn, ops in disassemble(self.mo.path, addr, addr + size):
            start = addr + (a - addr) // step * step
            p = split_ops(ops)
            if mn == "adrp":
                pages[p[0]] = int(p[1], 16)
            elif mn == "ldr" and len(p) == 2 and p[1].startswith("["):
                base, *off = p[1].strip("[]").split(",")
                if base.strip() in pages:
                    slot = pages[base.strip()] + (imm(off[0]) if off else 0)
                    if objc and p[0] == "x1":
                        self.stubs[start] = "msg:" + self.label(slot, depth=1)
                    elif not objc and start not in self.stubs:
                        self.stubs[start] = "call:" + self.label(slot, depth=1)

    def label(self, addr, depth=0):
        if addr in self.stubs:
            return self.stubs[addr]
        if addr in self.fx:
            kind, tgt = self.fx[addr]
            if kind == "bind":
                return "sym:" + tgt
            return self.label(tgt, depth + 1) if depth < 3 else "ptr"
        where = self.mo.section_at(addr)
        if where is None:
            return "unmapped"
        seg, sect = where
        if sect in STRING_SECTS:
            return "str:" + repr(self.mo.cstring(addr))
        if sect == "__cfstring":
            slot = addr + 16
            return "cfstr:" + (self.label(slot, depth + 1) if slot in self.fx else "?")
        if sect == "__swift5_typeref":
            return "typeref:" + self._mangled(addr)
        if sect == "__objc_selrefs" or sect == "__objc_classrefs" or sect == "__got":
            return f"{sect}:?"
        if sect == "__text" and addr in self.fset:
            return f"fn:{addr:#x}"   # rewritten in pass 2
        return f"sect:{seg},{sect}"

    def _mangled(self, addr):
        raw, out, i = self.mo.read(addr, 512), [], 0
        while i < len(raw) and raw[i] != 0:
            b = raw[i]
            if 0x01 <= b <= 0x17:
                out.append("<ref>")
                i += 5
            elif 0x18 <= b <= 0x1F:
                out.append("<ref>")
                i += 9
            else:
                out.append(chr(b))
                i += 1
        return "".join(out)


CALL_CLOBBERED = {f"x{i}" for i in range(19)} | {f"w{i}" for i in range(19)}
NO_DEST = ("st", "cmp", "cmn", "tst", "ccmp", "ccmn", "fcmp", "prfm", "dmb", "dsb", "isb",
           "ret", "br", "msr", "hint", "pac", "aut", "bti", "brk", "udf", "csdb")


def xreg(r):
    """Canonical 64-bit name for a general register operand (w8 -> x8)."""
    r = r.strip()
    return "x" + r[1:] if re.fullmatch(r"[wx]\d+", r) else r


def written_regs(mn, p):
    """Registers an instruction writes (conservative: may over-approximate)."""
    if not p or mn.startswith(NO_DEST) or mn in BRANCHES or mn.startswith("b."):
        regs = set()
    elif mn.startswith(("ldp", "ldnp", "ldxp", "ldaxp", "casp")):
        regs = {xreg(p[0]), xreg(p[1])}
    else:
        regs = {xreg(p[0])}
    # writeback addressing modes modify the base register
    for x in p:
        if x.startswith("[") and (x.endswith("!") or x.endswith("]") and p.index(x) < len(p) - 1):
            regs.add(xreg(x.strip("[]!").split(",")[0]))
    if mn in ("bl", "blr", "blraa", "blraaz", "blrab", "blrabz"):
        regs |= {f"x{i}" for i in range(19)} | {"x30"}
    return regs


def normalise(func_start, func_end, insns, R):
    """Rewrite one function's instructions into a layout-independent form.

    `known` maps a register to the absolute address it holds when that address
    came from adrp/adr (optionally plus add #imm / mov). Uses of such registers
    as a memory base or add source are rewritten to the label of the address.
    Any write to a register (including both regs of ldp, writeback bases and
    call-clobbered regs) forgets it, so a stale page is never used for a label.
    """
    out, known = [], {}
    for addr, mn, ops in insns:
        p = split_ops(ops)
        if mn == "nop":
            continue
        if mn == "adrp":
            known[xreg(p[0])] = int(p[1], 16)
            continue
        if mn == "adr":
            tgt = int(p[1], 16)
            out.append(f"add {p[0]}, {p[0]}, ={R.label(tgt)}")
            known[xreg(p[0])] = tgt
            continue
        if mn in BRANCHES or mn.startswith("b."):
            tgt = int(p[-1], 16)
            p[-1] = f"L+{tgt - func_start:#x}" if func_start <= tgt < func_end else R.label(tgt)
            out.append(f"{mn} {', '.join(p)}")
            for r in written_regs(mn, p):
                known.pop(r, None)
            continue
        if mn == "add" and len(p) == 3 and xreg(p[1]) in known and p[2].startswith("#"):
            tgt = known[xreg(p[1])] + imm(p[2])
            src = p[0] if xreg(p[0]) == xreg(p[1]) else p[1]
            out.append(f"add {p[0]}, {src}, ={R.label(tgt)}")
            known[xreg(p[0])] = tgt
            continue
        if mn == "mov" and len(p) == 2 and xreg(p[1]) in known and re.fullmatch(r"x\d+", p[0]):
            out.append(f"mov {p[0]}, {p[1]}")
            known[p[0]] = known[xreg(p[1])]
            continue
        mem = next((i for i, x in enumerate(p) if x.startswith("[")), None)
        if mem is not None:
            base, *off = [x.strip() for x in p[mem].rstrip("!").strip("[]").split(",")]
            if xreg(base) in known and (not off or off[0].startswith("#")):
                p[mem] = "[=" + R.label(known[xreg(base)] + (imm(off[0]) if off else 0)) + "]"
        elif mn.startswith("ldr") and len(p) == 2 and HEXNUM.fullmatch(p[1].lstrip("#")):
            p[1] = "[=" + R.label(int(p[1].lstrip("#"), 16)) + "]"   # literal load (LOH)
        out.append(f"{mn} {', '.join(p)}".strip())
        for r in written_regs(mn, p):
            known.pop(r, None)
    return out


def main(argv):
    path, outp = argv[0], argv[1]
    dump_dir = argv[argv.index("--dump-dir") + 1] if "--dump-dir" in argv else None
    mo = MachO(path)
    tstart, tsize = mo.section("__text")[:2]
    starts = [a for a in mo.function_starts() if tstart <= a < tstart + tsize]
    bounds = starts + [tstart + tsize]
    R = Resolver(mo, load_fixups(path), starts)
    insns = disassemble(path, tstart, tstart + tsize)

    funcs, idx = [], 0
    for fi, fs in enumerate(starts):
        fe = bounds[fi + 1]
        while idx < len(insns) and insns[idx][0] < fs:
            idx += 1
        j = idx
        while j < len(insns) and insns[j][0] < fe:
            j += 1
        body = normalise(fs, fe, insns[idx:j], R)
        idx = j
        funcs.append({"addr": fs, "n_insns": len(body), "body": body})

    # pass 1: fingerprint ignoring which own-function is called
    fn_ref = re.compile(r"fn:0x[0-9a-f]+")
    for f in funcs:
        f["fp1"] = hashlib.sha256("\n".join(fn_ref.sub("fn", l) for l in f["body"]).encode()).hexdigest()
    by_addr = {f["addr"]: f["fp1"][:16] for f in funcs}
    # pass 2: name own-function callees by their pass-1 fingerprint
    for f in funcs:
        f["body"] = [fn_ref.sub(lambda m: "fn:" + by_addr.get(int(m.group(0)[3:], 16), "?"), l)
                     for l in f["body"]]
        f["fp"] = hashlib.sha256("\n".join(f["body"]).encode()).hexdigest()
        if dump_dir:
            os.makedirs(dump_dir, exist_ok=True)
            with open(os.path.join(dump_dir, f"{f['addr']:x}.s"), "w") as fh:
                fh.write("\n".join(f["body"]) + "\n")

    labels = sum(1 for f in funcs for l in f["body"] if "=" in l or "call:" in l or "msg:" in l)
    with open(outp, "w") as fh:
        json.dump({"binary": path, "text": [tstart, tsize], "n_functions": len(funcs),
                   "n_insns": sum(f["n_insns"] for f in funcs), "n_stubs_resolved": len(R.stubs),
                   "functions": [{k: f[k] for k in ("addr", "n_insns", "fp", "fp1")} for f in funcs]}, fh)
    print(f"{outp}: {len(funcs)} functions, {sum(f['n_insns'] for f in funcs)} insns, "
          f"{len(R.stubs)} stubs resolved, {labels} resolved address operands")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1:])
