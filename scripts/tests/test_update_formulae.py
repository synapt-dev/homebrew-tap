#!/usr/bin/env python3
"""Witnesses for update_formulae.py: gitgrip follows the highest v1 release.

A final gr2/v* release becomes releases/latest on synapt-dev/grip; gitgrip.rb
must not move to it. The GitHub API is stubbed: fixtures only, no network.

Run: python3 -m unittest discover -s scripts/tests -p 'test_update_formulae.py'
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
FIXTURES = HERE / "fixtures"
GRIP_TAG_URL = "https://github.com/synapt-dev/grip/archive/refs/tags/"


def load_module():
    spec = importlib.util.spec_from_file_location("update_formulae", REPO / "scripts" / "update_formulae.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def release(tag: str, prerelease: bool = False, draft: bool = False, assets=()) -> dict:
    return {
        "tag_name": tag,
        "prerelease": prerelease,
        "draft": draft,
        "assets": [{"name": n, "browser_download_url": u} for n, u in assets],
    }


class FakeGitHub:
    """Answers request_bytes from a fixture release list per repository."""

    def __init__(self, releases: dict[str, list[dict]]):
        self.releases = releases
        self.urls: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.urls.append(url)
        for repository, items in self.releases.items():
            base = f"https://api.github.com/repos/{repository}/releases"
            if url == f"{base}/latest":
                final = [r for r in items if not r["draft"] and not r["prerelease"]]
                return json.dumps(final[0]).encode()
            if url.startswith(f"{base}?"):
                query = parse_qs(urlsplit(url).query)
                per_page = int(query.get("per_page", ["30"])[0])
                page = int(query.get("page", ["1"])[0])
                return json.dumps(items[(page - 1) * per_page : page * per_page]).encode()
        if url.startswith("https://api.github.com/"):
            raise AssertionError(f"unexpected API url {url}")
        return b"tarball:" + url.encode()


def digest(url: str) -> str:
    return hashlib.sha256(b"tarball:" + url.encode()).hexdigest()


class UpdateFormulaeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        shutil.copytree(REPO / "Formula", self.tmp / "Formula")
        self.mod = load_module()
        self.mod.ROOT = self.tmp

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def stub(self, grip: list[dict], recall: list[dict] | None = None) -> FakeGitHub:
        fake = FakeGitHub({"synapt-dev/grip": grip, "synapt-dev/recall": recall or []})
        self.mod.request_bytes = fake
        return fake

    def gitgrip_text(self) -> str:
        return (self.tmp / "Formula" / "gitgrip.rb").read_text()

    def test_f1_final_gr2_latest_keeps_gitgrip_on_v1(self):
        self.stub([release("gr2/v2.0.0"), release("gr2/v2.0.0a12", prerelease=True), release("v1.6.0")])
        tag = self.mod.update_gitgrip()
        text = self.gitgrip_text()
        self.assertNotIn("tags/gr2", text)
        self.assertEqual(tag, "v1.6.0")
        url = f"{GRIP_TAG_URL}v1.6.0.tar.gz"
        self.assertIn(f'url "{url}"\n  sha256 "{digest(url)}"', text)

    def test_f2_newest_v1_patch_release_is_taken(self):
        self.stub([release("gr2/v2.0.1"), release("v1.6.1"), release("gr2/v2.0.0"), release("v1.6.0")])
        tag = self.mod.update_gitgrip()
        text = self.gitgrip_text()
        self.assertNotIn("tags/gr2", text)
        self.assertEqual(tag, "v1.6.1")
        url = f"{GRIP_TAG_URL}v1.6.1.tar.gz"
        self.assertIn(f'url "{url}"\n  sha256 "{digest(url)}"', text)

    def test_f3_no_v1_release_refuses_and_leaves_gitgrip(self):
        before = self.gitgrip_text()
        self.stub([release("gr2/v2.0.0"), release("gr2/v2.0.0a12", prerelease=True)])
        with self.assertRaises(Exception) as caught:
            self.mod.update_gitgrip()
        self.assertEqual(self.gitgrip_text(), before)
        self.assertNotIn("tags/gr2", self.gitgrip_text())
        self.assertIn("gitgrip", str(caught.exception))

    def assert_gitgrip_at(self, tag: str, got: str):
        text = self.gitgrip_text()
        self.assertEqual(got, tag)
        url = f"{GRIP_TAG_URL}{tag}.tar.gz"
        self.assertIn(f'url "{url}"\n  sha256 "{digest(url)}"', text)

    def test_f5_backport_created_after_higher_v1_does_not_downgrade(self):
        # API order is newest-created first: v1.5.3 came off release/1.x after v1.6.0.
        self.stub([release("gr2/v2.0.0"), release("v1.5.3"), release("v1.6.0")])
        self.assert_gitgrip_at("v1.6.0", self.mod.update_gitgrip())

    def test_f6_only_v1_on_page_two_is_found(self):
        newer = [release(f"gr2/v2.0.{n}") for n in range(100, 0, -1)]
        fake = self.stub(newer + [release("v1.6.0")])
        self.assert_gitgrip_at("v1.6.0", self.mod.update_gitgrip())
        self.assertTrue(any("page=2" in u for u in fake.urls))

    def test_f7_final_release_with_rc_tag_is_not_taken(self):
        self.stub([release("v1.6.0-rc1"), release("v1.7"), release("v1.6.0")])
        self.assert_gitgrip_at("v1.6.0", self.mod.update_gitgrip())

    def test_f4_synapt_path_unchanged(self):
        tag = "v0.30.0"
        names = ["synapt-macos-aarch64.tar.gz", "synapt-linux-x86_64.tar.gz"]
        assets = [(n, f"https://github.com/synapt-dev/recall/releases/download/{tag}/{n}") for n in names]
        self.stub([release("gr2/v2.0.0"), release("v1.6.0")], [release(tag, assets=assets)])
        shutil.copyfile(FIXTURES / "Formula" / "synapt.rb", self.tmp / "Formula" / "synapt.rb")
        expected = (self.tmp / "Formula" / "synapt.rb").read_text()
        source = f"https://github.com/synapt-dev/recall/archive/refs/tags/{tag}.tar.gz"
        old = "https://github.com/synapt-dev/recall/"
        expected = expected.replace(
            f'{old}archive/refs/tags/v0.1.0.tar.gz"\n  sha256 "{"1" * 64}"',
            f'{source}"\n  sha256 "{digest(source)}"',
        )
        expected = expected.replace(
            f'{old}releases/download/v0.1.0/{names[0]}"\n      sha256 "{"2" * 64}"',
            f'{assets[0][1]}"\n      sha256 "{digest(assets[0][1])}"',
        )
        expected = expected.replace(
            f'{old}releases/download/v0.1.0/{names[1]}"\n      sha256 "{"3" * 64}"',
            f'{assets[1][1]}"\n      sha256 "{digest(assets[1][1])}"',
        )
        self.assertEqual(self.mod.update_synapt(), tag)
        self.assertEqual((self.tmp / "Formula" / "synapt.rb").read_text(), expected)
        self.assertNotIn("v0.1.0", expected)


if __name__ == "__main__":
    unittest.main()
