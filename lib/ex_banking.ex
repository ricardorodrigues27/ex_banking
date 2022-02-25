defmodule ExBanking do
  @moduledoc """
  Documentation for `ExBanking`.
  """

  alias ExBanking.Users

  @type banking_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists
           | :user_does_not_exist
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_user
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  @spec create_user(user :: String.t()) ::
          :ok | banking_error
  def create_user(name)
  def create_user(""), do: wrong_arguments()
  def create_user(user) when is_binary(user), do: Users.create_user(user)
  def create_user(_user), do: wrong_arguments()

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number()} | banking_error
  def get_balance(user, currency)
  def get_balance("", _currency), do: wrong_arguments()
  def get_balance(_user, ""), do: wrong_arguments()

  def get_balance(user, currency) when is_binary(user) and is_binary(currency),
    do: Users.get_balance(user, currency)

  def get_balance(_user, _currency), do: wrong_arguments()

  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, balance :: number()} | banking_error
  def deposit(user, amount, currency)
  def deposit("", _amount, _currency), do: wrong_arguments()
  def deposit(_user, _amount, ""), do: wrong_arguments()

  def deposit(user, amount, currency)
      when is_number(amount) and amount >= 0 and is_binary(user) and is_binary(currency) do
    amount
    |> ensure_decimal()
    |> then(&Users.deposit(user, &1, currency))
  end

  def deposit(_user, _amount, _currency), do: wrong_arguments()

  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, balance :: number()} | banking_error
  def withdraw(user, amount, currency)
  def withdraw("", _amount, _currency), do: wrong_arguments()
  def withdraw(_user, _amount, ""), do: wrong_arguments()

  def withdraw(user, amount, currency)
      when is_number(amount) and amount >= 0 and is_binary(user) and is_binary(currency) do
    amount
    |> ensure_decimal()
    |> then(&Users.withdraw(user, &1, currency))
  end

  def withdraw(_user, _amount, _currency), do: wrong_arguments()

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number(),
          currency :: String.t()
        ) ::
          {:ok, new_balance_from_user :: number(), new_balance_to_user :: number()}
          | banking_error

  def send(from_user, to_user, amount, currency)
  def send("", _to_user, _amount, _currency), do: wrong_arguments()
  def send(_from_user, "", _amount, _currency), do: wrong_arguments()
  def send(_from_user, _to_user, _amount, ""), do: wrong_arguments()

  def send(from_user, to_user, amount, currency)
      when is_number(amount) and amount >= 0 and is_binary(from_user) and is_binary(to_user) and
             is_binary(currency) do
    amount
    |> ensure_decimal()
    |> then(&Users.send(from_user, to_user, &1, currency))
  end

  def send(_from_user, _to_user, _amount, _currency), do: wrong_arguments()

  defp wrong_arguments, do: {:error, :wrong_arguments}

  @spec ensure_decimal(amount :: number()) :: Decimal.t()
  defp ensure_decimal(amount) do
    amount
    |> Decimal.cast()
    |> elem(1)
  end
end
