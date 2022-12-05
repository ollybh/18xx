# frozen_string_literal: true

require_relative '../../../step/dividend'

module Engine
  module Game
    module G21Moon
      module Step
        class Dividend < Engine::Step::Dividend
          def actions(_entity)
            []
          end

          # this is always called, there are no dividend choices in 21Moon
          def skip!
            sp = @game.sp_revenue(routes)
            lb = @game.lb_revenue(routes)
            kind = if sp.zero?
                     'withhold'
                   elsif lb.zero?
                     'payout'
                   else
                     'half'
                   end

            current_entity.operating_history[[@game.turn, @round.round_num]] =
              OperatingInfo.new(routes, @game.actions.last, sp + lb, @round.laid_hexes, dividend_kind: kind)

            process_dividend(Action::Dividend.new(current_entity, kind: kind))
          end

          def process_dividend(action)
            entity = action.entity
            lb_revenue = @game.lb_revenue(routes)
            sp_revenue = @game.sp_revenue(routes)

            payout = share_price_change(entity, sp_revenue)

            @round.routes = []

            @log << "#{entity.name} withholds #{@game.format_currency(lb_revenue)}" if lb_revenue.positive?

            @log << "#{entity.name} does not run" if !sp_revenue.positive? && !lb_revenue.positive?

            payout_corporation(lb_revenue, entity)
            payout_shares(entity, sp_revenue) if sp_revenue.positive?

            change_share_price(entity, payout)

            pass!
          end

          def share_price_change(entity, revenue)
            if revenue >= 2 * entity.share_price.price
              { share_direction: :right, share_times: 2 }
            elsif revenue >= entity.share_price.price / 2
              { share_direction: :right, share_times: 1 }
            elsif !revenue.positive?
              { share_direction: :left, share_times: 1 }
            else
              {}
            end
          end
        end
      end
    end
  end
end
