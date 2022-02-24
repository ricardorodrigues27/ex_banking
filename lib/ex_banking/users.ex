defmodule ExBanking.Users do
  alias ExBanking.Users.Actions

  def create_user(user) do
    Actions.create_user(user)
  end

  def get_balance(user, currency) do
    Actions.get_balance(user, currency)
  end

  def deposit(user, amount, currency) do
    Actions.deposit(user, amount, currency)
  end

  def withdraw(user, amount, currency) do
    Actions.withdraw(user, amount, currency)
  end

  def send(from_user, to_user, amount, currency) do
    Actions.send_to(from_user, to_user, amount, currency)
  end
end
