# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.Activity.Queries
  alias Pleroma.Bookmark
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.ReportNote
  alias Pleroma.ThreadMute
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}
  @type actor :: String.t()

  @primary_key {:id, FlakeId.Ecto.CompatType, autogenerate: true}

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  schema "activities" do
    field(:data, :map)
    field(:local, :boolean, default: true)
    field(:actor, :string)
    field(:recipients, {:array, :string}, default: [])
    field(:thread_muted?, :boolean, virtual: true)

    # A field that can be used if you need to join some kind of other
    # id to order / paginate this field by
    field(:pagination_id, :string, virtual: true)

    # This is a fake relation,
    # do not use outside of with_preloaded_user_actor/with_joined_user_actor
    has_one(:user_actor, User, on_delete: :nothing, foreign_key: :id)
    # This is a fake relation, do not use outside of with_preloaded_bookmark/get_bookmark
    has_one(:bookmark, Bookmark)
    # This is a fake relation, do not use outside of with_preloaded_report_notes
    has_many(:report_notes, ReportNote)
    has_many(:notifications, Notification, on_delete: :delete_all)

    # Attention: this is a fake relation, don't try to preload it blindly and expect it to work!
    # The foreign key is embedded in a jsonb field.
    #
    # To use it, you probably want to do an inner join and a preload:
    #
    # ```
    # |> join(:inner, [activity], o in Object,
    #      on: fragment("(?->>'id') = COALESCE((?)->'object'->> 'id', (?)->>'object')",
    #        o.data, activity.data, activity.data))
    # |> preload([activity, object], [object: object])
    # ```
    #
    # As a convenience, Activity.with_preloaded_object() sets up an inner join and preload for the
    # typical case.
    has_one(:object, Object, on_delete: :nothing, foreign_key: :id)

    timestamps()
  end

  def with_joined_object(query, join_type \\ :inner) do
    join(query, join_type, [activity], o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE(?->'object'->>'id', ?->>'object')",
          o.data,
          activity.data,
          activity.data
        ),
      as: :object
    )
  end

  def with_preloaded_object(query, join_type \\ :inner) do
    query
    |> has_named_binding?(:object)
    |> if(do: query, else: with_joined_object(query, join_type))
    |> preload([activity, object: object], object: object)
  end

  # Note: applies to fake activities (ActivityPub.Utils.get_notified_from_object/1 etc.)
  def user_actor(%Activity{actor: nil}), do: nil

  def user_actor(%Activity{} = activity) do
    with %User{} <- activity.user_actor do
      activity.user_actor
    else
      _ -> User.get_cached_by_ap_id(activity.actor)
    end
  end

  def with_joined_user_actor(query, join_type \\ :inner) do
    join(query, join_type, [activity], u in User,
      on: u.ap_id == activity.actor,
      as: :user_actor
    )
  end

  def with_preloaded_user_actor(query, join_type \\ :inner) do
    query
    |> with_joined_user_actor(join_type)
    |> preload([activity, user_actor: user_actor], user_actor: user_actor)
  end

  def with_preloaded_bookmark(query, %User{} = user) do
    from([a] in query,
      left_join: b in Bookmark,
      on: b.user_id == ^user.id and b.activity_id == a.id,
      as: :bookmark,
      preload: [bookmark: b]
    )
  end

  def with_preloaded_bookmark(query, _), do: query

  def with_preloaded_report_notes(query) do
    from([a] in query,
      left_join: r in ReportNote,
      on: a.id == r.activity_id,
      as: :report_note,
      preload: [report_notes: r]
    )
  end

  def with_preloaded_report_notes(query, _), do: query

  def with_set_thread_muted_field(query, %User{} = user) do
    from([a] in query,
      left_join: tm in ThreadMute,
      on: tm.user_id == ^user.id and tm.context == fragment("?->>'context'", a.data),
      as: :thread_mute,
      select: %Activity{a | thread_muted?: not is_nil(tm.id)}
    )
  end

  def with_set_thread_muted_field(query, _), do: query

  def get_by_ap_id(ap_id) do
    ap_id
    |> Queries.by_ap_id()
    |> Repo.one()
  end

  def get_bookmark(%Activity{} = activity, %User{} = user) do
    if Ecto.assoc_loaded?(activity.bookmark) do
      activity.bookmark
    else
      Bookmark.get(user.id, activity.id)
    end
  end

  def get_bookmark(_, _), do: nil

  def get_report(activity_id) do
    opts = %{
      type: "Flag",
      skip_preload: true,
      preload_report_notes: true
    }

    ActivityPub.fetch_activities_query([], opts)
    |> where(id: ^activity_id)
    |> Repo.one()
  end

  def change(struct, params \\ %{}) do
    struct
    |> cast(params, [:data, :recipients])
    |> validate_required([:data])
    |> unique_constraint(:ap_id, name: :activities_unique_apid_index)
  end

  def get_by_ap_id_with_object(ap_id) do
    ap_id
    |> Queries.by_ap_id()
    |> with_preloaded_object(:left)
    |> Repo.one()
  end

  @doc """
  Gets activity by ID, doesn't load activities from deactivated actors by default.
  """
  @spec get_by_id(String.t(), keyword()) :: t() | nil
  def get_by_id(id, opts \\ [filter: [:restrict_deactivated]]), do: get_by_id_with_opts(id, opts)

  @spec get_by_id_with_user_actor(String.t()) :: t() | nil
  def get_by_id_with_user_actor(id), do: get_by_id_with_opts(id, preload: [:user_actor])

  @spec get_by_id_with_object(String.t()) :: t() | nil
  def get_by_id_with_object(id), do: get_by_id_with_opts(id, preload: [:object])

  defp get_by_id_with_opts(id, opts) do
    if FlakeId.flake_id?(id) do
      query = Queries.by_id(id)

      with_filters_query =
        if is_list(opts[:filter]) do
          Enum.reduce(opts[:filter], query, fn
            {:type, type}, acc -> Queries.by_type(acc, type)
            :restrict_deactivated, acc -> restrict_deactivated_users(acc)
            _, acc -> acc
          end)
        else
          query
        end

      with_preloads_query =
        if is_list(opts[:preload]) do
          Enum.reduce(opts[:preload], with_filters_query, fn
            :user_actor, acc -> with_preloaded_user_actor(acc)
            :object, acc -> with_preloaded_object(acc)
            _, acc -> acc
          end)
        else
          with_filters_query
        end

      Repo.one(with_preloads_query)
    end
  end

  def all_by_ids_with_object(ids) do
    Activity
    |> where([a], a.id in ^ids)
    |> with_preloaded_object()
    |> Repo.all()
  end

  @doc """
  Accepts `ap_id` or list of `ap_id`.
  Returns a query.
  """
  @spec create_by_object_ap_id(String.t() | [String.t()]) :: Ecto.Queryable.t()
  def create_by_object_ap_id(ap_id) do
    ap_id
    |> Queries.by_object_id()
    |> Queries.by_type("Create")
  end

  def get_all_create_by_object_ap_id(ap_id) do
    ap_id
    |> create_by_object_ap_id()
    |> Repo.all()
  end

  def get_create_by_object_ap_id(ap_id) when is_binary(ap_id) do
    create_by_object_ap_id(ap_id)
    |> restrict_deactivated_users()
    |> Repo.one()
  end

  def get_create_by_object_ap_id(_), do: nil

  @doc """
  Accepts a list of `ap__id`.
  Returns a query yielding Create activities for the given objects,
  in the same order as they were specified in the input list.
  """
  @spec get_presorted_create_by_object_ap_id([String.t()]) :: Ecto.Queryable.t()
  def get_presorted_create_by_object_ap_id(ap_ids) do
    from(
      a in Activity,
      join:
        ids in fragment(
          "SELECT * FROM UNNEST(?::text[]) WITH ORDINALITY AS ids(ap_id, ord)",
          ^ap_ids
        ),
      on:
        ids.ap_id == fragment("?->>'object'", a.data) and
          fragment("?->>'type'", a.data) == "Create",
      order_by: [asc: ids.ord]
    )
  end

  @doc """
  Accepts `ap_id` or list of `ap_id`.
  Returns a query.
  """
  @spec create_by_object_ap_id_with_object(String.t() | [String.t()]) :: Ecto.Queryable.t()
  def create_by_object_ap_id_with_object(ap_id) do
    ap_id
    |> create_by_object_ap_id()
    |> with_preloaded_object()
  end

  def get_create_by_object_ap_id_with_object(ap_id) when is_binary(ap_id) do
    ap_id
    |> create_by_object_ap_id_with_object()
    |> Repo.one()
  end

  def get_create_by_object_ap_id_with_object(_), do: nil

  def get_local_create_by_object_ap_id(ap_id) when is_binary(ap_id) do
    ap_id
    |> create_by_object_ap_id()
    |> where(local: true)
    |> Repo.one()
  end

  @spec create_by_id_with_object(String.t()) :: t() | nil
  def create_by_id_with_object(id) do
    get_by_id_with_opts(id, preload: [:object], filter: [type: "Create"])
  end

  defp get_in_reply_to_activity_from_object(%Object{data: %{"inReplyTo" => ap_id}}) do
    get_create_by_object_ap_id_with_object(ap_id)
  end

  defp get_in_reply_to_activity_from_object(_), do: nil

  def get_in_reply_to_activity(%Activity{} = activity) do
    get_in_reply_to_activity_from_object(Object.normalize(activity, fetch: false))
  end

  def get_quoted_activity_from_object(%Object{data: %{"quoteUri" => ap_id}}) do
    get_create_by_object_ap_id_with_object(ap_id)
  end

  def get_quoted_activity_from_object(_), do: nil

  def normalize(%Activity{data: %{"id" => ap_id}}), do: get_by_ap_id_with_object(ap_id)
  def normalize(%{"id" => ap_id}), do: get_by_ap_id_with_object(ap_id)
  def normalize(ap_id) when is_binary(ap_id), do: get_by_ap_id_with_object(ap_id)
  def normalize(_), do: nil

  def delete_all_by_object_ap_id(id) when is_binary(id) do
    id
    |> Queries.by_object_id()
    |> Queries.exclude_type("Delete")
    |> select([u], u)
    |> Repo.delete_all(timeout: :infinity)
    |> elem(1)
    |> Enum.find(fn
      %{data: %{"type" => "Create", "object" => ap_id}} when is_binary(ap_id) -> ap_id == id
      %{data: %{"type" => "Create", "object" => %{"id" => ap_id}}} -> ap_id == id
      _ -> nil
    end)
    |> purge_web_resp_cache()
  end

  def delete_all_by_object_ap_id(_), do: nil

  defp purge_web_resp_cache(%Activity{data: %{"id" => id}} = activity) when is_binary(id) do
    with %{path: path} <- URI.parse(id) do
      @cachex.del(:web_resp_cache, path)
    end

    activity
  end

  defp purge_web_resp_cache(activity), do: activity

  def follow_accepted?(
        %Activity{data: %{"type" => "Follow", "object" => followed_ap_id}} = activity
      ) do
    with %User{} = follower <- Activity.user_actor(activity),
         %User{} = followed <- User.get_cached_by_ap_id(followed_ap_id) do
      Pleroma.FollowingRelationship.following?(follower, followed)
    else
      _ -> false
    end
  end

  def follow_accepted?(_), do: false

  def all_by_actor_and_id(actor, status_ids \\ [])
  def all_by_actor_and_id(_actor, []), do: []

  def all_by_actor_and_id(actor, status_ids) do
    Activity
    |> where([s], s.id in ^status_ids)
    |> where([s], s.actor == ^actor)
    |> Repo.all()
  end

  def follow_requests_for_actor(%User{ap_id: ap_id}) do
    ap_id
    |> Queries.by_object_id()
    |> Queries.by_type("Follow")
    |> where([a], fragment("? ->> 'state' = 'pending'", a.data))
  end

  def following_requests_for_actor(%User{ap_id: ap_id}) do
    Queries.by_type("Follow")
    |> where([a], fragment("?->>'state' = 'pending'", a.data))
    |> where([a], a.actor == ^ap_id)
    |> Repo.all()
  end

  def follow_activity(%User{ap_id: ap_id}, %User{ap_id: followed_ap_id}) do
    Queries.by_type("Follow")
    |> where([a], a.actor == ^ap_id)
    |> where([a], fragment("?->>'object' = ?", a.data, ^followed_ap_id))
    |> where([a], fragment("?->>'state'", a.data) in ["pending", "accept"])
    |> Repo.one()
  end

  def restrict_deactivated_users(query) do
    query
    |> join(
      :inner_lateral,
      [activity],
      active in fragment(
        "SELECT is_active from users WHERE ap_id = ? AND is_active = TRUE",
        activity.actor
      ),
      on: true
    )
  end

  defdelegate search(user, query, options \\ []), to: Pleroma.Search.DatabaseSearch

  def direct_conversation_id(activity, for_user) do
    alias Pleroma.Conversation.Participation

    with %{data: %{"context" => context}} when is_binary(context) <- activity,
         %Pleroma.Conversation{} = conversation <- Pleroma.Conversation.get_for_ap_id(context),
         %Participation{id: participation_id} <-
           Participation.for_user_and_conversation(for_user, conversation) do
      participation_id
    else
      _ -> nil
    end
  end

  @spec get_by_object_ap_id_with_object(String.t()) :: t() | nil
  def get_by_object_ap_id_with_object(ap_id) when is_binary(ap_id) do
    ap_id
    |> Queries.by_object_id()
    |> with_preloaded_object()
    |> first()
    |> Repo.one()
  end

  def get_by_object_ap_id_with_object(_), do: nil

  @spec add_by_params_query(String.t(), String.t(), String.t()) :: Ecto.Query.t()
  def add_by_params_query(object_id, actor, target) do
    object_id
    |> Queries.by_object_id()
    |> Queries.by_type("Add")
    |> Queries.by_actor(actor)
    |> where([a], fragment("?->>'target' = ?", a.data, ^target))
  end
end
