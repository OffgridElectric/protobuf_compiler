# CompileProto

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
by adding `compile_proto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:protobuf_compiler, "~> 0.1.0"}
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
        target: "lib/protobuf/",
        gen_descriptors: true 
      ]
    ]
  end
```

## Module prefix

By default the generated elixir modules have no namespace. For example:

```proto
syntax = "proto2";

message Example {}
```

will be generated as:

```elixir
defmodule Example do
  @moduledoc false
  use Protobuf, syntax: :proto2
end
```

In order to have your modules generated with a namespace, the proto file must be updated:

```proto
syntax = "proto2";

import "elixirpb.proto";
option (elixirpb.file).module_prefix = "Custom";

message Example {}
```

will now be generated as:

```elixir
defmodule Custom.Example do
  @moduledoc false
  use Protobuf, syntax: :proto2
  @type t :: %__MODULE__{}

  defstruct []
end
```

## Installing the elixir protoc plugin

To install the `protoc-gen-elixir` from Hex you can type:

```
mix escript.install hex protobuf
```

However you may experience the following error when compiling `.proto` files with namespace option:

```
** (SyntaxError) nofile:2:1: unexpected token: "" (column 1, code point U+001C)
    (elixir 1.12.2) lib/code.ex:978: Code.format_string!/2
    (protobuf 0.7.1) lib/protobuf/protoc/generator.ex:64: Protobuf.Protoc.Generator.format_code/1
    (protobuf 0.7.1) lib/protobuf/protoc/generator.ex:11: Protobuf.Protoc.Generator.generate/2
    (elixir 1.12.2) lib/enum.ex:1582: Enum."-map/2-lists^map/1-0-"/2
    (protobuf 0.7.1) lib/protobuf/protoc/cli.ex:42: Protobuf.Protoc.CLI.main/1
    (elixir 1.12.2) lib/kernel/cli.ex:124: anonymous fn/3 in Kernel.CLI.exec_fun/2
--elixir_out: protoc-gen-elixir: Plugin failed with status code 1.
```

This can be resolved by compiling `protoc-gen-elixir` from source: 
```
git clone git@github.com:elixir-protobuf/protobuf.git
mix deps.get
MIX_ENV=prod make protoc-gen-elixir
```
And then ensure the `protoc-gen-elixir` binary is available on your PATH.


## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/compile_proto](https://hexdocs.pm/compile_proto).

