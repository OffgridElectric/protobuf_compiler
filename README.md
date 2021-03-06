# ProtobufCompiler

Provides a mix task `mix compile.proto` for easier integration of `elixir-protobuf/protobuf`. 

The task will:
1. Fetch options, gather `.proto` sources
2. Check the `protoc` binary exists and is executable
3. Check the `protoc-gen-elixir` plugin is available and executable
4. Ensure the target directory exists
5. Check if any of the sources are "stale"
6. Compile each file replacing the basename `.proto` with `.pb.ex`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `protobuf_compiler` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:protobuf, "~> 0.9.0"},
    {:protobuf_compiler, "~> 0.2.0"}
  ]
end
```

Protoc options can be set in the project:

```elixir
defmodule MyProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_project,
      ...
      protoc_opts: [
        paths: ["lib"],
        dest: "lib/protobuf/",
        gen_descriptors: true 
      ]
    ]
  end
```

## Module prefix

```elixir
defmodule MyProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_project,
      ...
      protoc_opts: [
        ...
        package_prefix: "Custom"
      ]
    ]
  end
```

Your modules will now be generated with a namespace:

```elixir
defmodule Custom.Example do
  @moduledoc false
  use Protobuf, syntax: :proto2
  @type t :: %__MODULE__{}

  defstruct []
end
```

## Plugin Version

There is a strict dependency between `protobuf` library version and plugin used
for code generation.

This compiler tries to install the best suited plugin version:
* if `protobuf` is a dep in your application, plugin is built from sources; else
* if `protoc-gen-elixir` is found in your `PATH`, it will be used (mostly
  intended to developers); else
* compiler uses `mix escript.install hex` to install prebuilt version of the
  plugin.

When not built from source, you can force a specific version of the plugin with
the config:

```elixir
config :protobuf_compiler, plugin_version: "0.8.0"
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/protobuf_compiler](https://hexdocs.pm/protobuf_compiler).

