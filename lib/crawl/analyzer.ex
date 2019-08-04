defmodule Crawl.Analyzer do
  def address_process(rows) do
    Task.async(fn ->
      Enum.map(rows, fn row ->
        addr = Enum.at(row, 2) |> Poison.decode!() |> Map.get("所在地")
        Regex.scan(~r/.+市/, addr) |> Enum.join
      end)
    end)
  end

  def all_process() do
    # count = Crawl.Data.count
    continues_select(1, 5000, 100000, [])
  end

  def continues_select(offset, limits, max, tasks) do
    if offset < max do
      rows = Crawl.Data.select(offset, limits)
      ref = address_process(rows)
      continues_select(offset+limits, limits, max, [ref | tasks])
    else
      Enum.flat_map(tasks, fn task -> Task.await(task) end)
          |> Enum.reduce(%{}, fn x, acc ->
              Map.update(acc, x, 1, &(&1 + 1))
            end)
    end
  end

end