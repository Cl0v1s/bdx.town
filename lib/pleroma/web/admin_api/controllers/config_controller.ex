# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.ConfigDB
  alias Pleroma.Plugs.OAuthScopesPlug

  @descriptions Pleroma.Docs.JSON.compile()

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(OAuthScopesPlug, %{scopes: ["write"], admin: true} when action == :update)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read"], admin: true}
    when action in [:show, :descriptions]
  )

  action_fallback(Pleroma.Web.AdminAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.Admin.ConfigOperation

  def descriptions(conn, _params) do
    descriptions = Enum.filter(@descriptions, &whitelisted_config?/1)

    json(conn, descriptions)
  end

  def show(conn, %{only_db: true}) do
    with :ok <- configurable_from_database() do
      configs = Pleroma.Repo.all(ConfigDB)
      render(conn, "index.json", %{configs: configs})
    end
  end

  def show(conn, _params) do
    with :ok <- configurable_from_database() do
      configs = ConfigDB.get_all_as_keyword()

      merged =
        Config.Holder.default_config()
        |> ConfigDB.merge(configs)
        |> Enum.map(fn {group, values} ->
          Enum.map(values, fn {key, value} ->
            db =
              if configs[group][key] do
                ConfigDB.get_db_keys(configs[group][key], key)
              end

            db_value = configs[group][key]

            merged_value =
              if not is_nil(db_value) and Keyword.keyword?(db_value) and
                   ConfigDB.sub_key_full_update?(group, key, Keyword.keys(db_value)) do
                ConfigDB.merge_group(group, key, value, db_value)
              else
                value
              end

            setting = %{
              group: ConfigDB.convert(group),
              key: ConfigDB.convert(key),
              value: ConfigDB.convert(merged_value)
            }

            if db, do: Map.put(setting, :db, db), else: setting
          end)
        end)
        |> List.flatten()

      json(conn, %{configs: merged, need_reboot: Restarter.Pleroma.need_reboot?()})
    end
  end

  def update(%{body_params: %{configs: configs}} = conn, _) do
    with :ok <- configurable_from_database() do
      results =
        configs
        |> Enum.filter(&whitelisted_config?/1)
        |> Enum.map(fn
          %{group: group, key: key, delete: true} = params ->
            ConfigDB.delete(%{group: group, key: key, subkeys: params[:subkeys]})

          %{group: group, key: key, value: value} ->
            ConfigDB.update_or_create(%{group: group, key: key, value: value})
        end)
        |> Enum.reject(fn {result, _} -> result == :error end)

      {deleted, updated} =
        results
        |> Enum.map(fn {:ok, config} ->
          Map.put(config, :db, ConfigDB.get_db_keys(config))
        end)
        |> Enum.split_with(fn config ->
          Ecto.get_meta(config, :state) == :deleted
        end)

      Config.TransferTask.load_and_update_env(deleted, false)

      if not Restarter.Pleroma.need_reboot?() do
        changed_reboot_settings? =
          (updated ++ deleted)
          |> Enum.any?(fn config ->
            group = ConfigDB.from_string(config.group)
            key = ConfigDB.from_string(config.key)
            value = ConfigDB.from_binary(config.value)
            Config.TransferTask.pleroma_need_restart?(group, key, value)
          end)

        if changed_reboot_settings?, do: Restarter.Pleroma.need_reboot()
      end

      render(conn, "index.json", %{
        configs: updated,
        need_reboot: Restarter.Pleroma.need_reboot?()
      })
    end
  end

  defp configurable_from_database do
    if Config.get(:configurable_from_database) do
      :ok
    else
      {:error, "To use this endpoint you need to enable configuration from database."}
    end
  end

  defp whitelisted_config?(group, key) do
    if whitelisted_configs = Config.get(:database_config_whitelist) do
      Enum.any?(whitelisted_configs, fn
        {whitelisted_group} ->
          group == inspect(whitelisted_group)

        {whitelisted_group, whitelisted_key} ->
          group == inspect(whitelisted_group) && key == inspect(whitelisted_key)
      end)
    else
      true
    end
  end

  defp whitelisted_config?(%{group: group, key: key}) do
    whitelisted_config?(group, key)
  end

  defp whitelisted_config?(%{group: group} = config) do
    whitelisted_config?(group, config[:key])
  end
end
