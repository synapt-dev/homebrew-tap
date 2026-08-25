#!/usr/bin/env python3
"""Update tap formulae from the latest public synapt-dev releases."""

from __future__ import annotations

import hashlib
import json
import os
import re
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API = "https://api.github.com"
TOKEN = os.environ.get("GH_TOKEN", "")


def request_bytes(url: str) -> bytes:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "synapt-homebrew-updater",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers)) as response:
        return response.read()


def latest_release(repository: str) -> dict:
    return json.loads(request_bytes(f"{API}/repos/{repository}/releases/latest"))


def sha256_url(url: str) -> str:
    return hashlib.sha256(request_bytes(url)).hexdigest()


def replace_url_and_hash(text: str, old_url_pattern: str, url: str, digest: str) -> str:
    pattern = rf'(url "){old_url_pattern}("\n\s+sha256 ")([0-9a-f]{{64}})(")'
    replacement = rf"\g<1>{url}\g<2>{digest}\g<4>"
    updated, count = re.subn(pattern, replacement, text)
    if count != 1:
        raise RuntimeError(f"expected one formula URL match for {old_url_pattern!r}, got {count}")
    return updated


def update_gitgrip() -> str:
    release = latest_release("synapt-dev/grip")
    tag = release["tag_name"]
    url = f"https://github.com/synapt-dev/grip/archive/refs/tags/{tag}.tar.gz"
    path = ROOT / "Formula" / "gitgrip.rb"
    text = replace_url_and_hash(
        path.read_text(),
        r"https://github\.com/synapt-dev/grip/archive/refs/tags/v[^\"]+\.tar\.gz",
        url,
        sha256_url(url),
    )
    path.write_text(text)
    return tag


def update_synapt() -> str | None:
    release = latest_release("synapt-dev/recall")
    tag = release["tag_name"]
    assets = {asset["name"]: asset["browser_download_url"] for asset in release["assets"]}
    required = ["synapt-macos-aarch64.tar.gz", "synapt-linux-x86_64.tar.gz"]
    if any(name not in assets for name in required):
        print(f"synapt {tag}: release binaries not complete, leaving formula unchanged")
        return None

    source_url = f"https://github.com/synapt-dev/recall/archive/refs/tags/{tag}.tar.gz"
    path = ROOT / "Formula" / "synapt.rb"
    text = replace_url_and_hash(
        path.read_text(),
        r"https://github\.com/synapt-dev/recall/archive/refs/tags/v[^\"]+\.tar\.gz",
        source_url,
        sha256_url(source_url),
    )
    for name in required:
        asset_url = assets[name]
        text = replace_url_and_hash(
            text,
            rf"https://github\.com/synapt-dev/recall/releases/download/v[^\"]+/{re.escape(name)}",
            asset_url,
            sha256_url(asset_url),
        )
    path.write_text(text)
    return tag


def main() -> None:
    print(f"gitgrip: {update_gitgrip()}")
    synapt_tag = update_synapt()
    if synapt_tag:
        print(f"synapt: {synapt_tag}")


if __name__ == "__main__":
    main()
