class RapidMlx < Formula
  include Language::Python::Virtualenv

  desc "AI inference for Apple Silicon — drop-in OpenAI API replacement"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://github.com/raullenchai/Rapid-MLX/archive/refs/tags/v0.3.3.tar.gz"
  sha256 "8e8ae04587c1230690470f7fda10289f2727d8d53118bb639890dbb79cf2f2f9"
  license "Apache-2.0"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "python@3.12"

  def install
    venv = virtualenv_create(libexec, "python3.12")
    # Install from PyPI to ensure all dependencies are resolved
    venv.pip_install "rapid-mlx==#{version}"
    # Link CLI entry points from the venv
    %w[rapid-mlx vllm-mlx].each do |cmd|
      (bin/cmd).write_env_script libexec/"bin"/cmd, PATH: "#{libexec}/bin:${PATH}"
    end
  end

  def caveats
    <<~EOS
      Start serving a model:
        rapid-mlx serve qwen3.5-9b --port 8000

      Then point any OpenAI-compatible app at:
        http://localhost:8000/v1

      List available model aliases:
        rapid-mlx models
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/rapid-mlx --help 2>&1", 0)
  end
end
