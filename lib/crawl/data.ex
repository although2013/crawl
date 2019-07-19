defmodule Crawl.Data do
  def run do
    :application.ensure_all_started(:postgrex)
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", username: "postgres", password: "", database: "gehao")
    
    Task.start_link(fn -> loop(pid) end)
  end

  def exist?(url) do
    "SELECT id FROM suumo WHERE url='#{url}'"
  end

  def create(map) do
    keys = Map.keys(map)
    values = Enum.map(keys, fn key ->
      "'#{String.replace(map[key], "'", "''")}'"
    end) |> Enum.join(", ")

    "INSERT INTO suumo (#{Enum.join(keys, ", ")}, created_at) VALUES (#{values}, '#{DateTime.utc_now()}') ON CONFLICT (url) DO NOTHING;"
  end

  def loop(pid) do
    receive do
      {caller, :create, map} ->
        Postgrex.query!(pid, create(map), [])
      {caller, :exist, url} ->
        %{num_rows: num_rows} = Postgrex.query!(pid, exist?(url), [])
        result = cond do
          num_rows > 0 -> true
          true -> false
        end

        send(caller, result)
    end
    loop(pid)
  end


  def filter_urls do
  end
end