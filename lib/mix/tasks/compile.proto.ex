defmodule Mix.Tasks.Compile.Proto do
  @moduledoc """
  Compiles `.proto` files into `.pb.ex`.

  ## Usage

  This compiler can be added to the list of compilers for a project:

  ```
  def project do
    [
      ...
      compilers: [ :proto | Mix.compilers() ],
      protoc_opts: [
        paths: ["proto"],
        sources: ["lib/my.proto"],
        transform_module: ...
      ]
      ...
    ]
  end
  ```

  It can also be called as a mix task:

  ```
  mix compile.proto
  ```

  ## Compiler options

    * `:paths` - `[String.t()]` - directories to look for sources (default:
      `elixirc_paths`)
    * `:sources` - [String.t()] - additional `.proto` files to compile
    * `:dest` - `String.t()` - directory where to put generated files (default:
      `hd(elixirc_paths)`)
    * `:includes` - `[String.t()]` - directories to look for imports
    * `:plugins` - `[String.t()]` - list of plugin name, eg `["grpc"]`
    * `:gen_descriptors` - `boolean` - if true, generates descriptors (default:
      `false`)
    * `:package_prefix` - `String.t()`- package prefix
    * `:transform_module` - `atom() | String.t()`- transformation module (see
      `Protobuf.TransformModule` behaviour)
    * `:one_file_per_module` - `boolean` - generates one file per module
  """

  defmodule Options do
    @moduledoc """
    Defines a structure for compiler options
    """
    defstruct paths: [],
              sources: [],
              dest: nil,
              includes: [],
              plugins: [],
              gen_descriptors: false,
              package_prefix: nil,
              transform_module: nil,
              one_file_per_module: false
  end

  defmodule State do
    @moduledoc false
    defstruct errors: [],
              env: [],
              sources: [],
              opts: nil,
              manifest: nil,
              force: false,
              version: nil
  end

  defmodule Manifest do
    @moduledoc false
    defstruct sources: [], targets: []
  end

  @shortdoc "Compiles .proto file into elixir files"

  @task_name "compile.proto"

  @plugin "protoc-gen-elixir"
  @manifest "compile.proto.manifest"
  @manifest_vsn 2

  use Mix.Task.Compiler

  @doc false
  @impl true
  def run(_args) do
    Application.ensure_loaded(:protobuf_compiler)

    %State{opts: get_options(), manifest: parse_manifest(manifest())}
    |> set_force()
    |> check_exec("protoc")
    |> ensure_plugin()
    |> get_sources()
    |> do_compile()
    |> case do
      %State{errors: []} ->
        :ok

      %State{errors: errors} ->
        Enum.each(errors, &error/1)
        {:error, errors}
    end
  end

  @doc false
  @impl true
  def manifests, do: [manifest()]
  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)

  @doc false
  @impl true
  def clean do
    %State{opts: get_options(), manifest: parse_manifest(manifest())}
    |> do_clean()
  end

  ###
  ### Priv
  ###
  defp do_clean(%State{manifest: %Manifest{targets: targets}}) do
    targets
    |> Enum.each(fn target ->
      _ = info(target, "compile.clean")
      File.rm(target)
    end)
  end

  defp do_compile(%State{errors: [], sources: srcs, opts: opts} = s) do
    timestamp = System.os_time(:second)
    :ok = File.mkdir_p(opts.dest)

    if s.force do
      do_clean(s)
    end

    if Mix.Utils.stale?(srcs, targets(srcs, s)) do
      tmpdir = Path.join(Mix.Project.manifest_path(), "#{:erlang.phash2(make_ref())}")
      do_protoc(s, srcs, tmpdir)
    else
      s
    end
    |> write_manifest(timestamp)
  end

  defp do_compile(s), do: s

  defp get_sources(s) do
    sources =
      Enum.flat_map(s.opts.paths, fn srcdir ->
        Path.wildcard(Path.join(srcdir, "**/*.proto"))
      end)
      |> Kernel.++(s.opts.sources)
      |> MapSet.new()
      |> MapSet.to_list()

    %{s | sources: sources}
  end

  defp get_options do
    project = Mix.Project.config()
    opts = Keyword.get(project, :protoc_opts, [])

    dest =
      Keyword.get_lazy(opts, :dest, fn ->
        hd(Keyword.get(project, :elixirc_paths, ["lib"]))
      end)

    struct!(
      Options,
      Keyword.merge(
        [paths: opts[:paths] || project[:elixirc_paths], dest: dest],
        Keyword.take(opts, [
          :sources,
          :includes,
          :plugins,
          :gen_descriptors,
          :package_prefix,
          :transform_module,
          :one_file_per_module
        ])
      )
    )
  end

  defp set_force(s) do
    force = Mix.Utils.stale?([Mix.Project.config_mtime()], [manifest()])
    %{s | force: force}
  end

  defp do_protoc(s, sources, tmpdir) do
    _ = info(Enum.join(sources, " "))

    :ok = File.mkdir_p!(tmpdir)
    args = do_protoc_args(s, sources, tmpdir)
    cmd = "protoc " <> Enum.join(args, " ")

    if Mix.shell().cmd(cmd, env: s.env) == 0 do
      targets =
        tmpdir
        |> Path.join("**/*.pb.ex")
        |> Path.wildcard()
        |> Enum.map(&Path.relative_to(&1, tmpdir))

      s
      |> move_to_destdir(tmpdir, targets)
      |> update_manifest(sources, targets)
    else
      %{s | errors: s.errors ++ ["Compilation failed"]}
    end
  after
    File.rm_rf(tmpdir)
  end

  # For testing purpose
  @doc false
  def do_protoc_args(s, sources, tmpdir) do
    elixir_out_opts =
      s.opts
      |> Map.from_struct()
      |> Enum.reduce([], &elixir_out_opts/2)
      |> case do
        [] ->
          s.opts.target

        out_opts ->
          Enum.join(out_opts, ",") <> ":" <> tmpdir
      end

    includes =
      sources
      |> Enum.reduce(MapSet.new(), &MapSet.put(&2, Path.dirname(&1)))
      |> MapSet.to_list()
      |> Kernel.++(s.opts.includes)

    []
    |> Kernel.++(Enum.map(includes, &"-I #{&1}"))
    |> Kernel.++(["--elixir_out=" <> elixir_out_opts])
    |> Kernel.++(sources)
  end

  defp move_to_destdir(s, tmpdir, targets) do
    targets
    |> Enum.each(fn target ->
      :ok = move(Path.join(tmpdir, target), Path.join(s.opts.dest, target))
    end)

    s
  end

  defp update_manifest(s, sources, targets) do
    manifest = %Manifest{sources: sources, targets: targets}
    %{s | manifest: manifest}
  end

  defp targets(_sources, %{manifest: %{targets: targets}}) do
    targets
  end

  defp elixir_out_opts({:plugins, plugins}, acc),
    do: ["plugins=#{Enum.join(plugins, "+")}" | acc]

  defp elixir_out_opts({:gen_descriptors, true}, acc),
    do: ["gen_descriptors=true" | acc]

  defp elixir_out_opts({:package_prefix, nil}, acc), do: acc

  defp elixir_out_opts({:package_prefix, prefix}, acc),
    do: ["package_prefix=#{prefix}" | acc]

  defp elixir_out_opts({:transform_module, nil}, acc), do: acc

  defp elixir_out_opts({:transform_module, mod}, acc),
    do: ["transform_module=#{Module.concat([mod])}" | acc]

  defp elixir_out_opts({:one_file_per_module, true}, acc),
    do: ["one_file_per_module=true" | acc]

  defp elixir_out_opts(_, acc), do: acc

  defp info(msg, task_name \\ @task_name) do
    Mix.shell().info([:bright, task_name, :normal, " ", msg])
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

  defp ensure_plugin(s) do
    case System.find_executable(@plugin) do
      nil ->
        install_plugin(s)

      path ->
        req = version_req()

        s = get_plugin_version(s, path)

        if match_plugin_version?(s, req) do
          s
        else
          Mix.shell().info("Found plugin `#{@plugin}=#{s.version}` (config: #{req})")
          s
        end
    end
  end

  defp install_plugin(s) do
    escriptsdir = Mix.path_for(:escripts)
    path = "PATH" |> System.get_env() |> String.split(":")
    env = [{"PATH", Enum.join([escriptsdir | path], ":")}]
    version = version_req()

    :ok = Mix.Task.run("escript.install hex protobuf #{version}")
    Mix.shell().info("[protoc] #{Path.join(escriptsdir, @plugin)} (= #{version})")

    %{s | env: env, version: version}
  end

  defp get_plugin_version(s, path) do
    case System.cmd(path, ["--version"]) do
      {out, 0} -> %{s | version: String.trim(out)}
      {_, _} -> s
    end
  end

  defp match_plugin_version?(%{version: nil}, _), do: false

  defp match_plugin_version?(%{version: version}, req) do
    Version.match?(version, "~> #{req}")
  rescue
    _ -> false
  end

  defp move(from, to) do
    with :ok <- File.mkdir_p(Path.dirname(to)),
         :ok <- File.rename(from, to) do
      :ok
    else
      {:error, :exdev} ->
        # `from` and `to` are on different filesystems, can not just rename
        xfs_move(from, to)
    end
  end

  defp xfs_move(from, to) do
    with :ok <- File.cp(from, to),
         :ok <- File.rm(from) do
      :ok
    end
  end

  defp write_manifest(s, timestamp) do
    case s.manifest do
      %Manifest{targets: []} ->
        File.rm(manifest())

      manifest ->
        path = manifest()
        File.mkdir_p!(Path.dirname(path))

        term = {@manifest_vsn, manifest}
        manifest_data = :erlang.term_to_binary(term, [:compressed])
        File.write!(path, manifest_data)
        File.touch!(path, timestamp)
    end

    s
  end

  defp parse_manifest(path) do
    try do
      path |> File.read!() |> :erlang.binary_to_term()
    rescue
      _ ->
        %Manifest{}
    else
      {1, data} ->
        targets =
          data
          |> Enum.reduce(MapSet.new(), fn {_source, targets}, acc ->
            Enum.reduce(targets, acc, &MapSet.put(&2, &1))
          end)
          |> MapSet.to_list()

        %Manifest{sources: Map.keys(data), targets: targets}

      {@manifest_vsn, %Manifest{} = data} ->
        data
    end
  end

  defp version_req, do: Application.fetch_env!(:protobuf_compiler, :plugin_version)
end
