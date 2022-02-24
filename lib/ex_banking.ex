defmodule ExBanking do
  @moduledoc """
  Documentation for `ExBanking`.
  """

  alias ExBanking.Users

  def create_user(name) do
    Users.create_user(name)
  end

  def get_balance(name, currency) do
    Users.get_balance(name, currency)
  end

  def deposit(name, amount, currency) do
    Users.deposit(name, amount, currency)
  end

  def withdraw(name, amount, currency) do
    Users.withdraw(name, amount, currency)
  end

  def send(from_user, to_user, amount, currency) do
    Users.send(from_user, to_user, amount, currency)
  end
end
