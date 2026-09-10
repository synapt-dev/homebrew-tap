class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.25.0.tar.gz"
  sha256 "526754d3dc59e8d3e35938cdefc99b7e2ddb98e79aed343c4971b0dffd4bbb89"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.25.0/synapt-macos-aarch64.tar.gz"
      sha256 "f0ef4e40404c11d4c3b87af6f07a12be288ef505ce431dcf03ef071fee149941"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.25.0/synapt-linux-x86_64.tar.gz"
      sha256 "c5879d2f83107af0d86bb5588e32866af9ae7e1851b5afdf0e31ce08f1ffa5ee"
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
