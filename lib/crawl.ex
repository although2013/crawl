require IEx

defmodule Crawl do
  def main do
    HTTPoison.start
    first_url = "https://suumo.jp/jj/chintai/ichiran/FR301FC001/?ar=030&bs=040&ra=013&ae=06401&cb=0.0&ct=9999999&et=9999999&cn=9999999&mb=0&mt=9999999&shkr1=03&shkr2=03&shkr3=03&shkr4=03&fw2=&rn=0640"
    {:ok, pid} = Crawl.Data.run
    process(pid, first_url)
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

  def process(pid, url) do
    IO.puts(inspect(url))

    unless exist(pid, url) do
      {:ok, response} = get_page(url, 3)
      save(pid, url, response.body)

      links = response.body
        |> Floki.find("body a")
        |> Floki.attribute("href")
        |> Enum.filter(&Regex.match?(~r/chintai\//, &1))
        |> Enum.uniq()

      Enum.each(links, fn link ->
        fulllink = URI.merge("https://suumo.jp", link)
                    |> URI.to_string
                    |> String.trim
        if String.starts_with?(fulllink, "https") do
          process(pid, fulllink)
        end
      end)
    end
  end

  def save(pid, url, body) do
    send(pid, {self(), :create, %{url: url, body: body}})
  end

  def exist(pid, url) do
    send(pid, {self(), :exist, url})
    receive do
      value -> 
        IO.puts("#{value}, #{url}")
        value
    end
  end

end

# Crawl.establish
# listen_pid = spawn(Crawl, :listen, [sql_pid])
# Crawl.main(listen_pid)
