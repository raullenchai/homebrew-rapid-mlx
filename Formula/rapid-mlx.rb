class RapidMlx < Formula
  desc "AI inference for Apple Silicon — drop-in OpenAI API, 2-4x faster than Ollama"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://files.pythonhosted.org/packages/5b/89/b890f3f5c5ca35a0091e65791b927a448fa209e0a4ca8dbb5bb988e4f76c/rapid_mlx-0.10.7.tar.gz"
  sha256 "bf006624f500e4ff02c5e6212576e0a6b247ebc797c323742ebd76afceb37510"
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
           "rapid-mlx==0.10.7"

    # Gemma 4 family text inference (``gemma-4-12b``, ``gemma-4-12b-qat-8bit``,
    # ``gemma-4-26b``, ``gemma-4-31b``, ``gemma4`` shorthand — 11 aliases)
    # needs ``mlx_vlm.models.gemma4.{config,language}`` classes. Without
    # mlx-vlm installed, ``vllm_mlx/models/gemma4_text.py:137`` raises
    # ``ModuleNotFoundError: mlx_vlm`` and the entire family is broken.
    #
    # Plain ``pip install mlx-vlm`` would drag in 450 MB of vision /
    # audio / data deps (opencv-python, scipy, pyarrow, pandas, datasets,
    # mlx-audio, miniaudio) that rapid-mlx's text-only inference never
    # touches. ``--no-deps`` installs only the 16 MB of mlx-vlm Python
    # source — enough to unlock Gemma 4 without bloating the install.
    # Verified end-to-end: clean venv 460 MB → 476 MB; gemma-4-12b-qat-8bit
    # loads + infers without any deferred-import error from the gemma4
    # loader path. Users who want the full vision / audio stack still
    # ``pip install rapid-mlx[vision]``.
    system venv_pip, "install", "--no-deps", "mlx-vlm>=0.6.1"

    # Only expose the two rapid-mlx entrypoints to the user's PATH.
    #
    # We used to also wrap ``register-python-argcomplete`` so the
    # fallback ``eval "$(register-python-argcomplete rapid-mlx)"``
    # caveat resolved against a brew-installed copy. That clashed with
    # any other Python install that already drops the same binary into
    # ``/opt/homebrew/bin`` (the argcomplete pip package, a global
    # python install, etc.): on upgrade, ``brew link`` aborted on the
    # symlink conflict, which prevented ``rapid-mlx`` itself from
    # being linked — leaving the user with no working binary after a
    # successful build. Reported on the 0.6.79 → 0.6.80 upgrade.
    #
    # We don't need it on PATH anymore. The auto-installed completion
    # scripts below cover every interactive shell without the user
    # ever invoking ``register-python-argcomplete`` themselves; the
    # generated scripts also embed the absolute libexec path so they
    # survive the helper not being on PATH.
    %w[rapid-mlx vllm-mlx].each do |cmd|
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
      Add it (recommended) and start a new shell.
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
