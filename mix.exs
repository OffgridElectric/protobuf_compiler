defmodule CompileProto.MixProject do
  use Mix.Project

  @version "./VERSION" |> File.read!() |> String.trim()

  def project do
    [
      app: :compile_proto,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", runtime: false},
      {:protobuf, github: "OffgridElectric/protobuf", override: true}
    ]
  end
end
