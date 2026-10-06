#!/usr/bin/env python3
"""Check each literal SF Symbol's own modifier chain, including multiline code.

This is a source heuristic, not a Swift type checker or a VoiceOver certificate.
Comments, strings and nested modifier arguments cannot label a sibling image.
"""

import re
import sys
from pathlib import Path


def tokens(source):
    result = []
    index = 0
    while index < len(source):
        if source[index].isspace():
            index += 1
            continue
        if source.startswith("//", index):
            end = source.find("\n", index)
            index = len(source) if end < 0 else end
            continue
        if source.startswith("/*", index):
            depth = 1
            index += 2
            while index < len(source) and depth:
                if source.startswith("/*", index):
                    depth += 1
                    index += 2
                elif source.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            continue
        string = re.match(r'(#+)?("""|")', source[index:])
        if string:
            start = index
            hashes, quotes = string.group(1) or "", string.group(2)
            closing = quotes + hashes
            index += len(string.group())
            while index < len(source):
                if source.startswith(closing, index):
                    index += len(closing)
                    break
                if not hashes and source[index] == "\\":
                    index += 2
                else:
                    index += 1
            result.append((source[start:index], start))
            continue
        identifier = re.match(r'[A-Za-z_][A-Za-z_0-9]*', source[index:])
        text = identifier.group() if identifier else source[index]
        result.append((text, index))
        index += len(text)
    return result


def after_group(items, start):
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = []
    for index in range(start, len(items)):
        text = items[index][0]
        if text in pairs:
            stack.append(pairs[text])
        elif text in pairs.values():
            if not stack or stack.pop() != text:
                return None
            if not stack:
                return index + 1
    return None


def unlabelled_symbols(source):
    items = tokens(source)
    lines = source.splitlines()
    for index, (text, position) in enumerate(items):
        if text != "Image" or [item[0] for item in items[index + 1:index + 4]] != ["(", "systemName", ":"]:
            continue
        if index + 4 >= len(items) or not re.match(r'^#*"', items[index + 4][0]):
            continue
        end = after_group(items, index + 1)
        if end is None:
            continue
        labelled = False
        hidden = False
        while end + 2 < len(items) and items[end][0] == ".":
            modifier = items[end + 1][0]
            argument_start = end + 2
            if items[argument_start][0] not in {"(", "{"}:
                break
            next_end = after_group(items, argument_start)
            if next_end is None:
                break
            arguments = [item[0] for item in items[argument_start + 1:next_end - 1]]
            if modifier in {"accessibilityLabel", "labelStyle"}:
                labelled = True
            if modifier == "accessibilityHidden":
                hidden = arguments == ["true"]
            end = next_end
            if end < len(items) and items[end][0] == "{":
                end = after_group(items, end)
                if end is None:
                    break
        line = source.count("\n", 0, position) + 1
        if not labelled and not hidden and "a11y: allow" not in lines[line - 1]:
            yield line, lines[line - 1]


def main():
    for filename in sys.argv[1:]:
        source = Path(filename).read_text(encoding="utf-8")
        for line, text in unlabelled_symbols(source):
            print(f"[image-needs-label-or-hidden] {filename}:{line}:{text}")
            print("  Standalone SF Symbol should be labeled or hidden for VoiceOver.")
            print("  Prefer: .accessibilityLabel(...) for meaningful icons, or .accessibilityHidden(true) for purely decorative")


if __name__ == "__main__":
    main()
