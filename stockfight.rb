#!/usr/bin/env ruby

require 'rubygems'
require 'httparty'
require 'json'

$base_url = "https://api.stockfighter.io/ob/api"
$account = "SAP44392652"
$venue = "WMOPEX"
$stock = "XOPO"
$db

class TxDb
    def initialize
        @orders = []
    end

    def insert(order)
        @orders << order
    end

    def update_all!
        @orders.map(&:update!)
    end

    def cancel_all!
        @orders.each do |o| o.cancel! end
    end

    def sum_all(orders, method)
        orders.inject(0){|sum,o| sum += o.send method}
    end

    def total_fills(orders)
        return sum_all(orders, :nfilled)
    end

    def total_value(orders)
        return sum_all(orders, :filled_value)
    end

    def buys
        return @orders.select{|o|o.direction == "buy"}
    end

    def sells
        return @orders.select{|o|o.direction == "sell"}
    end

    def pos_shares
        return total_fills(buys)-total_fills(sells)
    end

    def pos_money
        return total_value(sells)-total_value(buys)
    end

    def to_s
        return "Got #{pos_shares} of #{$stock}, cash balance #{pos_money}"
    end
end

class Quote

    attr_reader :bid, :ask, :last

    def initialize
        @data = JSON.parse(HTTParty.get("#{$base_url}/venues/#{$venue}/stocks/#{$stock}/quote",
                            :headers => {"X-Starfighter-Authorization" => $apikey}).body)
        @bid = @data["bid"]
        @ask = @data["ask"]
        @last = @data["last"]
    end 

    def spread
        return @ask-@bid
    end

end

class Order

        attr_reader :nfilled, :direction, :limit

    def initialize(amount, limit = 0, direction = "buy", type = "market")
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
        #return if @status == :done
        response = HTTParty.get("#{$base_url}/venues/#{$venue}/stocks/#{$stock}/orders/#{@id}", :headers => {"X-Starfighter-Authorization" => $apikey})
        raise "Error updating!" unless response.code == 200
        handle_update!(JSON.parse(response.body))
    end

    def postOrder(json)
        response = HTTParty.post("#{$base_url}/venues/#{$venue}/stocks/#{$stock}/orders",
                    :body => json,
                    :headers => {"X-Starfighter-Authorization" => $apikey})
        return response.body
    end

    def to_json
        json = {
          "account" => $account,
          "venue" => @venue,
          "symbol" => @symbol,
          "price" => @limit,
          "qty" => @amount,
          "direction" => @direction,
          "orderType" => @type
        }
        return JSON.generate(json)
    end

    def post!
        raise "Already posted!" if @status != :prepared
        result = postOrder(to_json)
        response = JSON.parse(result)
        @id = response["id"]
        handle_response!(response)
        $db.insert self
    end

    def cancel!
        return if @status != :open
        response = HTTParty.delete("#{$base_url}/venues/#{$venue}/stocks/#{$stock}/orders/#{@id}",
                    :headers => {"X-Starfighter-Authorization" => $apikey})
        handle_response! response
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

    private 

    def handle_response!(response)
        raise "Rejected TX" if !response["ok"]
        handle_update! response
    end

    def handle_update!(resp)
        raise "Missing status" unless resp.has_key?("open")
        if resp["open"]
            @status = :open
        else
            @status = :closed
        end
        
        @nfilled = resp["totalFilled"]
        @fills = resp["fills"]
    end

end

$db = TxDb.new


if __FILE__ == $0
# Trivial market-making bot

    size = 10
    q = Quote.new
    last = q.last
    inv = 0
    maxinv = 300

    while true do
        spread = (last/100)-4
        bid = last-(spread/2)
        ask = last+(spread/2)
        nbid = [1,maxinv + inv].max
        nask = [1,maxinv - inv].max
        puts "Bid #{nbid}@#{bid}, ask #{nask}@#{ask} – @spread #{ask-bid}"
        obid = Order.new(nbid, bid, "sell", "limit")
        oask = Order.new(nask, bid, "buy", "limit")
        obid.post!
        oask.post!

        recalc = false
        while true do
            sleep 1
            obid.update!
            oask.update!

            # Did someone buy?
            if (oask.nfilled > 0 && obid.nfilled > 0)
                puts "We bought AND sold at #{last}, keeping it as it is"
                break
            end
            if (oask.nfilled > 0)
                last = oask.closest_fill
                puts "We bought at #{last}"
                break
            end
            if (obid.nfilled > 0)
                last = obid.closest_fill
                puts "We sold at #{last}"
                break
            end
        end

        obid.cancel!
        oask.cancel!
        inv += oask.nfilled
        inv -= obid.nfilled

        puts "Current inv: #{inv}"
        if inv.abs > 2*maxinv
            puts "That's too much, please fix it!"
            break
        end
    end

end
