class Gitgrip < Formula
  desc "Multi-repo workflow for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "4c64e1a8aa25b696afceeecff0af2e7bf08f9d43ef6c196b240e1587a1808eb0"

  license "MIT"

  depends_on "rust" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match "Multi-repo workflow tool", shell_output("#{bin}/gr --help")
  end
end
