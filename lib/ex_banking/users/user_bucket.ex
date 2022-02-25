defmodule ExBanking.Users.UserBucket do
  use Agent, restart: :transient

  @initial_amount_value Decimal.new("0")
  @precision_round 2

  def start_link(initial_value) do
    name = Keyword.get(initial_value, :name)
    Agent.start_link(fn -> %{} end, name: name)
  end

  def balance(bucket, currency) do
    Agent.get(bucket, fn entries ->
      {current_balance, _changes} = extract_info(entries[currency])

      {:ok, ensure_float_rounded(current_balance)}
    end)
  end

  def deposit(bucket, job_pid, amount, currency) do
    Agent.update(bucket, fn entries ->
      {current_balance, changes} = extract_info(entries[currency])

      updated_balance = Decimal.add(current_balance, amount)
      updated_changes = Map.put(changes, job_pid, %{status: :ok, balance: updated_balance})

      Map.put(entries, currency, insert_info(updated_balance, updated_changes))
    end)

    Agent.get(bucket, fn entries ->
      resulted_amount = entries[currency].changes[job_pid].balance |> ensure_float_rounded()
      {:ok, resulted_amount}
    end)
  end

  def withdraw(bucket, job_pid, amount, currency) do
    Agent.update(bucket, fn entries ->
      {current_balance, changes} = extract_info(entries[currency])

      {updated_balance, updated_changes} =
        if(Decimal.lt?(current_balance, amount)) do
          {current_balance,
           Map.put(changes, job_pid, %{status: :not_enough_money, balance: current_balance})}
        else
          updated_balance = Decimal.sub(current_balance, amount)
          {updated_balance, Map.put(changes, job_pid, %{status: :ok, balance: updated_balance})}
        end

      Map.put(entries, currency, insert_info(updated_balance, updated_changes))
    end)

    Agent.get(bucket, fn entries ->
      entries[currency].changes[job_pid]
      |> case do
        %{status: :not_enough_money} -> {:error, :not_enough_money}
        %{balance: value} -> {:ok, ensure_float_rounded(value)}
      end
    end)
  end

  def cancel_withdraw(bucket, job_pid, amount, currency) do
    Agent.cast(bucket, fn entries ->
      {current_balance, changes} = extract_info(entries[currency])

      {_changes, updated_changes} =
        Map.get_and_update(changes, job_pid, fn current_changes ->
          {current_balance, Map.put(current_changes, :status, :sender_unavailable)}
        end)

      updated_balance = Decimal.add(current_balance, amount)

      Map.put(entries, currency, insert_info(updated_balance, updated_changes))
    end)
  end

  defp extract_info(nil), do: {@initial_amount_value, %{}}

  defp extract_info(%{current_balance: current_balance, changes: changes}),
    do: {current_balance, changes}

  defp insert_info(updated_balance, updated_changes),
    do: %{current_balance: updated_balance, changes: updated_changes}

  @spec ensure_float_rounded(amount :: Decimal.t()) :: float()
  defp ensure_float_rounded(amount) do
    amount
    |> Decimal.round(@precision_round)
    |> Decimal.to_float()
  end
end
