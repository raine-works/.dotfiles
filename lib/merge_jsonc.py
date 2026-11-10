"""Deep-merge a tracked JSON base file under a local JSONC settings file.

Usage: merge_jsonc.py <base> <local> [forced-key ...]

Local values win, except top-level keys named as forced, which always take the
base value. Comments and trailing commas in the local file are tolerated (Zed
writes JSONC) but are not preserved.
"""

import json
import os
import sys


def strip_jsonc(text):
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i : j + 1])
            i = j + 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            i = n if i == -1 else i
        elif text.startswith("/*", i):
            i = text.find("*/", i + 2)
            i = n if i == -1 else i + 2
        else:
            out.append(c)
            i += 1
    cleaned = "".join(out)
    # Remove trailing commas before } or ].
    result, in_str, k = [], False, 0
    while k < len(cleaned):
        c = cleaned[k]
        if c == '"' and (k == 0 or cleaned[k - 1] != "\\"):
            in_str = not in_str
        if c == "," and not in_str:
            rest = cleaned[k + 1 :].lstrip()
            if rest[:1] in ("}", "]"):
                k += 1
                continue
        result.append(c)
        k += 1
    return "".join(result)


def load(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        text = strip_jsonc(f.read())
    return json.loads(text) if text.strip() else {}


def deep_merge(base, override):
    merged = dict(base)
    for key, value in override.items():
        if isinstance(merged.get(key), dict) and isinstance(value, dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def main():
    base_path, local_path, forced = sys.argv[1], sys.argv[2], sys.argv[3:]
    base, local = load(base_path), load(local_path)
    merged = deep_merge(base, local)
    for key in forced:
        if key in base:
            merged[key] = base[key]
    if merged == local:
        return
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    if os.path.exists(local_path):
        os.replace(local_path, local_path + ".bak")
    with open(local_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
