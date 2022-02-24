defmodule ExBanking.Users.Actions do
  alias ExBanking.Users.UserBucket

  @workers_supervisor Application.fetch_env!(:ex_banking, :workers_supervisor)
  @worker_registry Application.fetch_env!(:ex_banking, :worker_registry)
  @bucket_registry Application.fetch_env!(:ex_banking, :bucket_registry)
  @limit_processes 10

  def create_user(user) do
    with {:ok, _pid} <-
           DynamicSupervisor.start_child(
             @workers_supervisor,
             {Task.Supervisor, name: via_worker(user), max_children: @limit_processes}
           ),
         {:ok, _pid} <- UserBucket.start_link(name: via_bucket(user)) do
      :ok
    else
      _ -> {:error, :user_already_exists}
    end
  end

  def get_balance(user, currency) do
    user
    |> check_user_exists()
    |> start_task(:get_balance, user: user, currency: currency)
  end

  def deposit(user, amount, currency) do
    user
    |> check_user_exists()
    |> start_task(:deposit, user: user, amount: amount, currency: currency)
  end

  def withdraw(user, amount, currency) do
    user
    |> check_user_exists()
    |> start_task(:withdraw, user: user, amount: amount, currency: currency)
  end

  def send_to(from_user, to_user, amount, currency) do
    with {:check_from_user_exists, {:ok, from_user_pid}} <-
           {:check_from_user_exists, check_user_exists(from_user)},
         {:check_to_user_exists, {:ok, _pid}} <-
           {:check_to_user_exists, check_user_exists(to_user)} do
      start_task({:ok, from_user_pid}, :send,
        from_user: from_user,
        to_user: to_user,
        amount: amount,
        currency: currency
      )
    else
      {:check_from_user_exists, error} ->
        error
        |> Tuple.append(:sender)
        |> then(&handle_response(:send, &1))

      {:check_to_user_exists, error} ->
        error
        |> Tuple.append(:receiver)
        |> then(&handle_response(:send, &1))
    end
  end

  defp start_task({:ok, user_pid}, action, args) do
    parent = self()

    args = Keyword.put(args, :parent, parent)

    Task.Supervisor.start_child(user_pid, fn -> task(action, args) end)
    |> then(&task_await/1)
    |> then(&handle_response(action, &1))
  end

  defp start_task({:error, error}, _action, _args), do: {:error, error}

  defp task(:get_balance, args) do
    user = Keyword.fetch!(args, :user)
    currency = Keyword.fetch!(args, :currency)
    parent = Keyword.fetch!(args, :parent)

    result = UserBucket.balance(via_bucket(user), currency)
    send(parent, result)
  end

  defp task(:deposit, args) do
    user = Keyword.fetch!(args, :user)
    amount = Keyword.fetch!(args, :amount)
    currency = Keyword.fetch!(args, :currency)
    parent = Keyword.fetch!(args, :parent)

    result = UserBucket.deposit(via_bucket(user), self(), amount, currency)
    send(parent, result)
  end

  defp task(:withdraw, args) do
    user = Keyword.fetch!(args, :user)
    amount = Keyword.fetch!(args, :amount)
    currency = Keyword.fetch!(args, :currency)
    parent = Keyword.fetch!(args, :parent)

    result = UserBucket.withdraw(via_bucket(user), self(), amount, currency)
    send(parent, result)
  end

  defp task(:send, args) do
    from_user = Keyword.fetch!(args, :from_user)
    to_user = Keyword.fetch!(args, :to_user)
    amount = Keyword.fetch!(args, :amount)
    currency = Keyword.fetch!(args, :currency)
    parent = Keyword.fetch!(args, :parent)

    result =
      with {:sender_withdraw, {:ok, sender_value}} <-
             {:sender_withdraw,
              UserBucket.withdraw(via_bucket(from_user), self(), amount, currency)},
           {:receiver_deposit, {:ok, receiver_value}} <-
             {:receiver_deposit, deposit(to_user, amount, currency)} do
        {:ok, sender_value, receiver_value}
      else
        {:sender_withdraw, error} ->
          Tuple.append(error, :sender)

        {:receiver_deposit, error} ->
          UserBucket.cancel_withdraw(via_bucket(from_user), self(), amount, currency)
          Tuple.append(error, :receiver)
      end

    send(parent, result)
  end

  def check_user_exists(name) do
    case GenServer.whereis(via_worker(name)) do
      nil -> {:error, :user_does_not_exist}
      pid -> {:ok, pid}
    end
  end

  defp task_await({:error, :max_children}), do: {:error, :too_many_requests_to_user}

  defp task_await({:ok, _pid}) do
    receive do
      response -> response
    after
      2_000 -> {:error, :unexpected}
    end
  end

  defp handle_response(:send, {:error, :too_many_requests_to_user}),
    do: {:error, :too_many_requests_to_sender}

  defp handle_response(:send, {:error, :too_many_requests_to_user, :receiver}),
    do: {:error, :too_many_requests_to_receiver}

  defp handle_response(:send, {:error, :user_does_not_exist, :sender}),
    do: {:error, :sender_does_not_exist}

  defp handle_response(:send, {:error, :user_does_not_exist, :receiver}),
    do: {:error, :receiver_does_not_exist}

  defp handle_response(:send, {:error, error, _}),
    do: {:error, error}

  defp handle_response(_action, result), do: result

  defp via_worker(user) do
    {:via, Registry, {@worker_registry, user}}
  end

  defp via_bucket(user) do
    {:via, Registry, {@bucket_registry, user}}
  end
end
