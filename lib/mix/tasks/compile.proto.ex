defmodule Mix.Tasks.Compile.Proto do
  @moduledoc """
  Compiles protobuf types into elixir files

  ## Configuration

    * `:protoc_opts` - compilation options for the compiler. See below for options.

    Options:

    * `:sources` - list(String) - source files to compile
    * `:target` - String - directory to put generated files. Default to `"lib"`
    * `:includes` - directories to look for imported definitions, in
      addition to `:src`. Default to `[]`
    * `:rpc` - Boolean - uses grpc plugin
    * `gen_descriptors` - generates descriptors
  """

  defmodule Options do
    @moduledoc """
    Defines a structure for compiler options
    """

    defstruct sources: [],
              target: "./lib",
              includes: [],
              rpc: false,
              gen_descriptors: false
  end

  @shortdoc "Compiles .proto file into elixir files"

  @task_name "compile.proto"

  @includes Path.expand("../../../src", __DIR__)

  use Mix.Task.Compiler

  @doc false
  def run(args) do
    opts = get_options(args)

    s = %{errors: []}

    opts.sources
    |> Enum.reduce(s, &check_src(&2, &1, "proto"))
    |> check_exec("protoc")
    |> check_exec("protoc-gen-elixir")
    |> do_compile(opts.sources, opts)
    |> case do
      %{errors: []} ->
        :ok

      %{errors: errors} ->
        Enum.each(errors, &error/1)
        {:error, errors}
    end
  end

  @doc false
  def clean(args) do
    opts = get_options(args)

    opts.target
    |> Path.join("*.pb.ex")
    |> Path.wildcard()
    |> case do
      [] ->
        :ok

      paths ->
        info("cleanup " <> Enum.join(paths, " "))
        Enum.each(paths, &File.rm/1)
    end
  end

  ###
  ### Priv
  ###
  defp get_options(args) do
    project = Mix.Project.config()
    opts = struct!(Options, project[:protoc_opts] || args)
    %{opts | includes: [@includes | List.wrap(opts.includes)]}
  end

  defp do_compile(%{errors: []} = s, srcs, opts) do
    :ok = File.mkdir_p(opts.target)

    targets = Enum.reduce(srcs, [], &(targets(&1, opts) ++ &2))

    if Mix.Utils.stale?(srcs, targets) do
      srcs
      |> Enum.reduce(s, &do_protoc(&2, &1, opts))
    else
      s
    end
  end

  defp do_compile(s, _srcs, _opts), do: s

  defp do_protoc(s, src, opts) do
    _ = info(src)

    elixir_out_opts =
      opts
      |> Map.from_struct()
      |> Enum.reduce([], &elixir_out_opts/2)
      |> case do
        [] ->
          opts.target

        out_opts ->
          Enum.join(out_opts, ",") <> ":" <> opts.target
      end

    includes = [Path.dirname(src) | opts.includes]

    args =
      []
      |> Kernel.++(Enum.map(includes, &"-I #{&1}"))
      |> Kernel.++(["--elixir_out=" <> elixir_out_opts])
      |> Kernel.++([src])

    cmd = "protoc " <> Enum.join(args, " ")

    if Mix.shell().cmd(cmd) == 0 do
      s
    else
      %{s | errors: s.errors ++ ["Compilation failed"]}
    end
  end

  defp elixir_out_opts({:rpc, true}, acc), do: ["plugins=grpc" | acc]

  defp elixir_out_opts({:gen_descriptors, true}, acc), do: ["gen_descriptors=true" | acc]

  defp elixir_out_opts(_, acc), do: acc

  defp targets(src, opts) do
    [Path.join([opts.target, Path.basename(src, ".proto") <> ".pb.ex"])]
  end

  defp info(msg) do
    Mix.shell().info([:bright, @task_name, :normal, " ", msg])
  end

  defp error(msg) do
    Mix.shell().info([:bright, @task_name, :normal, " ", :red, msg])
  end

  defp check_exec(s, exec) do
    if System.find_executable(exec) do
      s
    else
      %{s | errors: ["Missing executable: #{exec}" | s.errors]}
    end
  end

  defp check_src(s, src, ext) do
    if File.exists?(src) do
      check_ext(s, src, ext)
    else
      %{s | errors: ["Missing file: #{src}" | s.errors]}
    end
  end

  defp check_ext(s, src, ext) do
    if String.ends_with?(src, ".#{ext}") do
      s
    else
      %{s | errors: ["Source file #{src} doesn't match '*.#{ext}'" | s.errors]}
    end
  end
end
