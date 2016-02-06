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

    def has_buy_fills
        return total_fills_for(buys) > 0
    end

    def has_sell_fills
        return total_fills_for(sells) > 0
    end

    def total_fills_for(orders)
        return sum_all(orders, :nfilled)
    end

    def total_value_for(orders)
        return sum_all(orders, :filled_value)
    end

    def avg_fill
        return total_value_for(@orders)/total_fills_for(@orders)
    end

    def best_buy_fill
        return buys.map(&:closest_fill).min
    end

    def best_sell_fill
        return sells.map(&:closest_fill).max
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
