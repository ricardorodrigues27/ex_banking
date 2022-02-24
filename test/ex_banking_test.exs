defmodule ExBankingTest do
  use ExUnit.Case, async: false
  doctest ExBanking

  @workers_supervisor Application.fetch_env!(:ex_banking, :workers_supervisor)
  @worker_registry Application.fetch_env!(:ex_banking, :worker_registry)
  @bucket_registry Application.fetch_env!(:ex_banking, :bucket_registry)
  @default_user "default_user"

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

  defp create_default_user(_context) do
    ExBanking.create_user(@default_user)

    :ok
  end

  describe "create_user/1" do
    test "should return error with invalid arguments" do
      assert {:error, :wrong_arguments} = ExBanking.create_user(1)
      assert {:error, :wrong_arguments} = ExBanking.create_user("")
    end

    test "should return error when user already exists" do
      ExBanking.create_user(@default_user)
      assert {:error, :user_already_exists} = ExBanking.create_user(@default_user)
    end

    test "should return success with valid arguments" do
      assert :ok = ExBanking.create_user("new user")
    end
  end

  describe "get_balance/2" do
    setup :create_default_user

    test "should return error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.get_balance("not_user", "usd")
    end

    test "should return error when calls with wrong arguments" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@default_user, 1)
    end

    test "should return balance for existing user" do
      # without balance for currency
      assert {:ok, 0.0} = ExBanking.get_balance(@default_user, "usd")

      ExBanking.deposit(@default_user, 1, "usd")
      assert {:ok, 1.0} = ExBanking.get_balance(@default_user, "usd")
    end

    test "should return error when reaches limit processes for the user" do
      1..1000
      |> Enum.each(fn _ ->
        spawn(fn -> ExBanking.get_balance(@default_user, "usd") end)
      end)

      assert {:error, :too_many_requests_to_user} = ExBanking.get_balance(@default_user, "usd")
    end
  end

  describe "deposit/3" do
    setup :create_default_user

    test "should return error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.deposit("not_user", 1, "usd")
    end

    test "should return error when calls with wrong arguments" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(1, 1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.deposit(@default_user, 1, 1)
      assert {:error, :wrong_arguments} = ExBanking.deposit(@default_user, -1, "usd")
    end

    test "should return success and new balance with valid arguments" do
      assert {:ok, 1.0} = ExBanking.deposit(@default_user, 1, "usd")
      assert {:ok, 2.0} = ExBanking.deposit(@default_user, 1.0, "usd")

      assert {:ok, 2.0} = ExBanking.get_balance(@default_user, "usd")
    end

    test "should return error when reaches limit processes for the user" do
      1..1000
      |> Enum.each(fn _ ->
        spawn(fn -> ExBanking.get_balance(@default_user, "usd") end)
      end)

      assert {:error, :too_many_requests_to_user} = ExBanking.deposit(@default_user, 1, "usd")
    end
  end

  describe "withdraw/3" do
    setup :create_default_user

    test "should return error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.withdraw("not_user", 1, "usd")
    end

    test "should return error when calls with wrong arguments" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(1, 1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@default_user, 1, 1)
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@default_user, -1, "usd")
    end

    test "should return error when user not have money" do
      assert {:error, :not_enough_money} = ExBanking.withdraw(@default_user, 1, "usd")
    end

    test "should return success and new balance with valid arguments" do
      ExBanking.deposit(@default_user, 10, "usd")
      assert {:ok, 8.0} = ExBanking.withdraw(@default_user, 2, "usd")
      assert {:ok, 8.0} = ExBanking.get_balance(@default_user, "usd")
    end

    test "should return error when reaches limit processes for the user" do
      1..1000
      |> Enum.each(fn _ ->
        spawn(fn -> ExBanking.get_balance(@default_user, "usd") end)
      end)

      assert {:error, :too_many_requests_to_user} = ExBanking.withdraw(@default_user, 1, "usd")
    end
  end

  describe "send/4" do
    setup _context do
      first_user = "user1"
      second_user = "user2"

      ExBanking.create_user(first_user)
      ExBanking.create_user(second_user)

      %{first_user: first_user, second_user: second_user}
    end

    test "should return error when user does not exists", %{
      first_user: first_user,
      second_user: second_user
    } do
      assert {:error, :sender_does_not_exist} = ExBanking.send("not_user", second_user, 1, "usd")
      assert {:error, :receiver_does_not_exist} = ExBanking.send(first_user, "not_user", 1, "usd")
    end

    test "should return error when calls with wrong arguments", %{
      first_user: first_user,
      second_user: second_user
    } do
      assert {:error, :wrong_arguments} = ExBanking.send(1, second_user, 1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.send("", second_user, 1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.send(first_user, 1, 1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.send(first_user, "", 1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.send(first_user, second_user, "", "usd")
      assert {:error, :wrong_arguments} = ExBanking.send(first_user, second_user, -1, "usd")
      assert {:error, :wrong_arguments} = ExBanking.send(first_user, second_user, 1, 1)
      assert {:error, :wrong_arguments} = ExBanking.send(first_user, second_user, 1, "")
    end

    test "should return error when user not have money", %{
      first_user: first_user,
      second_user: second_user
    } do
      assert {:error, :not_enough_money} = ExBanking.send(first_user, second_user, 1, "usd")
    end

    test "should return success and new balance for users with valid arguments", %{
      first_user: first_user,
      second_user: second_user
    } do
      ExBanking.deposit(first_user, 10, "usd")
      ExBanking.deposit(second_user, 10, "usd")

      # send money from user1 to user2
      assert {:ok, 8.0, 12.0} = ExBanking.send(first_user, second_user, 2, "usd")
      assert {:ok, 8.0} = ExBanking.get_balance(first_user, "usd")
      assert {:ok, 12.0} = ExBanking.get_balance(second_user, "usd")

      # send money from user2 to user1
      assert {:ok, 10.0, 10.0} = ExBanking.send(second_user, first_user, 2, "usd")
      assert {:ok, 10.0} = ExBanking.get_balance(first_user, "usd")
      assert {:ok, 10.0} = ExBanking.get_balance(second_user, "usd")
    end

    test "should return error when reaches limit processes for the first user", %{
      first_user: first_user,
      second_user: second_user
    } do
      1..1000
      |> Enum.each(fn _ ->
        spawn(fn -> ExBanking.get_balance(first_user, "usd") end)
      end)

      assert {:error, :too_many_requests_to_sender} = ExBanking.send(first_user, second_user, 1, "usd")
    end

    test "should return error when reaches limit processes for the second user", %{
      first_user: first_user,
      second_user: second_user
    } do
      1..1000
      |> Enum.each(fn _ ->
        spawn(fn -> ExBanking.get_balance(second_user, "usd") end)
      end)

      assert {:error, :too_many_requests_to_receiver} = ExBanking.send(first_user, second_user, 1, "usd")
    end
  end
end
