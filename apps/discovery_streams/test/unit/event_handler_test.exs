defmodule DiscoveryStreams.EventHandlerTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  import Checkov
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, dataset_delete: 0]
  use Placebo

  describe "data:ingest:start event" do
    setup do
      allow Brook.ViewState.create(any(), any(), any()), return: :does_not_matter

      :ok
    end

    test "should store dataset.id by dataset.technical.systemName and vice versa" do
      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "stream", private: false, systemName: "fake_system_name"}
        )

      expect DiscoveryStreams.DatasetProcessor.start(dataset), return: :ok

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)

      response = DiscoveryStreams.EventHandler.handle_event(event)

      assert_called Brook.ViewState.create(:streaming_datasets_by_id, dataset.id, dataset.technical.systemName), once()

      assert_called Brook.ViewState.create(
                      :streaming_datasets_by_system_name,
                      dataset.technical.systemName,
                      dataset.id
                    ),
                    once()

      assert :ok == response
    end

    test "data:extract:start event should not handle private dataset" do
      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "stream", private: true, systemName: "fake_system_name"}
        )

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)

      response = DiscoveryStreams.EventHandler.handle_event(event)

      refute_called Brook.ViewState.create(any(), any(), any())
      assert :discard == response
    end
  end

  describe "dataset:update event" do
    setup do
      allow Brook.ViewState.delete(any(), any()), return: :does_not_matter

      :ok
    end

    data_test "when sourceType is '#{source_type}' and private is '#{private}' delete should be called #{delete_called} times" do
      system_name = Faker.UUID.v4()

      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: source_type, private: private, systemName: system_name}
        )

      if delete_called do
        expect DiscoveryStreams.DatasetProcessor.delete(dataset.id), return: :ok
      end

      event = Brook.Event.new(type: dataset_update(), data: dataset, author: :author)

      DiscoveryStreams.EventHandler.handle_event(event)

      assert delete_called == called?(Brook.ViewState.delete(:streaming_datasets_by_id, dataset.id))
      assert delete_called == called?(Brook.ViewState.delete(:streaming_datasets_by_system_name, system_name))

      where([
        [:source_type, :private, :delete_called],
        ["ingest", false, true],
        ["ingest", true, true],
        ["stream", false, false],
        ["stream", true, true]
      ])
    end

    test "should delete dataset when dataset:delete event fires" do
      system_name = Faker.UUID.v4()
      dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{systemName: system_name})
      allow(DiscoveryStreams.TopicHelper.delete_input_topic(any()), return: :ok)

      event = Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
      expect DiscoveryStreams.DatasetProcessor.delete(dataset.id), return: :ok

      DiscoveryStreams.EventHandler.handle_event(event)
      assert_called(Brook.ViewState.delete(:streaming_datasets_by_id, dataset.id))
      assert_called(Brook.ViewState.delete(:streaming_datasets_by_system_name, system_name))
    end
  end
end
