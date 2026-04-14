class Gitgrip < Formula
  desc "Multi-repo workflow tool for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v0.18.0.tar.gz"
  sha256 "56d7cbedd7539e1e062bcfd24b75e392a4b15b26067daaf3b7d937c16d282fc8"

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
