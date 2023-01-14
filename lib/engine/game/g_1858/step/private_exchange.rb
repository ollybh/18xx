# frozen_string_literal: true

module Engine
  module Game
    module G1858
      module Step
        # Code shared by both the Exchange and PrivateClosure steps.
        module PrivateExchange
          def acquire_private(corporation, entity)
            player = entity.owner

            company = @game.private_company(entity)
            minor = @game.private_minor(entity)

            @game.release_stubs(minor)
            transfer_abilities(minor, company)
            minor.close!
            player.companies.delete(company)
            company.owner = corporation
            corporation.companies << company
            @log << "#{corporation.name} acquires #{company.name} from #{player.name}"
          end

          def transfer_abilities(minor, company)
            # The ability blocking other entities laying track in the private's
            # home hexes needs to survive until the private railway closes, so
            # move it from the minor to the company.
            blocker = @game.abilities(minor, :blocks_hexes)
            return unless blocker

            company.add_ability(blocker)
          end

          def exchange_for_share(bundle, corporation, minor, player)
            unless @game.corporation_private_connected?(corporation, minor)
              raise GameError, "#{minor.name} is not connected to #{corporation.full_name}"
            end

            @game.share_pool.buy_shares(player, bundle, exchange: :free)
          end

          def claim_token(corporation, minor)
            return if corporation.unplaced_tokens.empty?

            company = @game.private_company(minor)
            cities = @game.reserved_cities(corporation, company)
            return if cities.empty?

            @round.pending_tokens << {
              entity: corporation,
              hexes: cities.map(&:hex),
              token: corporation.next_token,
            }
          end
        end
      end
    end
  end
end