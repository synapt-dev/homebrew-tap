class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.25.3.tar.gz"
  sha256 "9307187b2d60dc2f80bb36aa553f1184c2c48a6f111fff3528531bb5d2328004"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.25.3/synapt-macos-aarch64.tar.gz"
      sha256 "0cea61a4f65c55e8f6f2ada4e87ba52c13c920f151400be26f547970d642b48d"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.25.3/synapt-linux-x86_64.tar.gz"
      sha256 "d7bf422b789db99c837f2e6c103b9cb84cf6eddb0e46ef24633b7613972a5659"
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
