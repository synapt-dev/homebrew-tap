class Gitgrip < Formula
  desc "Multi-repo workflow for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v1.5.0.tar.gz"
  sha256 "bed778bc603b4ba056d4c3a571d874ec1cd69887d4db369eac5bf5be4c1a9ce9"

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
