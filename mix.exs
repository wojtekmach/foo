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
        steps: [:assemble, &build_launcher/1]
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

  defp shell!(cmd) do
    {_, 0} = System.shell(cmd, into: IO.stream())
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
          "-eval",
          "io:format(\"~s\", [erlang:system_info(system_version)]), halt().",
      };
      erl_start(sizeof(args) / sizeof(args[0]), (char **)args);
  }
  """

  EEx.function_from_string(:defp, :launcher, launcher, [:release])
end
