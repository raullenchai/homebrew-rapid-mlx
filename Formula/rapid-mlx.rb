class RapidMlx < Formula
  include Language::Python::Virtualenv

  desc "AI inference for Apple Silicon — drop-in OpenAI API replacement"
  homepage "https://github.com/raullenchai/Rapid-MLX"
  url "https://github.com/raullenchai/Rapid-MLX/archive/refs/tags/v0.3.11.tar.gz"
  sha256 "4a277c4d8f5b9cd5c341c8b117a793488a745cd602bd72421618d7a72b491b18"
  license "Apache-2.0"

  depends_on :macos
  depends_on arch: :arm64
  depends_on "python@3.12"

  def install
    venv = virtualenv_create(libexec, "python3.12")
    venv.pip_install "rapid-mlx==#{version}"
    %w[rapid-mlx vllm-mlx].each do |cmd|
      (bin/cmd).write_env_script libexec/"bin"/cmd, PATH: "#{libexec}/bin:${PATH}"
    end
  end

  def caveats
    <<~EOS
      Start serving a model:
        rapid-mlx serve qwen3.5-9b

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
