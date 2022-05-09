defmodule CompileProtoTest do
  use ExUnit.Case

  alias Mix.Tasks.Compile.Proto

  setup do
    # Get Mix output sent to the current process to avoid polluting tests.
    Mix.shell(Mix.Shell.Process)

    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    :ok
  end

  test "use default options" do
    result = Proto.run([])

    assert result == :ok
  end

  test "accepts options" do
    options = [
      paths: ["test"],
      dest: Path.expand("test/output"),
      gen_descriptors: true
    ]

    result = Proto.run(options)
    _ = Proto.clean()

    assert result == :ok
  end

  describe ".do_protoc_args/3" do
    test "destdir" do
      s = %Proto.State{opts: %Proto.Options{}}
      args = Proto.do_protoc_args(s, [], "/destdir")

      assert ["--elixir_out=/destdir"] == args
    end

    test "sources" do
      s = %Proto.State{opts: %Proto.Options{}}
      args = Proto.do_protoc_args(s, ["a.proto", "b.proto"], "/destdir")

      assert ["--elixir_out=/destdir", "a.proto", "b.proto"] == args
    end

    test "sources with different dirname" do
      s = %Proto.State{opts: %Proto.Options{}}
      args = Proto.do_protoc_args(s, ["/dira/a.proto", "/dirb/b.proto"], "/destdir")

      assert ["--elixir_out=/destdir", "/dira/a.proto", "/dirb/b.proto"] ==
               args
    end

    test "additional includes" do
      s = %Proto.State{opts: %Proto.Options{includes: ["/additional"]}}
      args = Proto.do_protoc_args(s, ["/dira/a.proto", "/dirb/b.proto"], "/destdir")

      assert [
               "-I/additional",
               "--elixir_out=/destdir",
               "/dira/a.proto",
               "/dirb/b.proto"
             ] == args
    end

    test "plugins" do
      s = %Proto.State{opts: %Proto.Options{plugins: ["grpc"]}}
      args = Proto.do_protoc_args(s, ["a.proto"], "/destdir")

      assert ["--elixir_out=plugins=grpc:/destdir", "a.proto"] == args
    end

    test "gen_descriptors=true" do
      s = %Proto.State{opts: %Proto.Options{gen_descriptors: true}}
      args = Proto.do_protoc_args(s, ["a.proto"], "/destdir")

      assert ["--elixir_out=gen_descriptors=true:/destdir", "a.proto"] == args
    end

    test "package_prefix=..." do
      s = %Proto.State{opts: %Proto.Options{package_prefix: "prefix"}}
      args = Proto.do_protoc_args(s, ["a.proto"], "/destdir")

      assert ["--elixir_out=package_prefix=prefix:/destdir", "a.proto"] == args
    end

    test "transform_module=module" do
      s = %Proto.State{opts: %Proto.Options{transform_module: "App.Module"}}
      args = Proto.do_protoc_args(s, ["a.proto"], "/destdir")

      assert ["--elixir_out=transform_module=App.Module:/destdir", "a.proto"] == args
    end

    test "one_file_per_module=true" do
      s = %Proto.State{opts: %Proto.Options{one_file_per_module: true}}
      args = Proto.do_protoc_args(s, ["a.proto"], "/destdir")

      assert ["--elixir_out=one_file_per_module=true:/destdir", "a.proto"] == args
    end
  end
end
