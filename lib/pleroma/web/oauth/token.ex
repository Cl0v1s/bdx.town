# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  @expires_in Pleroma.Config.get([:oauth2, :token_expires_in], 600)
  @type t :: %__MODULE__{}

  schema "oauth_tokens" do
    field(:token, :string)
    field(:refresh_token, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:valid_until, :naive_datetime_usec)
    belongs_to(:user, Pleroma.User, type: Pleroma.FlakeId)
    belongs_to(:app, App)

    timestamps()
  end

  @doc "Gets token for app by access token"
  @spec get_by_token(App.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_by_token(%App{id: app_id} = _app, token) do
    from(t in __MODULE__, where: t.app_id == ^app_id and t.token == ^token)
    |> Repo.find_resource()
  end

  @doc "Gets token for app by refresh token"
  @spec get_by_refresh_token(App.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_by_refresh_token(%App{id: app_id} = _app, token) do
    from(t in __MODULE__,
      where: t.app_id == ^app_id and t.refresh_token == ^token,
      preload: [:user]
    )
    |> Repo.find_resource()
  end

  def exchange_token(app, auth) do
    with {:ok, auth} <- Authorization.use_token(auth),
         true <- auth.app_id == app.id do
      create_token(
        app,
        User.get_cached_by_id(auth.user_id),
        %{scopes: auth.scopes}
      )
    end
  end

  defp put_token(changeset) do
    changeset
    |> change(%{token: Token.Utils.generate_token()})
    |> validate_required([:token])
    |> unique_constraint(:token)
  end

  defp put_refresh_token(changeset, attrs) do
    refresh_token = Map.get(attrs, :refresh_token, Token.Utils.generate_token())

    changeset
    |> change(%{refresh_token: refresh_token})
    |> validate_required([:refresh_token])
    |> unique_constraint(:refresh_token)
  end

  defp put_valid_until(changeset, attrs) do
    expires_in =
      Map.get(attrs, :valid_until, NaiveDateTime.add(NaiveDateTime.utc_now(), @expires_in))

    changeset
    |> change(%{valid_until: expires_in})
    |> validate_required([:valid_until])
  end

  def create_token(%App{} = app, %User{} = user, attrs \\ %{}) do
    %__MODULE__{user_id: user.id, app_id: app.id}
    |> cast(%{scopes: attrs[:scopes] || app.scopes}, [:scopes])
    |> validate_required([:scopes, :user_id, :app_id])
    |> put_valid_until(attrs)
    |> put_token
    |> put_refresh_token(attrs)
    |> Repo.insert()
  end

  def delete_user_tokens(%User{id: user_id}) do
    from(
      t in Token,
      where: t.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  def delete_user_token(%User{id: user_id}, token_id) do
    from(
      t in Token,
      where: t.user_id == ^user_id,
      where: t.id == ^token_id
    )
    |> Repo.delete_all()
  end

  def get_user_tokens(%User{id: user_id}) do
    from(
      t in Token,
      where: t.user_id == ^user_id
    )
    |> Repo.all()
    |> Repo.preload(:app)
  end

  def is_expired?(%__MODULE__{valid_until: valid_until}) do
    NaiveDateTime.diff(NaiveDateTime.utc_now(), valid_until) > 0
  end

  def is_expired?(_), do: false
end
