defmodule ExBanking.Users do
  alias ExBanking.Users.Actions

  def create_user(name) do
    # UserWorker.start_link(name: name)
    Actions.create_user(name)
  end

  def get_balance(name, currency) do
    Actions.get_balance(name, currency)
  end

  def deposit(name, amount, currency) do
    Actions.deposit(name, amount, currency)
  end

  def withdraw(name, amount, currency) do
    Actions.withdraw(name, amount, currency)
  end

  def send(from_user, to_user, amount, currency) do
    Actions.send_to(from_user, to_user, amount, currency)
  end
end
