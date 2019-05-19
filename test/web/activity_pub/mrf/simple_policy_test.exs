# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.SimplePolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF.SimplePolicy

  setup do
    orig = Config.get!(:mrf_simple)

    Config.put(:mrf_simple,
      media_removal: [],
      media_nsfw: [],
      federated_timeline_removal: [],
      report_removal: [],
      reject: [],
      accept: []
    )

    on_exit(fn ->
      Config.put(:mrf_simple, orig)
    end)
  end

  describe "when :media_removal" do
    test "is empty" do
      Config.put([:mrf_simple, :media_removal], [])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) == {:ok, media_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      Config.put([:mrf_simple, :media_removal], ["remote.instance"])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) ==
               {:ok,
                media_message
                |> Map.put("object", Map.delete(media_message["object"], "attachment"))}

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  describe "when :media_nsfw" do
    test "is empty" do
      Config.put([:mrf_simple, :media_nsfw], [])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) == {:ok, media_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      Config.put([:mrf_simple, :media_nsfw], ["remote.instance"])
      media_message = build_media_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(media_message) ==
               {:ok,
                media_message
                |> put_in(["object", "tag"], ["foo", "nsfw"])
                |> put_in(["object", "sensitive"], true)}

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  defp build_media_message do
    %{
      "actor" => "https://remote.instance/users/bob",
      "type" => "Create",
      "object" => %{
        "attachment" => [%{}],
        "tag" => ["foo"],
        "sensitive" => false
      }
    }
  end

  describe "when :report_removal" do
    test "is empty" do
      Config.put([:mrf_simple, :report_removal], [])
      report_message = build_report_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(report_message) == {:ok, report_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      Config.put([:mrf_simple, :report_removal], ["remote.instance"])
      report_message = build_report_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(report_message) == {:reject, nil}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  defp build_report_message do
    %{
      "actor" => "https://remote.instance/users/bob",
      "type" => "Flag"
    }
  end

  describe "when :federated_timeline_removal" do
    test "is empty" do
      Config.put([:mrf_simple, :federated_timeline_removal], [])
      {_, ftl_message} = build_ftl_actor_and_message()
      local_message = build_local_message()

      assert SimplePolicy.filter(ftl_message) == {:ok, ftl_message}
      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end

    test "has a matching host" do
      {actor, ftl_message} = build_ftl_actor_and_message()

      ftl_message_actor_host =
        ftl_message
        |> Map.fetch!("actor")
        |> URI.parse()
        |> Map.fetch!(:host)

      Config.put([:mrf_simple, :federated_timeline_removal], [ftl_message_actor_host])
      local_message = build_local_message()

      assert {:ok, ftl_message} = SimplePolicy.filter(ftl_message)
      assert actor.follower_address in ftl_message["to"]
      refute actor.follower_address in ftl_message["cc"]
      refute "https://www.w3.org/ns/activitystreams#Public" in ftl_message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in ftl_message["cc"]

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
    end
  end

  defp build_ftl_actor_and_message do
    actor = insert(:user)

    {actor,
     %{
       "actor" => actor.ap_id,
       "to" => ["https://www.w3.org/ns/activitystreams#Public", "http://foo.bar/baz"],
       "cc" => [actor.follower_address, "http://foo.bar/qux"]
     }}
  end

  describe "when :reject" do
    test "is empty" do
      Config.put([:mrf_simple, :reject], [])

      remote_message = build_remote_message()

      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end

    test "has a matching host" do
      Config.put([:mrf_simple, :reject], ["remote.instance"])

      remote_message = build_remote_message()

      assert SimplePolicy.filter(remote_message) == {:reject, nil}
    end
  end

  describe "when :accept" do
    test "is empty" do
      Config.put([:mrf_simple, :accept], [])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end

    test "is not empty but it doesn't have a matching host" do
      Config.put([:mrf_simple, :accept], ["non.matching.remote"])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert SimplePolicy.filter(remote_message) == {:reject, nil}
    end

    test "has a matching host" do
      Config.put([:mrf_simple, :accept], ["remote.instance"])

      local_message = build_local_message()
      remote_message = build_remote_message()

      assert SimplePolicy.filter(local_message) == {:ok, local_message}
      assert SimplePolicy.filter(remote_message) == {:ok, remote_message}
    end
  end

  defp build_local_message do
    %{
      "actor" => "#{Pleroma.Web.base_url()}/users/alice",
      "to" => [],
      "cc" => []
    }
  end

  defp build_remote_message do
    %{"actor" => "https://remote.instance/users/bob"}
  end
end
