require IEx

defmodule Crawl do
  def start_link do
    HTTPoison.start
    Crawl.Data.start_link
    Crawl.Queue.start_link

    first_url = "https://suumo.jp/jj/chintai/ichiran/FR301FC001/?ar=030&bs=040&ra=011&cb=0.0&ct=9999999&et=9999999&cn=9999999&mb=0&mt=9999999&shkr1=03&shkr2=03&shkr3=03&shkr4=03&fw2=&ek=064053820&ek=064053840&rn=0640"
    

    Task.start_link(fn -> process(:one, first_url) end)
  end

  def get_page(_, 0) do
    {:ok, %{body: ""}}
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

  def process(:one, link) do
    {:ok, response} = get_page(link, 3)

    bc_links(response.body) |> Crawl.Queue.enqueue
    jj_links(response.body) |> Crawl.Queue.enqueue
    :timer.sleep(200)

    link = Crawl.Queue.dequeue()
    process(:multi, link)
  end

  def process(:multi, link) do
    exist = exist?(link)
    IO.puts("exist: #{exist}, #{length(Crawl.Queue.queue)}, #{link}")

    unless exist do
      {:ok, response} = get_page(link, 3)
      IO.puts("Get Page #{Time.utc_now}")
      Task.async(fn -> save(link, response.body) end)
      IO.puts("Async called save #{Time.utc_now}")
      # if length(Crawl.Queue.queue) < 300 do
        bc_links(response.body) |> Crawl.Queue.enqueue
        jj_links(response.body) |> Crawl.Queue.enqueue
      IO.puts("Put links to queue #{Time.utc_now}")
      # end
    end

    link = Crawl.Queue.dequeue()
    process(:multi, link)
  end

  def bc_links(body) do
    Crawl.Extract.bc_ids(body)
        |> Enum.map(fn id ->
          "https://suumo.jp/chintai/bc_#{id}/"
        end)
  end

  def jj_links(body) do
    Floki.find(body, "body a")
        |> Floki.attribute("href")
        |> Enum.filter(fn link ->
                  Regex.match?(~r/\/jj\/.+?page/, link) &&
                  Regex.match?(~r/\/chintai\//, link)
                end)
        |> Enum.map(fn link ->
            URI.merge("https://suumo.jp", link)
                |> URI.to_string
                |> String.trim
        end)
        |> Enum.uniq()
  end

  def save(url, body) do
    if Regex.match?(~r/\/bc_\d+\//, url) && String.length(body) > 1 do
      json = Crawl.Extract.to_json(body) |> Poison.encode!
      Crawl.Data.create(%{url: url, body: json})
    end
  end

  def exist?(url) do
    Crawl.Data.exist?(url)
  end

end

# Crawl.establish
# listen_pid = spawn(Crawl, :listen, [sql_pid])
# Crawl.main(listen_pid)
