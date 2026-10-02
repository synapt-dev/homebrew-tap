class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.27.0.tar.gz"
  sha256 "ca13fe525a128d1fc8d492e0f40483634989b549807af0b4e72fcfe9654fe8da"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.27.0/synapt-macos-aarch64.tar.gz"
      sha256 "e897d61982eee34362298ee04244bc80210a29676c826bbd73c7291db6520ba2"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.27.0/synapt-linux-x86_64.tar.gz"
      sha256 "0ad1fe45a750934898638f4d9c6a653fceb76fcb700bee7ef037dfbb0c2fb828"
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
