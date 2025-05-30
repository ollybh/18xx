# frozen_string_literal: true

module Engine
  class ShareBundle
    attr_reader :shares, :percent
    attr_accessor :share_price

    def initialize(shares, percent = nil)
      @shares = Array(shares).dup
      raise GameError, 'A share bundle must contain at least one share' if @shares.empty?
      raise GameError, 'All shares must be from the same corporation' unless @shares.map(&:corporation).uniq.one?
      raise GameError, 'All shares must be owned by the same owner' unless @shares.map(&:owner).uniq.one?

      @percent = percent || @shares.sum(&:percent)
      @share_price = nil
    end

    def num_shares(ceil: true)
      num = @percent.to_f / corporation.share_percent
      ceil ? num.ceil : num
    end

    def partial?
      @percent != @shares.sum(&:percent)
    end

    def corporation
      @shares.first.corporation
    end

    def owner
      @shares.first.owner
    end

    def president
      corporation.owner
    end

    def presidents_share
      @shares.find(&:president)
    end

    def preferred
      @shares.any?(&:preferred)
    end

    def price_per_share
      @share_price || @shares.first.price_per_share
    end

    def price
      (price_per_share * num_shares(ceil: false)).ceil
    end

    def can_dump?(entity)
      return true unless presidents_share

      sh = corporation.player_share_holders(corporate: true)
      (sh.reject { |k, _| k == entity }.values.max || 0) >= presidents_share.percent
    end

    def to_bundle
      self
    end

    def buyable
      @shares.all?(&:buyable)
    end

    def ==(other)
      [shares, percent, share_price] == [other.shares, other.percent, other.share_price]
    end

    # Percent of shares not counting preferred shares
    def common_percent
      @common_percent ||= @shares.reject(&:preferred).sum(&:percent)
    end
  end
end
