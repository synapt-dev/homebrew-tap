class Gitgrip < Formula
  desc "Multi-repo workflow tool for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "651dbe4fa67464413764d1c7b7104ed94a81ddd8141847570f0975ebbdf744cf"

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
