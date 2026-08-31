class Gitgrip < Formula
  desc "Multi-repo workflow for synchronized branches, linked PRs, and atomic merges"
  homepage "https://synapt.dev/grip"

  url "https://github.com/synapt-dev/grip/archive/refs/tags/v1.3.1.tar.gz"
  sha256 "fcac377a09315a70d82093c077ac5d9ff12bf7d192185c41d8e40cb8a7297e90"

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
