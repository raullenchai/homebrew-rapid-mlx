class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/ff/2d/4ae48439d5e54218c8522efd5b852a5fc034050961f7d12d9a52eea3ff8b/rapid_mlx-0.6.79.tar.gz"
  sha256 "089bf46ff20dc378fcdff22a0c9f1817d81aa129338cc33133674aefb40f850f"
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
           "rapid-mlx==0.6.79"

    # ``register-python-argcomplete`` is the argcomplete-bundled helper
    # used below to generate shell completion scripts. Wrap it
    # alongside the main entrypoints so anyone who prefers an explicit
    # ``eval "$(register-python-argcomplete rapid-mlx)"`` line in their
    # rc still has a stable, version-free path to point at.
    %w[rapid-mlx vllm-mlx register-python-argcomplete].each do |cmd|
      (bin/cmd).write_env_script libexec/"bin"/cmd, PATH: "#{libexec}/bin:${PATH}"
    end

    # Pre-generate shell completion scripts and drop them into
    # Homebrew's standard locations. ``brew shellenv`` adds these
    # directories to ``FPATH`` (zsh) / ``BASH_COMPLETION_COMPAT_DIR``
    # (bash) / fish's vendor completions, so users get tab completion
    # automatically on the next shell — no manual ``eval`` line in
    # their rc. The generated scripts invoke ``rapid-mlx`` by name
    # (no hardcoded paths), so they survive every upgrade.
    rpa = libexec/"bin/register-python-argcomplete"
    (bash_completion/"rapid-mlx").write Utils.safe_popen_read(rpa, "rapid-mlx")
    (zsh_completion/"_rapid-mlx").write Utils.safe_popen_read(rpa, "--shell", "zsh", "rapid-mlx")
    (fish_completion/"rapid-mlx.fish").write Utils.safe_popen_read(rpa, "--shell", "fish", "rapid-mlx")
  end

  def caveats
    out = <<~EOS
      Quick start — pick by RAM:
        rapid-mlx serve qwen3.5-4b    # 16+ GB
        rapid-mlx serve qwen3.5-9b    # 24+ GB
        rapid-mlx serve qwen3.5-35b   # 48+ GB

      OpenAI-compatible API:  http://localhost:8000/v1
      All model aliases:      rapid-mlx models

      Tab completion (alias names, flags, subcommands) is enabled
      automatically — start a new shell to load it. Verify with:
        rapid-mlx ser<TAB>      # → serve
        rapid-mlx chat <TAB>    # → alias list

      If completion doesn't fire, ``brew shellenv`` is not in your rc.
      Either add it (recommended), or fall back to the manual line:
        eval "$(register-python-argcomplete rapid-mlx)"
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
