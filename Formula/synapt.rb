class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.26.0.tar.gz"
  sha256 "659004c2d1d0649b669089bcf649233d3ac4c0851ca81a30e688f85c068dd74e"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.26.0/synapt-macos-aarch64.tar.gz"
      sha256 "8b70ae6e4f94fbfd9f2ec8dd65dd61e104c15943a2d422089966d906720793df"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.26.0/synapt-linux-x86_64.tar.gz"
      sha256 "8ba41c2381c2a68e4429009dbf352c003750f8c0091ba89dba62212974c0fc01"
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
