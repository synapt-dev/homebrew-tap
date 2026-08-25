class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.20.0.tar.gz"
  sha256 "87c3b2c1ee1c286677d4bbd34abc156c433f9f3299f1fbd5ef78b38dbc3c55cc"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.20.0/synapt-macos-aarch64.tar.gz"
      sha256 "3179130afc7de6e0433f77d6cf37ff750c79197b0e98d6a2927886836f2b6f9f"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.20.0/synapt-linux-x86_64.tar.gz"
      sha256 "0d05df84bd0200bb020d6e635973220bb0fe5995ae77a5f4455c6f7b2adeec38"
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
