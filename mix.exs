defmodule Foo.MixProject do
  use Mix.Project

  def project do
    [
      app: :foo,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Foo.Application, []}
    ]
  end

  defp deps do
    []
  end

  defp releases do
    [
      foo: [
        # include_erts: false
        targets: [
          "macos-aarch64",
          "macos-x86_64",
          "ios-aarch64",
          "iossimulator-aarch64",
          "iossimulator-x86_64"
        ],
        bootstrap: [
          openssl_version: "3.0.5",
          otp_version: "25.1"
        ],
        steps: [
          :assemble,
          &bootstrap/1,
          &build_launcher/1
        ]
      ]
    ]
  end

  defp build_launcher(release) do
    tmp_dir = Path.join(release.path, "tmp")
    File.mkdir_p!(tmp_dir)
    launcher_cpp_path = Path.join(tmp_dir, "launcher.cpp")
    launcher_bin_path = Path.join([release.path, "bin", "launcher"])
    File.write!(launcher_cpp_path, launcher(release))

    otp_src = "/Users/wojtek/src/otp"
    arch = :erlang.system_info(:system_architecture)

    shell!("""
    clang++ \
        -framework Foundation \
        -ltermcap \
        -L#{otp_src}/erts/emulator/ryu/obj/#{arch}/opt -lryu \
        -L#{otp_src}/erts/emulator/zlib/obj/#{arch}/opt -lz \
        -L#{otp_src}/erts/emulator/pcre/obj/#{arch}/opt -lepcre \
        -L#{otp_src}/bin/#{arch} -lbeam \
        -L#{release.erts_source}/lib/internal -lerts_internal -lethread \
        -o #{launcher_bin_path} #{launcher_cpp_path}
    """)

    File.rm_rf!(tmp_dir)
    release
  end

  defp bootstrap(release) do
    Enum.reduce(release.options[:targets], release, &bootstrap/2)
  end

  defp bootstrap(target, release) do
    release
    |> build_openssl(target)
    |> build_otp(target)
  end

  defp build_openssl(release, target) do
    version = release.options[:bootstrap][:openssl_version]
    source_dir = Path.expand("_build/tmp/openssl-#{version}")
    target_dir = Path.expand("_build/openssl-#{version}-#{target}")

    openssl_target =
      case target do
        "macos-aarch64" -> "darwin64-arm64-cc"
        "macos-x86_64" -> "darwin64-x86_64-cc"
        "ios-aarch64" -> "ios64-xcrun"
        "iossimulator-aarch64" <> _ -> "iossimulator-arm64-xcrun"
        "iossimulator-x86_64" <> _ -> "iossimulator-x86_64-xcrun"
      end

    shell!("scripts/build_openssl.sh #{version} #{source_dir} #{target_dir} #{openssl_target}")
    release
  end

  defp build_otp(release, target) do
    version = release.options[:bootstrap][:otp_version]
    openssl_version = release.options[:bootstrap][:openssl_version]
    source_dir = Path.expand("_build/tmp/otp-#{version}")
    target_dir = Path.expand("_build/otp-#{version}-#{target}")
    openssl_dir = Path.expand("_build/openssl-#{openssl_version}-#{target}")

    shell!("""
    scripts/build_otp.sh \\
      #{version} \\
      #{source_dir} \\
      #{target_dir} \\
      #{target} \\
      #{openssl_dir} \\
      $PWD/scripts/xcomp/#{target}.conf
    """)

    release
  end

  require EEx

  launcher = ~S"""
  #include <stdlib.h>

  extern "C" {
      extern void erl_start(int argc, char **argv);
  }

  int main() {
      setenv("BINDIR", "<%= Path.join([release.path, "erts-#{release.erts_version}", "bin"]) %>", 0);
      const char *args[] = {
          "launcher",
          "--",
          "-root",
          "<%= release.path %>",
          "-bindir",
          "<%= Path.join([release.path, "erts-#{release.erts_version}", "bin"]) %>",
          "-config",
          "<%= Path.join([release.version_path, "sys"]) %>",
          "-boot",
          "<%= Path.join([release.version_path, "start"]) %>",
          "-boot_var",
          "RELEASE_LIB",
          "<%= Path.join([release.path, "lib"]) %>",
          "-noshell",
      };
      erl_start(sizeof(args) / sizeof(args[0]), (char **)args);
  }
  """

  EEx.function_from_string(:defp, :launcher, launcher, [:release])

  defp shell!(cmd, opts \\ []) do
    {_, 0} = System.shell(cmd, [into: IO.stream()] ++ opts)
  end
end
