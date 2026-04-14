class Gitgrip < Formula
  desc "Multi-repo workflow tool for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v0.20.0.tar.gz"
  sha256 "9b8e76f1e4f2b0306a1b05175dd90deed293f00c82744aa54526bae07eba6d6a"

  license "MIT"

  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "pkg-config" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match "Multi-repo workflow tool", shell_output("#{bin}/gr --help")
  end
end
