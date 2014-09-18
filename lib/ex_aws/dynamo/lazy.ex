defmodule ExAws.Dynamo.Lazy do
  @moduledoc """
  Dynamo has a few functions that require paging.
  These functions operate just like those in ExAws.Dynamo,
  Except that they return streams instead of lists that can be iterated through
  and will automatically retrieve additional pages as necessary.
  """

  def scan(table, opts \\ %{}) do
    request_fun = fn(fun_opts) ->
      ExAws.Dynamo.scan(table, Map.merge(opts, fun_opts))
    end

    ExAws.Dynamo.scan(table, opts)
      |> do_scan(request_fun)
  end

  def do_scan({:error, results}, _), do: {:error, results}
  def do_scan({:ok, results}, request_fun) do
    {items, meta} = Map.pop(results, "Items")
    stream = build_scan_stream({:ok, results}, request_fun)

    {:ok, Map.put(meta, "Items", stream)}
  end

  def build_scan_stream(initial, request_fun) do
    Stream.resource(
      fn -> initial end,
      fn
        :quit             -> {:halt, nil}

        {:error, items} -> {[{:error, items}], :quit}

        {:ok, %{"Items" => items, "LastEvaluatedKey" => key}} ->
          {items, request_fun.(%{ExclusiveStartKey: key})}

        {:ok, %{"Items" => items}} ->
          {items, :quit}
      end,
      &(&1)
    )
  end
end
