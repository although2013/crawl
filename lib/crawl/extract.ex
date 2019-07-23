defmodule Crawl.Extract do
  def start_link() do
    
  end

  def run do
    str = File.read("lib/crawl/sample.html")
    house = Floki.find(str, ".table_gaiyou tr") |>
        Floki.find("th, td") |>
        Floki.filter_out(".blank_td") |>
        Enum.map(fn ele ->
              Floki.text(ele, sep: ", ") |> String.trim
            end)  |>
        Enum.chunk_every(2) |>
        Map.new(fn [k, v] -> {k, v} end) |>
        Map.delete("携帯用QRコード")
  end

end
