#!/usr/bin/env ruby

require_relative 'sfconfig'
require_relative 'api/api'

class MarketMaker
    
    def initialize(apikey, account, venue, stock, maxinv)
        @client = StockClient.new(apikey, account, venue, stock)
        @inv = 0
        @maxinv = maxinv
    end

    def makemarket!
        last = @client.quote.last

        while true do
            open = TxList.new
            spread = (last/100)-4
            bid = last-(spread/2)
            ask = last+(spread/2)
            nask = [1,@maxinv + @inv].max
            nbid = [1,@maxinv - @inv].max
            puts "Bid #{nbid}@#{bid}, ask #{nask}@#{ask} – @spread #{ask-bid}"
            if (nbid > 0)
                open.insert(Order.new(@client, nbid, bid, "buy", "limit"))
            end
            if (nask > 0)
                open.insert(Order.new(@client, nask, ask, "sell", "limit"))
            end
            open.post_all!

            while true do
                # As we always have at least one order for each side on the book,
                # we are guaranteed to find out about any price moves.
                # (But not about market makers with a narrower spread...)
                sleep 1
                open.update_all!
                if (open.total_fills > 0)
                    break
                end
            end

            open.cancel_all!
            @inv += open.pos_shares

            # The new mid price is the weighted average of all executed
            # transactions for the outstanding orders.
            last = open.avg_fill

            # Failsafe. This should only be reached after extreme
            # price swings or implementation bugs...
            puts "Current inv: #{@inv}"
            if (@inv.abs > 2*@maxinv)
                puts "That's too much, please fix it!"
                break
            end
        end
    end

end
        

if __FILE__ == $0
    # Replace the arguments with your own values!
    MarketMaker.new($apikey, $account, $venue, $stock, $maxinv).makemarket!
end
