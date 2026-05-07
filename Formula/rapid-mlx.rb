class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/74/54/d7e8661383614d1ccdd14e39e6272fc53cd9e27774c7eef7a8ac49dae04b/rapid_mlx-0.6.15.tar.gz"
  sha256 "67d36a2919d6c9ae581ac89f7831295f3c4a959327c754aa886bd80c9191fdc0"
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

    system python3, "-m", "venv", libexec
    venv_pip = libexec/"bin/pip"

    # Tell Cargo's macOS linker to leave room for install_name_tool to
    # rewrite paths. This is the canonical fix for the
    # "larger updated load commands do not fit" relink failure on
    # pydantic_core and rpds-py.
    ENV["RUSTFLAGS"] = "-C link-arg=-Wl,-headerpad_max_install_names"

    # Source-build the two Rust extensions whose PyPI wheels lack
    # headerpad space (adds ~1 min on first install). Everything else
    # uses prebuilt wheels. Pip's wheel cache is left enabled so repeat
    # installs / upgrades reuse downloads.
    system venv_pip, "install", "--prefer-binary",
           "--no-binary", "pydantic-core,rpds-py",
           "rapid-mlx==0.6.15"

    %w[rapid-mlx vllm-mlx].each do |cmd|
      (bin/cmd).write_env_script libexec/"bin"/cmd, PATH: "#{libexec}/bin:${PATH}"
    end
  end

  def caveats
    <<~EOS
      Start a server (auto-picks a model that fits your RAM):
        rapid-mlx serve qwen3.5-4b      # 16+ GB
        rapid-mlx serve qwen3.5-9b      # 24+ GB
        rapid-mlx serve qwen3.5-35b     # 48+ GB

      Point any OpenAI-compatible app at http://localhost:8000/v1.
      List all aliases with: rapid-mlx models

      If `rapid-mlx` is shadowed by an older curl|bash install, remove it:
        rm -f ~/.local/bin/rapid-mlx ~/.local/bin/vllm-mlx*
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/rapid-mlx --help 2>&1", 0)
  end
end
