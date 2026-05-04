class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/61/4a/8315b2b0750f133f206cbfdccd5032e79e80aeb47d5347de45f2da0a5d13/rapid_mlx-0.6.10.tar.gz"
  sha256 "debe4faf65b9b9ac3c861d0df7917dd57c8e67020f448c5394631931e9de02b4"
  license "Apache-2.0"
  head "https://github.com/raullenchai/Rapid-MLX.git", branch: "main"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "python@3.12"

  def install
    python3 = Formula["python@3.12"].opt_bin/"python3.12"

    # Create venv WITH pip (so we can install dependencies)
    system python3, "-m", "venv", libexec
    venv_pip = libexec/"bin/pip"

    # Install rapid-mlx and all dependencies from PyPI
    system venv_pip, "install", "--no-cache-dir", "rapid-mlx==0.6.10"

    # Link CLI entry points
    %w[rapid-mlx vllm-mlx].each do |cmd|
      (bin/cmd).write_env_script libexec/"bin"/cmd, PATH: "#{libexec}/bin:${PATH}"
    end
  end

  service do
    run [opt_bin/"rapid-mlx", "serve"]
    keep_alive false
    working_dir var
    log_path var/"log/rapid-mlx.log"
    error_log_path var/"log/rapid-mlx.log"
  end

  def caveats
    <<~EOS
      Start serving a model:
        rapid-mlx serve mlx-community/Qwen3.5-4B-MLX-4bit

      Then point any OpenAI-compatible app at:
        http://localhost:8000/v1

      List available model aliases:
        rapid-mlx models

      Tested with: PydanticAI, LangChain, smolagents, Aider,
      LibreChat, Open WebUI, Anthropic SDK, Cursor, Claude Code.
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/rapid-mlx --help 2>&1", 0)
  end
end
