defmodule Crawl.Data do
  use Agent

  def start_link do
    :application.ensure_all_started(:postgrex)
    pwd = System.get_env("sql_password", "")
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", username: "postgres", password: pwd, database: "gehao")
    Agent.start_link(fn -> pid end, name: __MODULE__)
  end

  def pid do
    Agent.get(__MODULE__, & &1)
  end

  def exist?(url) do
    sql = "SELECT id FROM suumo WHERE url='#{url}'"
    %{num_rows: num_rows} = Postgrex.query!(pid(), sql, [])
    cond do
      num_rows > 0 -> true
      true -> false
    end
  end

  def last do
    sql = "SELECT id, url, body FROM suumo ORDER BY id DESC LIMIT 1"
    Postgrex.query!(pid(), sql, [])
  end

  def find(id) do
    sql = "SELECT id, url, body FROM suumo WHERE id=#{id} LIMIT 1"
    %{rows: [[id, url, body]]} = Postgrex.query!(pid(), sql, [])
    %{id: id, url: url, body: body}
  end

  def create(map) do
    keys = Map.keys(map)
    values = Enum.map(keys, fn key ->
      "'#{String.replace(map[key], "'", "''")}'"
    end) |> Enum.join(", ")

    sql = "INSERT INTO suumo (#{Enum.join(keys, ", ")}, created_at) VALUES (#{values}, '#{DateTime.utc_now()}') ON CONFLICT (url) DO NOTHING;"
    Postgrex.query!(pid(), sql, [])
  end

  # def loop(pid) do
  #   receive do
  #     {caller, :create, map} ->
  #       Postgrex.query!(pid, create(map), [])
  #     {caller, :exist, url} ->
  #       %{num_rows: num_rows} = Postgrex.query!(pid, exist?(url), [])
  #       result = cond do
  #         num_rows > 0 -> true
  #         true -> false
  #       end

  #       send(caller, result)
  #   end
  #   loop(pid)
  # end


  # def filter_urls do
  # end
end



# -- Drop table

# -- DROP TABLE public.suumo;

# CREATE TABLE public.suumo (
#   id bigserial NOT NULL,
#   url varchar NOT NULL,
#   body text NULL,
#   created_at timestamp NULL,
#   CONSTRAINT suumo_pkey PRIMARY KEY (id)
# );
# CREATE UNIQUE INDEX suumo_url_idx ON public.suumo USING btree (url);
# CREATE UNIQUE INDEX suumo_id_idx ON public.suumo (id);