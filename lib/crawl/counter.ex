defmodule Crawl.Counter do
  use Agent

  def start_link do
    Agent.start_link(fn -> 0 end, name: Counter)
  end

  def value do
    Agent.get(Counter, & &1)
  end

  def add(value) do
    Agent.update(Counter, &(&1+value))
  end

  def minus(value) do
    Agent.update(Counter, &(&1-value))
  end
end