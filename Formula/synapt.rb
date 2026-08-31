class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.22.0.tar.gz"
  sha256 "358c36f792e914299f142d49e30d2ec59f5eb12f5a737cb8c17d63156318a2a8"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.22.0/synapt-macos-aarch64.tar.gz"
      sha256 "6de0b5529fdb00c17cba93b01f7c1a0bd4e4e7b407640f96fdbfd792e7f4d949"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.22.0/synapt-linux-x86_64.tar.gz"
      sha256 "4c8544f1755e5d201b813377eb788f34ce06f0f24b244ef89dfa99963496098a"
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
