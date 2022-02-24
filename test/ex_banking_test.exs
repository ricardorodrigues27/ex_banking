defmodule ExBankingTest do
  use ExUnit.Case, async: false
  doctest ExBanking

  @workers_supervisor Application.fetch_env!(:ex_banking, :workers_supervisor)
  @worker_registry Application.fetch_env!(:ex_banking, :worker_registry)
  @bucket_registry Application.fetch_env!(:ex_banking, :bucket_registry)

  setup do
    start_supervised!(
      {DynamicSupervisor, name: @workers_supervisor, strategy: :one_for_one, max_seconds: 30}
    )

    start_supervised!({Registry, name: @bucket_registry, keys: :unique})
    start_supervised!({Registry, name: @worker_registry, keys: :unique})

    :ok
  end

  defp generate_user_name do
    :crypto.strong_rand_bytes(5)
    |> Base.url_encode64(padding: false)
  end

  test "get_balance/2" do
    user = "ricardo"

    ExBanking.create_user(user)

    # user not exists
    assert {:error, :user_does_not_exist} = ExBanking.get_balance("not_exists", "usd")

    assert {:ok, 0} = ExBanking.get_balance(user, "usd")

    # after deposit
    ExBanking.deposit(user, 1, "usd")
    assert {:ok, 1} = ExBanking.get_balance(user, "usd")
  end

  test "get_balance/2 massive calls" do
    user = "ricardo"

    ExBanking.create_user(user)

    1..1500
    |> Enum.each(fn _ ->
      spawn(fn -> ExBanking.get_balance(user, "usd") end)
    end)

    assert {:error, :too_many_requests_to_user} = ExBanking.get_balance(user, "usd")
  end

  test "deposit/3" do
    user = generate_user_name()

    ExBanking.create_user(user)

    # user not exists
    assert {:error, :user_does_not_exist} = ExBanking.deposit("not_exists", 1, "usd")

    assert {:ok, 1} = ExBanking.deposit(user, 1, "usd")
    assert {:ok, 2} = ExBanking.deposit(user, 1, "usd")
    assert {:ok, 2} = ExBanking.get_balance(user, "usd")
  end

  test "deposit/3 massive calls" do
    user = generate_user_name()

    ExBanking.create_user(user)

    1..1500
    |> Enum.each(fn _ ->
      spawn(fn -> ExBanking.get_balance(user, "usd") end)
    end)

    assert {:error, :too_many_requests_to_user} = ExBanking.deposit(user, 1.0, "usd")
  end

  test "withdraw/3" do
    user = generate_user_name()

    ExBanking.create_user(user)

    # user not exists
    assert {:error, :user_does_not_exist} = ExBanking.withdraw("not_exists", 1, "usd")

    # without balance
    assert {:error, :not_enough_money} = ExBanking.withdraw(user, 1, "usd")

    ExBanking.deposit(user, 1, "usd")
    assert {:ok, 0} = ExBanking.withdraw(user, 1, "usd")
    assert {:ok, 0} = ExBanking.get_balance(user, "usd")
  end

  test "withdraw/3 massive calls" do
    user = generate_user_name()

    ExBanking.create_user(user)

    1..1500
    |> Enum.each(fn _ ->
      spawn(fn -> ExBanking.get_balance(user, "usd") end)
    end)

    assert {:error, :too_many_requests_to_user} = ExBanking.withdraw(user, 1.0, "usd")
  end

  test "send/4" do
    user_1 = generate_user_name()
    user_2 = generate_user_name()

    ExBanking.create_user(user_1)
    ExBanking.create_user(user_2)

    # without balance
    assert {:error, :not_enough_money} = ExBanking.send(user_1, user_2, 1, "usd")
    assert {:error, :not_enough_money} = ExBanking.send(user_2, user_1, 1, "usd")

    ExBanking.deposit(user_1, 1, "usd")
    assert {:ok, 0, 1} = ExBanking.send(user_1, user_2, 1, "usd")
    assert {:ok, 0} = ExBanking.get_balance(user_1, "usd")
    assert {:ok, 1} = ExBanking.get_balance(user_2, "usd")

    assert {:ok, 0, 1} = ExBanking.send(user_2, user_1, 1, "usd")
    assert {:ok, 1} = ExBanking.get_balance(user_1, "usd")
    assert {:ok, 0} = ExBanking.get_balance(user_2, "usd")
  end

  test "send/4 concurrenctly" do
    require Integer

    user_1 = generate_user_name()
    user_2 = generate_user_name()

    ExBanking.create_user(user_1)
    ExBanking.create_user(user_2)

    ExBanking.deposit(user_1, 2, "usd")
    ExBanking.deposit(user_2, 5, "usd")

    1..4000
    |> Enum.each(fn x ->
      spawn(fn ->
        if Integer.is_even(x) do
          ExBanking.send(user_1, user_2, 1.0, "usd")
        else
          ExBanking.send(user_2, user_1, 1.0, "usd")
        end
      end)
    end)

    Process.sleep(500)

    assert {:ok, _} = ExBanking.get_balance(user_1, "usd")
  end

  test "send/4 massive calls sender" do
    user_1 = generate_user_name()
    user_2 = generate_user_name()

    ExBanking.create_user(user_1)
    ExBanking.create_user(user_2)

    ExBanking.deposit(user_1, 1000, "usd")

    1..900
    |> Enum.each(fn _ ->
      spawn(fn -> ExBanking.get_balance(user_1, "usd") end)
    end)

    assert {:error, :too_many_requests_to_sender} = ExBanking.send(user_1, user_2, 1, "usd")
  end

  test "send/4 massive calls receiver" do
    user_1 = generate_user_name()
    user_2 = generate_user_name()

    ExBanking.create_user(user_1)
    ExBanking.create_user(user_2)

    ExBanking.deposit(user_1, 1000, "usd")

    1..1500
    |> Enum.each(fn _ ->
      spawn(fn -> ExBanking.get_balance(user_2, "usd") end)
    end)

    assert {:error, :too_many_requests_to_receiver} = ExBanking.send(user_1, user_2, 1, "usd")
  end
end
