# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper do
  @moduledoc """
  Configure Tesla.Client with default and customized adapter options.
  """
  @defaults [name: MyFinch, pool_timeout: 5_000, receive_timeout: 5_000]

  @type proxy_type() :: :socks4 | :socks5
  @type host() :: charlist() | :inet.ip_address()

  alias Pleroma.HTTP.AdapterHelper
  require Logger

  @type proxy :: {Connection.proxy_type(), Connection.host(), pos_integer(), list()}

  @callback options(keyword(), URI.t()) :: keyword()

  @spec format_proxy(String.t() | tuple() | nil) :: proxy() | nil
  def format_proxy(nil), do: nil

  def format_proxy(proxy_url) do
    case parse_proxy(proxy_url) do
      {:ok, type, host, port} -> {type, host, port, []}
      _ -> nil
    end
  end

  @spec maybe_add_proxy(keyword(), proxy() | nil) :: keyword()
  def maybe_add_proxy(opts, nil), do: opts

  def maybe_add_proxy(opts, proxy) do
    Keyword.put(opts, :proxy, proxy)
  end

  def maybe_add_proxy_pool(opts, nil), do: opts

  def maybe_add_proxy_pool(opts, proxy) do
    Logger.info("Using HTTP Proxy: #{inspect(proxy)}")

    opts
    |> maybe_add_pools()
    |> maybe_add_default_pool()
    |> maybe_add_conn_opts()
    |> put_in([:pools, :default, :conn_opts, :proxy], proxy)
  end

  def maybe_add_cacerts(opts, nil), do: opts

  def maybe_add_cacerts(opts, cacerts) do
    opts
    |> maybe_add_pools()
    |> maybe_add_default_pool()
    |> maybe_add_conn_opts()
    |> maybe_add_transport_opts()
    |> put_in([:pools, :default, :conn_opts, :transport_opts, :cacerts], cacerts)
  end

  def add_pool_size(opts, pool_size) do
    opts
    |> maybe_add_pools()
    |> maybe_add_default_pool()
    |> put_in([:pools, :default, :size], pool_size)
  end

  def ensure_ipv6(opts) do
    # Default transport opts already enable IPv6, so just ensure they're loaded
    opts
    |> maybe_add_pools()
    |> maybe_add_default_pool()
    |> maybe_add_conn_opts()
    |> maybe_add_transport_opts()
  end

  defp maybe_add_pools(opts) do
    if Keyword.has_key?(opts, :pools) do
      opts
    else
      Keyword.put(opts, :pools, %{})
    end
  end

  defp maybe_add_default_pool(opts) do
    pools = Keyword.get(opts, :pools)

    if Map.has_key?(pools, :default) do
      opts
    else
      put_in(opts, [:pools, :default], [])
    end
  end

  defp maybe_add_conn_opts(opts) do
    conn_opts = get_in(opts, [:pools, :default, :conn_opts])

    unless is_nil(conn_opts) do
      opts
    else
      put_in(opts, [:pools, :default, :conn_opts], [])
    end
  end

  defp maybe_add_transport_opts(opts) do
    transport_opts = get_in(opts, [:pools, :default, :conn_opts, :transport_opts])

    opts =
      unless is_nil(transport_opts) do
        opts
      else
        put_in(opts, [:pools, :default, :conn_opts, :transport_opts], [])
      end

    # IPv6 is disabled and IPv4 enabled by default; ensure we can use both
    put_in(opts, [:pools, :default, :conn_opts, :transport_opts, :inet6], true)
  end

  def add_default_pool_max_idle_time(opts, pool_timeout) do
    opts
    |> maybe_add_pools()
    |> maybe_add_default_pool()
    |> put_in([:pools, :default, :pool_max_idle_time], pool_timeout)
  end

  def add_default_conn_max_idle_time(opts, connection_timeout) do
    opts
    |> maybe_add_pools()
    |> maybe_add_default_pool()
    |> put_in([:pools, :default, :conn_max_idle_time], connection_timeout)
  end

  @doc """
  Merge default connection & adapter options with received ones.
  """

  @spec options(URI.t(), keyword()) :: keyword()
  def options(%URI{} = uri, opts \\ []) do
    @defaults
    |> Keyword.merge(opts)
    |> AdapterHelper.Default.options(uri)
  end

  defp proxy_type("http"), do: {:ok, :http}
  defp proxy_type("https"), do: {:ok, :https}
  defp proxy_type(_), do: {:error, :unknown}

  @spec parse_proxy(String.t() | tuple() | nil) ::
          {:ok, proxy_type(), host(), pos_integer()}
          | {:error, atom()}
          | nil
  def parse_proxy(nil), do: nil
  def parse_proxy(""), do: nil

  def parse_proxy(proxy) when is_binary(proxy) do
    with %URI{} = uri <- URI.parse(proxy),
         {:ok, type} <- proxy_type(uri.scheme) do
      {:ok, type, uri.host, uri.port}
    else
      e ->
        Logger.warning("Parsing proxy failed #{inspect(proxy)}, #{inspect(e)}")
        {:error, :invalid_proxy}
    end
  end

  def parse_proxy(proxy) when is_tuple(proxy) do
    with {type, host, port} <- proxy do
      {:ok, type, host, port}
    else
      _ ->
        Logger.warning("Parsing proxy failed #{inspect(proxy)}")
        {:error, :invalid_proxy}
    end
  end

  @spec parse_host(String.t() | atom() | charlist()) :: charlist() | :inet.ip_address()
  def parse_host(host) when is_list(host), do: host
  def parse_host(host) when is_atom(host), do: to_charlist(host)

  def parse_host(host) when is_binary(host) do
    host = to_charlist(host)

    case :inet.parse_address(host) do
      {:error, :einval} -> host
      {:ok, ip} -> ip
    end
  end

  @spec format_host(String.t()) :: charlist()
  def format_host(host) do
    host_charlist = to_charlist(host)

    case :inet.parse_address(host_charlist) do
      {:error, :einval} ->
        :idna.encode(host_charlist)

      {:ok, _ip} ->
        host_charlist
    end
  end
end
