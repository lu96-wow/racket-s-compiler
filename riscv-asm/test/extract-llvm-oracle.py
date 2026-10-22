#!/usr/bin/env python3
"""Extract (assembly text -> bytes) pairs from LLVM MC/RISCV tests.

LLVM MC tests place the expected encoding in a CHECK-ASM line immediately
before the instruction under test, for example:

    # CHECK-ASM: encoding: [0x03,0xe0,0x40,0x00]
    lwu x0, 4(x1)

This script extracts only pure-hex encodings. Relocation expressions and
symbolic encodings containing A/0b... are skipped.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from collections import Counter, defaultdict
from pathlib import Path

ENCODING_RE = re.compile(r"encoding:\s*\[([^\]]*)\]")
PURE_HEX_RE = re.compile(r"^(0x[0-9a-fA-F]+)(?:\s*,\s*0x[0-9a-fA-F]+)*$")
HEX_BYTE_RE = re.compile(r"0x([0-9a-fA-F]+)")
CHECK_ASM_RE = re.compile(r"^#\s*CHECK-ASM(?:-[A-Z0-9-]+)?:\s*(.*)$")


def parse_encoding(text: str) -> list[int] | None:
    m = ENCODING_RE.search(text)
    if not m:
        return None
    body = m.group(1).strip()
    if not PURE_HEX_RE.fullmatch(body):
        return None
    values = [int(x, 16) for x in HEX_BYTE_RE.findall(body)]
    if len(values) not in (2, 4):
        return None
    return values


def bytes_to_word(values: list[int]) -> int:
    word = 0
    for i, b in enumerate(values):
        word |= b << (8 * i)
    return word


def is_comment_or_blank(line: str) -> bool:
    s = line.strip()
    return not s or s.startswith("#")


def is_directive_or_label(line: str) -> bool:
    s = line.strip()
    if not s:
        return True
    if s.startswith("."):
        return True
    if s.endswith(":"):
        return True
    # local labels like .Lfoo:
    if s.startswith(".L") and s.endswith(":"):
        return True
    return False


def strip_inline_comment(line: str) -> str:
    # LLVM RISC-V assembly tests use '#' for comments; no '#' inside operands.
    return line.split("#", 1)[0].strip()


def extract_file(path: Path) -> "list[dict]":
    out: list[dict] = []
    pending: list[int] | None = None
    pending_line: int | None = None
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()

    for lineno, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        m = CHECK_ASM_RE.match(line.strip())
        if m:
            rest = m.group(1)
            enc = parse_encoding(rest)
            if enc is not None:
                pending = enc
                pending_line = lineno
            else:
                # A non-pure CHECK-ASM encoding must not be attached to the
                # next instruction.
                pending = None
                pending_line = None
            continue

        if is_comment_or_blank(line):
            continue

        asm = strip_inline_comment(line)
        if not asm:
            continue
        if is_directive_or_label(asm):
            pending = None
            pending_line = None
            continue

        if pending is not None:
            out.append(
                {
                    "file": str(path),
                    "check_line": pending_line,
                    "asm_line": lineno,
                    "asm": asm,
                    "word": f"0x{bytes_to_word(pending):x}",
                    "size": len(pending),
                }
            )
            pending = None
            pending_line = None

    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--llvm-test-dir",
        default=os.environ.get("LLVM_RISCV_MC_TESTS"),
        help="path to llvm/test/MC/RISCV",
    )
    parser.add_argument(
        "--out",
        default=str(Path(__file__).with_name("oracle") / "llvm-encoding.json"),
    )
    args = parser.parse_args()

    if not args.llvm_test_dir:
        parser.error("--llvm-test-dir or LLVM_RISCV_MC_TESTS is required")
    root = Path(args.llvm_test_dir)
    if not root.is_dir():
        parser.error(f"not a directory: {root}")

    pairs = []
    for path in sorted(root.rglob("*.s")):
        pairs.extend(extract_file(path))

    grouped: dict[str, list[dict]] = defaultdict(list)
    for item in pairs:
        asm = item["asm"]
        mnemonic = asm.split(None, 1)[0]
        grouped[mnemonic].append(
            {
                "asm": asm,
                "word": item["word"],
                "size": item["size"],
                "file": str(Path(item["file"]).relative_to(root)),
                "asm_line": item["asm_line"],
            }
        )

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(dict(sorted(grouped.items())), indent=2, ensure_ascii=False)
        + "\n",
        encoding="utf-8",
    )

    sizes = Counter(item["size"] for item in pairs)
    print(f"files: {len(list(root.rglob('*.s')))}")
    print(f"encoding pairs: {len(pairs)}")
    print(f"mnemonics: {len(grouped)}")
    print(f"instruction sizes: {dict(sorted(sizes.items()))}")
    print(f"output: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
