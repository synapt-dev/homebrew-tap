class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.24.1.tar.gz"
  sha256 "26b9294bffaf45a5e7f4deb7305f5821660601c8cbfd5a792a9bc0f7ecf1a375"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.24.1/synapt-macos-aarch64.tar.gz"
      sha256 "8b199f5c0bd816cefce3733515308a82b74ab22e093874b054878c5cb95d5c5a"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.24.1/synapt-linux-x86_64.tar.gz"
      sha256 "fbecb5d8938d3a851f9f62d61c57b45816054f5f3a09ba4c962da888182ad037"
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
