class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.29.0.tar.gz"
  sha256 "091b8d7ae0afd49a2bb8ee52c19c1358f10a814733d6a754d76d0bb5e03d18e9"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.29.0/synapt-macos-aarch64.tar.gz"
      sha256 "6b4ee1e29eca90a88a3a0e14dfb9c5372302e668ddf2d598e90ce1810a92dff6"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.29.0/synapt-linux-x86_64.tar.gz"
      sha256 "ba678c3d8802306d1d96d463cf881d49fe6e6310d208111b4024639ed5eea875"
    end
  end

  def install
    resource("binary").stage do
      bin.install "synapt"
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/synapt --version")
  end
end
