class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.30.0.tar.gz"
  sha256 "efdeba7a799174b05baf9285312bcb688258482613f6e30ae952154542675dcb"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.30.0/synapt-macos-aarch64.tar.gz"
      sha256 "c370cd1d364524140ee536ffccd8872a241548d0bd605f7e966055cd4b1f2f1c"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.30.0/synapt-linux-x86_64.tar.gz"
      sha256 "38b8b9057e2f04542740d6a808a406975845ef14f1cb0565f4d0794cedb2c282"
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
