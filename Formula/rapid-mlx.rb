class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/24/f3/55424dc854219aad9938964cbdca252015a01d23c6cab7dde982b479ed40/rapid_mlx-0.6.13.tar.gz"
  sha256 "c1506d4c17a22b885d32f62e5beefeb9e1a69e1d6daa64716eb741a5a680d489"
  license "Apache-2.0"
  head "https://github.com/raullenchai/Rapid-MLX.git", branch: "main"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "python@3.12"
  # Build dep — pydantic_core is a Rust extension. We rebuild it from
  # source (rather than using the PyPI wheel) so the resulting .so has
  # headerpad space for Homebrew's keg relocation. Without this, every
  # brew install/upgrade prints scary "Error: Failed changing dylib ID"
  # lines for _pydantic_core.cpython-312-darwin.so even though the
  # install otherwise succeeds.
  depends_on "rust" => :build

  def install
    python3 = Formula["python@3.12"].opt_bin/"python3.12"

    # Create venv WITH pip (so we can install dependencies)
    system python3, "-m", "venv", libexec
    venv_pip = libexec/"bin/pip"

    # Tell Cargo's macOS linker to leave room for install_name_tool to
    # rewrite paths. This is the canonical fix for the
    # "larger updated load commands do not fit" relink failure.
    ENV["RUSTFLAGS"] = "-C link-arg=-Wl,-headerpad_max_install_names"

    # Install rapid-mlx with pydantic_core compiled from source (adds
    # ~1 min on first install; cached afterwards).
    system venv_pip, "install", "--no-cache-dir",
           "--no-binary", "pydantic-core",
           "rapid-mlx==0.6.13"

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
