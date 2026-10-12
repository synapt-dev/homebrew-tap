class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.28.0.tar.gz"
  sha256 "fbc68a463d0ea7f1a7d71c662a31f90580c5d0cfff49d87b1b9783aa7061c3cb"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.28.0/synapt-macos-aarch64.tar.gz"
      sha256 "6f9d659f143b9798105cfef54cd59f41af5bc2342a932bc523fe610cad9e3b04"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.28.0/synapt-linux-x86_64.tar.gz"
      sha256 "563b54977254275877ba60b99b24a93b86c75e081f79d65412b6bacffd34e610"
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
