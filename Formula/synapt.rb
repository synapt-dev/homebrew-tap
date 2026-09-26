class Synapt < Formula
  desc "Persistent conversational memory for AI coding assistants"
  homepage "https://synapt.dev"
  url "https://github.com/synapt-dev/recall/archive/refs/tags/v0.25.4.tar.gz"
  sha256 "fa4d466ce7659b82a5d3cbceae578b45dbf423440afca0970708e3df5c594241"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
  end

  on_linux do
    depends_on arch: :x86_64
  end

  resource "binary" do
    on_macos do
      url "https://github.com/synapt-dev/recall/releases/download/v0.25.4/synapt-macos-aarch64.tar.gz"
      sha256 "09a66cdf5fa89e79841b412a83dac32531962f78a4e1b65fffe12697e3ab24bc"
    end
    on_linux do
      url "https://github.com/synapt-dev/recall/releases/download/v0.25.4/synapt-linux-x86_64.tar.gz"
      sha256 "721cb69188c2b18d2c8b64c5030e32b9f064e72ebe922086f0a7dd75d6209de7"
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
