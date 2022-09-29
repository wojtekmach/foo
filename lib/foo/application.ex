defmodule Foo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    dbg("hello from Elixir!")
    dbg(System.version())
    children = []
    opts = [strategy: :one_for_one, name: Foo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
