defmodule Crawl.Queue do
  use GenServer

  ### GenServer API

  @doc """
  GenServer.init/1 callback
  """
  def init(state), do: {:ok, state}

  @doc """
  GenServer.handle_call/3 callback
  """
  def handle_call(:dequeue, _from, [value | state]) do
    Crawl.Counter.minus(1)
    {:reply, value, state}
  end

  def handle_call(:dequeue, _from, []), do: {:reply, nil, []}

  def handle_call(:queue, _from, state) do
    {:reply, state, state}
  end

  @doc """
  GenServer.handle_cast/2 callback
  """
  def handle_cast({:enqueue, value}, state) do
    Crawl.Counter.add(1)
    {:noreply, state ++ [value]}
  end

  def handle_cast({:enqueue_list, value}, state) do
    exist_links = Crawl.Data.existed_links(value)
    value = value -- exist_links
    Crawl.Counter.add(length(value))
    {:noreply, state ++ value}
  end

  ### Client API / Helper functions

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def queue, do: GenServer.call(__MODULE__, :queue)
  def enqueue(value) when is_list(value), do: GenServer.cast(__MODULE__, {:enqueue_list, value})
  def enqueue(value), do: GenServer.cast(__MODULE__, {:enqueue, value})

  def dequeue, do: GenServer.call(__MODULE__, :dequeue)
end