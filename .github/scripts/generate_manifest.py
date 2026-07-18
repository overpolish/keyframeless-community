#!/usr/bin/env python3
"""Generate one index.json per catalog folder.

A catalog is a top-level directory (Shaders, Captions, ...) whose entries are
UUID sub-folders, each holding a single display sub-folder with a metadata.json
plus the entry's files. The manifest is the directory listing the plugin reads
over raw.githubusercontent.com, so browsing needs zero GitHub REST API calls
(and never trips the 60/hour unauthenticated rate limit).

Output is deterministic (entries + files sorted, no timestamps) so a run only
produces a diff when the catalog actually changed.
"""

import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST_NAME = "index.json"


def is_catalog(name: str) -> bool:
    if name.startswith("."):
        return False
    path = os.path.join(REPO_ROOT, name)
    return os.path.isdir(path)


def build_entry(catalog: str, uuid: str):
    """Return the manifest entry for one UUID folder, or None if malformed."""
    uuid_dir = os.path.join(REPO_ROOT, catalog, uuid)
    subdirs = sorted(
        d for d in os.listdir(uuid_dir) if os.path.isdir(os.path.join(uuid_dir, d))
    )
    if not subdirs:
        return None
    folder = subdirs[0]  # the single display sub-folder
    entry_dir = os.path.join(uuid_dir, folder)

    meta_path = os.path.join(entry_dir, "metadata.json")
    if not os.path.isfile(meta_path):
        return None
    try:
        with open(meta_path, "r", encoding="utf-8") as f:
            metadata = json.load(f)
    except (ValueError, OSError):
        return None
    if not isinstance(metadata, dict) or "name" not in metadata:
        return None

    files = sorted(
        f for f in os.listdir(entry_dir) if os.path.isfile(os.path.join(entry_dir, f))
    )

    return {
        "uuid": uuid,
        "folder": folder,
        "metadata": metadata,
        "files": files,
    }


def build_catalog(catalog: str):
    catalog_dir = os.path.join(REPO_ROOT, catalog)
    uuids = sorted(
        d for d in os.listdir(catalog_dir) if os.path.isdir(os.path.join(catalog_dir, d))
    )
    entries = []
    for uuid in uuids:
        entry = build_entry(catalog, uuid)
        if entry is not None:
            entries.append(entry)
    entries.sort(key=lambda e: e["metadata"].get("name", "").lower())
    return {"version": 1, "entries": entries}


def main() -> int:
    catalogs = sorted(n for n in os.listdir(REPO_ROOT) if is_catalog(n))
    for catalog in catalogs:
        manifest = build_catalog(catalog)
        out_path = os.path.join(REPO_ROOT, catalog, MANIFEST_NAME)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2, sort_keys=True, ensure_ascii=False)
            f.write("\n")
        print(f"{catalog}/{MANIFEST_NAME}: {len(manifest['entries'])} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
