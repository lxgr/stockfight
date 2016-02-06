require 'json'
require 'httparty'

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
        raise "Error updating!" unless http_ok?(response.code)
        handle_result(order, response)
    end 

    def cancel_order(order)
        response = HTTParty.delete("#{Base_url}/venues/#{@venue}/stocks/#{@stock}/orders/#{order.id}", :headers => {"X-Starfighter-Authorization" => $apikey})
        raise "Error deleting!" unless http_ok?(response.code)
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

    def http_ok?(code)
        return code.between?(200,300)
    end
end
