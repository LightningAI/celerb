module Celerb
  class TaskPublisher

    def self.connect(opts, connection=nil)
      @channel = AMQP::Channel.new(connection)
      @default_exchange = @channel.direct(opts[:exchange],
        :key => opts[:key], :durable => true)
      @results = ResultConsumer.new @channel, opts
    end

    def self.delay_task(queue, task_name, task_args=[], task_kwargs={},
                   task_id=nil, taskset_id=nil, expires=nil, eta=nil,
                   exchange=nil, exchange_type=nil, retries=0)
      task_id ||= TaskPublisher.uniq_id
      publish(queue, {
        :task => task_name,
        :id   => task_id,
        :args => task_args,
        :kwargs  => task_kwargs,
        :retries => retries,
        :eta     => eta,
        :expires => expires
      })
      return task_id
    end

    def self.register_result_handler(task_id, expiry, &blk)
      @results.register(task_id, expiry, &blk)
    end

    private

    def self.publish(queue, body)
      exchange = @default_exchange
      if queue.kind_of? String
        exchange = @channel.direct(queue, :key => queue,
          :durable => true)
      end
      exchange.publish MessagePack.pack(body), {
        :content_type => 'application/x-msgpack',
        :content_encoding => 'binary'
      }
    end

    def self.uniq_id
      return UUID.create_v4.to_s
    end

  end
end
