# frozen_string_literal: true

require 'spec_helper'

module Engine
  module RouteGraph
    describe Edge, :graph do
      subject(:edge)      { described_class.new(left_v, right_v, [plain_path]) }
      # Minimal vertex-like doubles for Edge endpoints.
      let(:left_v)        { instance_double(Engine::RouteGraph::NodeVertex, id: 'left') }
      let(:right_v)       { instance_double(Engine::RouteGraph::NodeVertex, id: 'right') }
      # Non-terminal paths (track-only).
      let(:plain_path)    { instance_double(Engine::Part::Path, terminal: nil, track: :broad) }
      # A path with a terminal marker (e.g. from a tile with terminal=2).
      let(:terminal_path) { instance_double(Engine::Part::Path, terminal: 2, track: :broad) }
      # A narrow-gauge path for gauge tests.
      let(:narrow_path)   { instance_double(Engine::Part::Path, terminal: nil, track: :narrow) }

      describe '#initialize' do
        it 'stores the left and right vertices', :aggregate_failures do
          expect(edge.left).to eq(left_v)
          expect(edge.right).to eq(right_v)
        end

        it 'stores the paths' do
          expect(edge.paths).to eq([plain_path])
        end

        it 'derives gauge from the first path' do
          expect(edge.gauge).to eq(:broad)
        end

        it 'uses the first path\'s track as gauge' do
          edge = described_class.new(left_v, right_v, [narrow_path])
          expect(edge.gauge).to eq(:narrow)
        end
      end

      describe '#ends' do
        it 'returns [left, right]' do
          expect(edge.ends).to eq([left_v, right_v])
        end
      end

      describe '#linked?' do
        it 'returns true for the left vertex' do
          expect(edge).to be_linked(left_v)
        end

        it 'returns true for the right vertex' do
          expect(edge).to be_linked(right_v)
        end

        it 'returns false for an unrelated vertex' do
          other = instance_double(Engine::RouteGraph::NodeVertex, id: 'other')
          expect(edge).not_to be_linked(other)
        end
      end

      describe '#other_end' do
        it 'returns right when given left' do
          expect(edge.other_end(left_v)).to eq(right_v)
        end

        it 'returns left when given right' do
          expect(edge.other_end(right_v)).to eq(left_v)
        end

        it 'returns left when left == right (loop edge)' do
          loop_edge = described_class.new(left_v, left_v, [plain_path])
          expect(loop_edge.other_end(left_v)).to eq(left_v)
        end

        it 'raises GameError for an unlinked vertex' do
          other = instance_double(Engine::RouteGraph::NodeVertex, id: 'other')
          expect { edge.other_end(other) }
            .to raise_error(Engine::GameError, /not linked/)
        end
      end

      describe '#paths_from' do
        subject(:edge) { described_class.new(left_v, right_v, [plain_path, narrow_path]) }

        it 'returns @paths in forward order for the left vertex' do
          expect(edge.paths_from(left_v)).to eq([plain_path, narrow_path])
        end

        it 'returns @paths in reverse order for the right vertex' do
          expect(edge.paths_from(right_v)).to eq([narrow_path, plain_path])
        end

        it 'raises GameError for an unlinked vertex' do
          other = instance_double(Engine::RouteGraph::NodeVertex, id: 'other')
          expect { edge.paths_from(other) }
            .to raise_error(Engine::GameError, /not linked/)
        end
      end

      describe '#paths_to' do
        subject(:edge) { described_class.new(left_v, right_v, [plain_path, narrow_path]) }

        it 'returns @paths in reverse order for the left vertex' do
          expect(edge.paths_to(left_v)).to eq([narrow_path, plain_path])
        end

        it 'returns @paths in forward order for the right vertex' do
          expect(edge.paths_to(right_v)).to eq([plain_path, narrow_path])
        end

        it 'raises GameError for an unlinked vertex' do
          other = instance_double(Engine::RouteGraph::NodeVertex, id: 'other')
          expect { edge.paths_to(other) }
            .to raise_error(Engine::GameError, /not linked/)
        end
      end

      describe '#terminal?' do
        it 'returns false when no paths are terminal' do
          edge = described_class.new(left_v, right_v, [plain_path, plain_path])
          expect(edge).not_to be_terminal
        end

        it 'returns true when any path is terminal' do
          edge = described_class.new(left_v, right_v, [plain_path, terminal_path])
          expect(edge).to be_terminal
        end
      end
    end
  end
end
