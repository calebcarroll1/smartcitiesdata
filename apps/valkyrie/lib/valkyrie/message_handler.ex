require Logger

defmodule Valkyrie.MessageHandler do
  @moduledoc false
  alias SmartCity.Data

  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, &handle_message/1)
    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ok
  end

  def handle_message(%{key: key, value: value}) do
    start_time = Data.Timing.current_time()

    with {:ok, new_value} <- Data.new(value),
         {:ok, validated_message} <- validate(new_value),
         {:ok, updated_message} <- set_operational_timing(start_time, validated_message),
         {:ok, encoded_message} <- Jason.encode(updated_message) do
      Kaffe.Producer.produce_sync(key, encoded_message)
    else
      {:error, "Invalid data message"} ->
        nil

      {:error, reason} ->
        Logger.warn("Error handling message: #{value}")
        Yeet.process_dead_letter(value, "Valkyrie", reason: inspect(reason))

      _ ->
        Logger.warn("Error handling message: #{value}")
        Yeet.process_dead_letter(value, "Valkyrie")
    end
  end

  defp validate(%Data{dataset_id: id, payload: payload} = message) do
    %Valkyrie.Dataset{schema: schema} = Valkyrie.Dataset.get(id)

    invalid_fields = Valkyrie.Validators.get_invalid_fields(payload, schema)

    if Enum.empty?(invalid_fields) do
      {:ok, message}
    else
      fields = Enum.join(invalid_fields, ", ")
      Logger.warn("The following fields were invalid: #{fields}")
      Yeet.process_dead_letter(message, "Valkyrie", reason: "The following fields were invalid: #{fields}")
      {:error, "Invalid data message"}
    end
  end

  defp set_operational_timing(start_time, validated_message) do
    try do
      updated_message =
        validated_message
        |> Data.add_timing(
          Data.Timing.new(
            :valkyrie,
            :timing,
            start_time,
            Data.Timing.current_time()
          )
        )

      {:ok, updated_message}
    rescue
      _ -> {:error, "Failed to set operational timing."}
    end
  end
end
