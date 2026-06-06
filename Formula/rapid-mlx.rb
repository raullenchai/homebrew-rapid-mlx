class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/d1/6a/f9d65abc9e79a6e4d843cf1687614430e678d163f74524bdf16b4b70ca5c/rapid_mlx-0.6.78.tar.gz"
  sha256 "c3f65e3f78f486f5762fd9aba0e6673185dd239b8ade27709437c66131e34ef5"
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
           "rapid-mlx==0.6.78"

    %w[rapid-mlx vllm-mlx].each do |cmd|
      (bin/cmd).write_env_script libexec/"bin"/cmd, PATH: "#{libexec}/bin:${PATH}"
    end
  end

  def caveats
    out = <<~EOS
      Quick start — pick by RAM:
        rapid-mlx serve qwen3.5-4b    # 16+ GB
        rapid-mlx serve qwen3.5-9b    # 24+ GB
        rapid-mlx serve qwen3.5-35b   # 48+ GB

      OpenAI-compatible API:  http://localhost:8000/v1
      All model aliases:      rapid-mlx models
    EOS

    # Only surface the shadow-fix hint when an older curl|bash install
    # is actually present — otherwise the block is just noise. Brew's
    # own PATH-shadow warning fires in the same case but doesn't tell
    # the user *how* to remove the offending binary.
    #
    # ``File.symlink?`` covers dangling symlinks too: if the curl|bash
    # install was later removed but its symlink remains in
    # ``~/.local/bin``, that broken symlink still wins on PATH and we
    # still want to surface the cleanup hint.
    shadows = ["~/.local/bin/rapid-mlx", "~/.local/bin/vllm-mlx"]
              .map { |p| File.expand_path(p) }
              .select { |p| File.exist?(p) || File.symlink?(p) }
    unless shadows.empty?
      # Single-quote each path so a copy-paste survives a HOME with a
      # space in it. ``expand_path`` output cannot itself contain a
      # single quote unless the username does, which would already
      # break a great many other things.
      quoted = shadows.map { |p| "'#{p}'" }.join(" ")
      out += <<~EOS

        An older curl|bash install is shadowing this Homebrew install. Remove it:
          rm -f #{quoted}
      EOS
    end

    out
  end

  test do
    assert_match "usage", shell_output("#{bin}/rapid-mlx --help 2>&1", 0)
  end
end
