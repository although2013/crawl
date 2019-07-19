require IEx

defmodule Crawl do
  def main do
    HTTPoison.start
    first_url = "https://suumo.jp/jj/chintai/ichiran/FR301FC001/?ar=030&bs=040&ra=011&cb=0.0&ct=9999999&et=9999999&cn=9999999&mb=0&mt=9999999&shkr1=03&shkr2=03&shkr3=03&shkr4=03&fw2=&ek=064053820&ek=064053840&rn=0640"

    {:ok, pid} = Crawl.Data.run
    process(first_url, pid)
  end

  def get_page(reason, 0) do
    {:error, reason}
  end

  def get_page(url, retry) do
    IO.puts("retry #{retry}, #{Time.utc_now} #{url}")
    case HTTPoison.get(url) do
      {:ok, response} -> {:ok, response}
      {:error, _} ->
        wait = :math.pow(2, (8-2*retry))
        :timer.sleep(round(1000*wait))
        get_page(url, (retry-1))
    end
  end

  def process(url, pid) do
    unless exist(pid, url) do
      {:ok, response} = get_page(url, 3)
      save(pid, url, response.body)

      links = response.body
        |> Floki.find("body a")
        |> Floki.attribute("href")
        |> Enum.filter(fn link ->
                  Regex.match?(~r/(bc_\d+\/|\/jj\/|jnc_\d+\/)/, link) &&
                  Regex.match?(~r/\/chintai\//, link)
                end)
        |> Enum.map(fn link ->
            URI.merge("https://suumo.jp", link)
                |> URI.to_string
                |> String.trim
        end)
        |> Enum.uniq()
        |> Enum.filter(fn link ->
                  String.starts_with?(link, "https") &&
                  !Regex.match?(~r/(void\(0\)|\/showLogin\/|\/kankyo\/|\/tenpo\/|\.css\/|favicon.ico)/, link)
                end)

      Enum.each(links, fn link ->
        process(link, pid)
      end)

      # stream = Task.async_stream(
      #                 links,
      #                 Crawl,
      #                 :process,
      #                 [pid],
      #                 max_concurrency: 1,
      #                 ordered: false)
      # Stream.run(stream)
    end
  end

  def save(pid, url, body) do
    try do
      send(pid, {self(), :create, %{url: url, body: body}})
    rescue
      e -> IO.puts(inspect(e))
    end
  end

  def exist(pid, url) do
    send(pid, {self(), :exist, url})
    receive do
      value -> 
        IO.puts("#{inspect(value)}, #{url}")
        value
    end
  end

end

# Crawl.establish
# listen_pid = spawn(Crawl, :listen, [sql_pid])
# Crawl.main(listen_pid)
