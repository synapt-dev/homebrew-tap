class Gitgrip < Formula
  desc "Multi-repo workflow for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v1.5.2.tar.gz"
  sha256 "986522527dc973b471ec78773ac3465f5410670dc956e4db2482e61245e9ea16"

  license "MIT"

  depends_on "pkg-config" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match "Multi-repo workflow tool", shell_output("#{bin}/gr --help")
  end
end
