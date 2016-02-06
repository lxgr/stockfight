class Order

        attr_reader :nfilled, :direction, :limit, :amount, :type, :symbol, :venue, :id

    def initialize(client, amount, limit = 0, direction = "buy", type = "market")
        @client = client
        @symbol = $stock
        @venue = $venue
        @amount = amount
        @limit = limit
        @direction = direction
        @type = type
        @status = :prepared
        @nfilled = 0
        @id
    end

    def update!
        raise "Not yet posted!" if @status == :prepared
        return if @status == :closed
        @client.update_order(self)
    end

    def post!
        raise "Already posted!" if @status != :prepared
        @client.post_order(self)
    end

    def cancel!
        return if @status != :open
        @client.cancel_order(self)
    end

    def is_open?
        return @status == :open
    end

    def filled_value
        return @fills.inject(0){|sum, elem|sum+elem["price"]*elem["qty"]}
    end

    def closest_fill
        return @fills.map{|el|el["price"]}.min_by{|p|(limit-p).abs}
    end

    def to_s
        return inspect
    end

    def handle_response!(resp)
        raise "Missing status" unless resp.has_key?("open")
        if resp["open"]
            @status = :open
        else
            @status = :closed
        end
        @nfilled = resp["totalFilled"]
        @fills = resp["fills"]
        @id = resp["id"]
    end 

end
