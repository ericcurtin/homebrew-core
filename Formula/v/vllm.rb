class Vllm < Formula
  include Language::Python::Virtualenv

  desc "High-throughput and memory-efficient inference and serving engine for LLMs"
  homepage "https://github.com/vllm-project/vllm"
  url "https://github.com/vllm-project/vllm/releases/download/v0.13.0/vllm-0.13.0.tar.gz"
  sha256 "4ad43db45fef37114b550d03a4f423fb3fa3a31d8bc09ee810ef8b9cdcd4b5fe"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "rust" => :build
  depends_on "python@3.13"

  on_macos do
    depends_on arch: :arm64
    depends_on "maturin" => :build
  end

  # vllm-metal plugin for macOS Apple Silicon
  resource "vllm-metal" do
    on_macos do
      url "https://github.com/vllm-project/vllm-metal/archive/refs/tags/v0.1.0-20260111-163800.tar.gz"
      sha256 "dc044e472d598162ad1c559789d83c8041a807051bda9373326c216003049adf"
    end
  end

  def install
    python3 = "python3.13"
    venv = virtualenv_create(libexec, python3)

    if OS.mac?
      # On macOS Apple Silicon, install vllm-metal plugin
      # which provides Metal/MLX acceleration
      resource("vllm-metal").stage do
        system "maturin", "build", "--release", "-o", "dist"
        wheel = Dir["dist/*.whl"].first
        venv.pip_install wheel
      end
    end

    # Install vllm with CPU support
    # On macOS: The vllm-metal plugin provides the Metal acceleration
    # On Linux: For CUDA support, users should use pip with CUDA wheels
    ENV["VLLM_TARGET_DEVICE"] = "cpu"
    ENV["MAX_JOBS"] = ENV.make_jobs.to_s
    venv.pip_install_and_link buildpath
  end

  def caveats
    if OS.mac?
      <<~EOS
        vLLM has been installed with Metal/MLX support via vllm-metal plugin
        for Apple Silicon Macs.

        To start the vLLM server:
          vllm serve <model>

        Environment variables for Metal backend customization:
          VLLM_METAL_MEMORY_FRACTION - Memory allocation (default: auto)
          VLLM_METAL_USE_MLX - Use MLX backend (default: 1)
      EOS
    else
      <<~EOS
        vLLM has been installed with CPU support.

        For CUDA support, please install via pip with the appropriate
        CUDA wheels from https://github.com/vllm-project/vllm/releases

        To start the vLLM server:
          vllm serve <model>
      EOS
    end
  end

  test do
    # Test CLI is accessible and shows help
    output = shell_output("#{bin}/vllm --help 2>&1")
    assert_match "vllm", output

    # Test that vllm module can be imported
    system libexec/"bin/python", "-c", "import vllm; print(vllm.__version__)"
  end
end
