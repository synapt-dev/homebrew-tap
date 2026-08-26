class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.21.0.tar.gz"
  sha256 "44c8c035414082ff127567b129ab0d1e8c163c47fec9ce0468d23cf485113017"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.21.0/synapt-macos-aarch64.tar.gz"
      sha256 "44a527ab1f75ad450573995f037a4439c2bf53adfd8ccda92a7fc941070bf4cc"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.21.0/synapt-linux-x86_64.tar.gz"
      sha256 "c1b6c61ac27cb5e5b38dedf75e40c764240c988b1c0be2c7f06051c447104279"
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
