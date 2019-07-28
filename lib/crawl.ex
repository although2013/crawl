require IEx

defmodule Crawl do
  def start_link do
    HTTPoison.start
    Crawl.Data.start_link
    Crawl.Counter.start_link
    Crawl.Queue.start_link

    first_url = "https://suumo.jp/jj/chintai/ichiran/FR301FC001/?ar=030&bs=040&ra=013&ae=01201&ae=01601&cb=0.0&ct=9999999&et=9999999&cn=9999999&mb=0&mt=9999999&shkr1=03&shkr2=03&shkr3=03&shkr4=03&fw2=&rn=0005&rn=0125&rn=0160&rn=0500&rn=0185&rn=0190&rn=0120&rn=0305&rn=0325&rn=0330&rn=0335&rn=0340&rn=0395&rn=0405&rn=0430&rn=0573&rn=0580&rn=0600&rn=0010&rn=0015&rn=0020&rn=0025&rn=0030&rn=0040&rn=0045&rn=0050&rn=0043&rn=0035&rn=0350&rn=0370&rn=0355&rn=0365&rn=0320&rn=0310&rn=0315&rn=0345&rn=0375&rn=0385&rn=0440&rn=0445&rn=0450&rn=0220&rn=0230&rn=0200&rn=0205&rn=0210&rn=0215&rn=0235&rn=0055&rn=0060&rn=0065&rn=0070&rn=0085&rn=0765&rn=0265&rn=0270&rn=0275&rn=0280&rn=0285&rn=0290&rn=0295&rn=0540&rn=0550&rn=0555&rn=0095&rn=0100&rn=0240&rn=0250&rn=0300&rn=0090&rn=0560&rn=0080&rn=0075&rn=0640&rn=0760&rn=7580&rn=7585&rn=0155&rn=0415&rn=0420&rn=0435&rn=0563"

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
    unless exist?(link) do
      {:ok, response} = get_page(link, 3)
      bc_links(response.body) |> Crawl.Queue.enqueue
      jj_links(response.body) |> Crawl.Queue.enqueue
      save(link, response.body)
    end

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
