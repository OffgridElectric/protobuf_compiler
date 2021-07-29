defmodule CompileProtoTest do
  use ExUnit.Case

  alias Mix.Tasks.Compile.Proto

  setup do
    # Get Mix output sent to the current process to avoid polluting tests.
    Mix.shell(Mix.Shell.Process)

    on_exit fn -> Mix.shell(Mix.Shell.IO) end

    :ok
  end

  test "use default options" do
    result = Proto.run([])

    assert result == :ok
  end

  test "accepts options" do
    options = [
      sources: ["test/test.proto"],
      target: Path.expand("test/output"),
      rpc: false,
      gen_descriptors: true
    ]

    result = Proto.run(options)
    _ = Proto.clean(options)

    # To test shell messages...
    # assert_receive {:mix_shell, :info, [info]}

    assert result == :ok
  end
end
