class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.24.2.tar.gz"
  sha256 "ba1e73ff179693b3e2be739731c4e9becc42f010dd1e10bfddc913822473e4b8"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.24.2/synapt-macos-aarch64.tar.gz"
      sha256 "a6a2031ec2014e6198bd605f316120ba601acf296f82b23c74de32761394dd52"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.24.2/synapt-linux-x86_64.tar.gz"
      sha256 "5b4c09db4dd425b3126a30f049dba0534becf8dda69fa065a0fa1001eef536da"
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
