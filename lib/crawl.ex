require IEx

defmodule Crawl do
  def start_link do
    HTTPoison.start
    Crawl.Data.start_link
    Crawl.Counter.start_link
    Crawl.Queue.start_link

    first_url = "https://suumo.jp/jj/chintai/ichiran/FR301FC001/?ar=030&bs=040&ta=11&sc=11101&sc=11102&sc=11103&sc=11104&sc=11105&sc=11106&sc=11107&sc=11108&sc=11109&sc=11110&sc=11201&sc=11202&sc=11203&sc=11208&sc=11219&sc=11223&sc=11224&sc=11237&cb=0.0&ct=9999999&et=9999999&cn=9999999&mb=0&mt=9999999&shkr1=03&shkr2=03&shkr3=03&shkr4=03&fw2="

    Task.start_link(fn -> uniq_queue() end)
    Task.start_link(fn -> process_first(first_url) end)
  end

  def uniq_queue do
    :timer.sleep(1500)
    IO.puts("--queue uniq--")
    Crawl.Queue.queue |> Enum.uniq |> Crawl.Queue.update
    Crawl.Queue.queue |> length |> Crawl.Counter.assign
    uniq_queue()
  end

  def get_page(_, 0) do
    {:ok, %{body: ""}}
  end

  def get_page(link, retry) do
    case HTTPoison.get(link) do
      {:ok, response} -> {:ok, response}
      {:error, _} ->
        wait = :math.pow(2, (8-2*retry))
        :timer.sleep(round(1000*wait))
        get_page(link, (retry-1))
    end
  end

  def process_first(link) do
    {:ok, response} = get_page(link, 3)
    bc_links(response.body) |> Crawl.Queue.enqueue
    jj_links(response.body) |> Crawl.Queue.enqueue
    save(link, response.body)

    link = Crawl.Queue.dequeue()
    process(link)
  end

  def process(link) do
    unless exist?(link) do
      before = Time.utc_now
      IO.puts("#{before}, #{Crawl.Counter.value} #{link}")
      {:ok, response} = get_page(link, 3)
      time_diff = Time.diff(Time.utc_now, before, :millisecond) / 1000
      IO.puts("#{time_diff}s #{link}")

      Task.async(fn ->
        save(link, response.body)
        bc_links(response.body) |> Crawl.Queue.enqueue
        jj_links(response.body) |> Crawl.Queue.enqueue
      end)
    end

    link = Crawl.Queue.dequeue()
    process(link)
  end

  def bc_links(body) do
    Crawl.Extract.bc_ids(body)
        |> Enum.map(fn id ->
            "https://suumo.jp/chintai/bc_#{id}/"
          end)
        |> Enum.uniq()
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
    IO.puts("save #{url}")
    json = if Regex.match?(~r/\/bc_\d+\//, url) && String.length(body) > 1 do
             Crawl.Extract.to_json(body) |> Poison.encode!
           else
             ""
           end
    Crawl.Data.create(%{url: url, body: json})
  end

  def exist?(url) do
    Crawl.Data.exist?(url)
  end

end

# Crawl.establish
# listen_pid = spawn(Crawl, :listen, [sql_pid])
# Crawl.main(listen_pid)
