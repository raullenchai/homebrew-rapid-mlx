class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/e7/07/454a91e55f8c1d40608d07a66228cab56ad44eccb959161ea362650e2f17/rapid_mlx-0.6.14.tar.gz"
  sha256 "390bf160e0805870f1b2bae0437eadceb96dddc605d3c4fdd877a611afcce73f"
  license "Apache-2.0"
  head "https://github.com/raullenchai/Rapid-MLX.git", branch: "main"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "python@3.12"
  # Build dep — pydantic_core and rpds-py are Rust extensions whose
  # PyPI wheels lack headerpad space, so Homebrew's keg relocation
  # fails with scary "Error: Failed changing dylib ID" lines even
  # though the install otherwise succeeds. Rebuilding from source
  # with the RUSTFLAGS below produces .so files that relink cleanly.
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

    # Install rapid-mlx with pydantic_core and rpds-py compiled from
    # source (adds ~1 min on first install; cached afterwards).
    system venv_pip, "install", "--no-cache-dir",
           "--no-binary", "pydantic-core,rpds-py",
           "rapid-mlx==0.6.14"

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
