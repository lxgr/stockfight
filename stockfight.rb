#!/usr/bin/env ruby

require 'rubygems'
require 'httparty'
require 'json'
require_relative 'sfconfig'

$account = "YAN34122142"
$venue = "GFDEX"
$stock = "HNH"

class TxList
    def initialize
        @orders = []
    end

    def insert(order)
        @orders << order
        return order
    end

    def remove(order)
        return @orders.delete(order)
    end

    def update_all!
        @orders.map(&:update!)
    end

    def post_all!
        @orders.map(&:post!)
    end

    def cancel_all!
        @orders.map(&:cancel!)
    end

    def sum_all(orders, method)
        orders.inject(0){|sum,o| sum += o.send method}
    end

    def total_fills
        return total_fills_for(@orders)
    end

    def total_fills_for(orders)
        return sum_all(orders, :nfilled)
    end

    def total_value_for(orders)
        return sum_all(orders, :filled_value)
    end

    def buys
        return @orders.select{|o|o.direction == "buy"}
    end

    def sells
        return @orders.select{|o|o.direction == "sell"}
    end

    def pos_shares
        return total_fills_for(buys)-total_fills_for(sells)
    end

    def pos_money
        return total_value_for(sells)-total_value_for(buys)
    end

    def to_s
        return "Got #{pos_shares} of #{$stock}, cash balance #{pos_money}"
    end
end

class Quote

    attr_accessor :bid, :ask, :last
    @bid
    @ask
    @last

    def spread
        return @ask-@bid
    end

end

class StockClient

    Base_url = "https://api.stockfighter.io/ob/api"
    
    def initialize(apikey, account, venue, stock)
        @apikey = apikey
        @account = account
        @venue = venue
        @stock = stock
    end

    def quote
        response = JSON.parse(HTTParty.get("#{Base_url}/venues/#{$venue}/stocks/#{$stock}/quote", :headers => {"X-Starfighter-Authorization" => $apikey}).body)
        q = Quote.new
        q.bid = response["bid"]
        q.ask = response["ask"]
        q.last = response["last"]
        return q
    end
        

    def post_order(order)
        response = HTTParty.post("#{Base_url}/venues/#{@venue}/stocks/#{@stock}/orders",
                    :body => order_to_json(order),
                    :headers => {"X-Starfighter-Authorization" => @apikey})
        handle_result(order, response)
    end

    def update_order(order)
        response = HTTParty.get("#{Base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{order.id}", :headers => {"X-Starfighter-Authorization" => @apikey})
        raise "Error updating!" unless response.code.between?(200,300)
        handle_result(order, response)
    end 

    def cancel_order(order)
        response = HTTParty.delete("#{Base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{order.id}", :headers => {"X-Starfighter-Authorization" => $apikey})
        raise "Error deleting!" unless response.code.between?(200,300)
        handle_result(order, response)
    end
        
    private

    def handle_result(order, response)
        result = JSON.parse(response.body)
        order.handle_response!(validate_response(result))
    end

    def validate_response(response)
        # TODO: Check if all required fields are there
        return response
    end
    
    def order_to_json(order)
        json = {
          "account" => @account,
          "venue" => order.venue,
          "symbol" => order.symbol,
          "price" => order.limit,
          "qty" => order.amount,
          "direction" => order.direction,
          "orderType" => order.type
        }
        return JSON.generate(json)
    end
end

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

$db = TxList.new


if __FILE__ == $0
# Trivial market-making bot

    client = StockClient.new($apikey, $account, $venue, $stock)
    inv = 0
    maxinv = 300

    while true do
        open = TxList.new
        last = client.quote.last
        spread = (last/100)-4
        bid = last-(spread/2)
        ask = last+(spread/2)
        nask = [1,maxinv + inv].max
        nbid = [1,maxinv - inv].max
        puts "Bid #{nbid}@#{bid}, ask #{nask}@#{ask} – @spread #{ask-bid}"
        if (nbid > 0)
            open.insert(Order.new(client, nbid, bid, "buy", "limit"))
        end
        if (nask > 0)
            open.insert(Order.new(client, nask, ask, "sell", "limit"))
        end
        open.post_all!

        while true do
            # TODO: We can probably get stuck here! Timeout?
            sleep 1
            open.update_all!
            if (open.total_fills > 0)
                break
            end
        end

        open.cancel_all!
        inv += open.pos_shares

        puts "Current inv: #{inv}"
        if inv.abs > 2*maxinv
            puts "That's too much, please fix it!"
            break
        end
    end

end
