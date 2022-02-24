defmodule ExBanking.Users.UserBucket do
  use Agent, restart: :transient

  @initial_amount_value 0.0
  @precision_round 2

  def start_link(initial_value) do
    name = Keyword.get(initial_value, :name)
    Agent.start_link(fn -> %{} end, name: name)
  end

  def balance(bucket, currency) do
    Agent.get(bucket, fn entries ->
      {current_value, _changes} = extract_info(entries[currency])

      {:ok, ensure_float_rounded(current_value)}
    end)
  end

  def deposit(bucket, job_pid, amount, currency) do
    Agent.update(bucket, fn entries ->
      {current_value, changes} = extract_info(entries[currency])

      updated_value = current_value + amount
      updated_changes = Map.put(changes, job_pid, %{status: :ok, result: updated_value})

      Map.put(entries, currency, insert_info(updated_value, updated_changes))
    end)

    Agent.get(bucket, fn entries ->
      resulted_amount = entries[currency].changes[job_pid].result |> ensure_float_rounded()
      {:ok, resulted_amount}
    end)
  end

  def withdraw(bucket, job_pid, amount, currency) do
    Agent.update(bucket, fn entries ->
      {current_value, changes} = extract_info(entries[currency])

      {updated_value, updated_changes} =
        if(current_value < amount) do
          {current_value,
           Map.put(changes, job_pid, %{status: :not_enough_money, result: current_value})}
        else
          updated_value = current_value - amount
          {updated_value, Map.put(changes, job_pid, %{status: :ok, result: updated_value})}
        end

      Map.put(entries, currency, insert_info(updated_value, updated_changes))
    end)

    Agent.get(bucket, fn entries ->
      entries[currency].changes[job_pid]
      |> case do
        %{status: :not_enough_money} -> {:error, :not_enough_money}
        %{result: value} -> {:ok, ensure_float_rounded(value)}
      end
    end)
  end

  def cancel_withdraw(bucket, job_pid, amount, currency) do
    Agent.cast(bucket, fn entries ->
      {current_value, changes} = extract_info(entries[currency])

      {_changes, updated_changes} =
        Map.get_and_update(changes, job_pid, fn current_changes ->
          {current_value, Map.put(current_changes, :status, :sender_unavailable)}
        end)

      updated_value = current_value + amount

      Map.put(entries, currency, insert_info(updated_value, updated_changes))
    end)
  end

  defp extract_info(nil), do: {@initial_amount_value, %{}}

  defp extract_info(%{current_value: current_value, changes: changes}),
    do: {current_value, changes}

  defp insert_info(updated_value, updated_changes),
    do: %{current_value: updated_value, changes: updated_changes}

  defp ensure_float_rounded(amount) do
    Float.round(amount, @precision_round)
  end
end
