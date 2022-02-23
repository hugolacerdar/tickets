defmodule Tickets do
  # Mocked business logic

  def tickets_available?(_event) do
    Process.sleep(Enum.random(100..200))
    true
  end

  def create_ticket(_user, _event) do
    Process.sleep(Enum.random(250..1000))
  end

  def send_email(_user) do
    Process.sleep(Enum.random(100..250))
  end

  @users [
    %{id: "1", email: "only@example.com"},
    %{id: "2", email: "a@example.com"},
    %{id: "3", email: "mock@example.com"},
  ]

  def users_by_ids(ids) when is_list(ids) do
    Process.sleep(Enum.random(100..200))
    Enum.filter(@users, & &1.id in ids)
  end

  def insert_all_tickets(messages) do
    Process.sleep(Enum.count(messages) * 250)
    messages
  end
end
