defmodule Foo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    dbg(:erlang.system_info(:system_architecture))
    System.halt()
    children = []
    opts = [strategy: :one_for_one, name: Foo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
