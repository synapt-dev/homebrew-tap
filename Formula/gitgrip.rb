class Gitgrip < Formula
  desc "Multi-repo workflow for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v1.4.0.tar.gz"
  sha256 "cd39e33511c693c38eba1daa29c43f336077c1ad766d28691dbb8539cd642ff2"

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
