defmodule BookingsPipeline do
    use Broadway

    @producer BroadwayRabbitMQ.Producer

    @producer_config [
        queue: "bookings_queue",
        declare: [durable: true],
        on_failure: :reject_and_requeue
    ]

    def start_link(_args) do
        options = [
            name: BookingPipeline,
            producer: [
                module: {@producer, @producer_config}
            ],
            processors: [
                default: []
            ],
            batchers: [
                cinema: [],
                musical: [],
                default: []
            ]
        ]

        Broadway.start_link(__MODULE__, options)
    end

    # only use business logic here
    def handle_message(_processor, message, _context) do
        if Tickets.tickets_available?(message.data.event) do 
            case message do
                %{data: %{event: "cinema"}} = message -> Broadway.Message.put_batcher(message, :cinema)

                %{data: %{event: "musical"}} = message -> Broadway.Message.put_batcher(message, :musical)

                message -> message
            end
        else
            Broadway.Message.failed(message, "bookings-closed")
        end
    end

    # should be used only for preloading data
    def prepare_messages(messages, _context) do
        # Parse data and convert to a map.
        messages = 
            Enum.map(messages, fn message -> 
                Broadway.Message.update_data(message, fn data -> 
                    [event, user_id] = String.split(data, ",")
                    %{event: event, user_id: user_id} 
                end) 
            end)

        users = Tickets.users_by_ids(Enum.map(messages, & &1.data.user_id))

        # Put users in messages.
        Enum.map(messages, fn message -> 
            Broadway.Message.update_data(message, fn data -> 
                user = Enum.find(users, & &1.id == data.user_id)
                Map.put(data, :user, user)
            end)
        end)
    end

    def handle_failed(messages, _context) do
        IO.inspect(messages, label: "Failed messages")

        Enum.map(messages, fn
            %{status: {:failed, "bookings-closed"}} = message -> 
                Broadway.Message.configure_ack(message, on_failure: :reject)
                
            message -> message
        end)
    end
    
    def handle_batch(_batcher, messages, batch_info, _context) do
        IO.puts("#{inspect(self())} Batch #{batch_info.batcher} #{batch_info.batch_key}")

        # TODO: add format message to send
        messages
        |> Tickets.insert_all_tickets()
        |> Enum.each(fn message -> 
             channel = message.metadata.amqp_channel
             payload = "email,#{message.data.user.email}"
             AMQP.Basic.publish(channel, "", "notifications_queue", payload)
        end)

        messages
    end
end
