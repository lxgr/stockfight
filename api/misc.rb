class Quote

    attr_accessor :bid, :ask, :last
    @bid
    @ask
    @last

    def spread
        return @ask-@bid
    end

end
