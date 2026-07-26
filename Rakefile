# frozen_string_literal: true

unless ENV['RACK_ENV'] == 'production'
  require 'parallel_tests'
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
  require_relative 'lib/assets'

  # Specs
  RSpec::Core::RakeTask.new(:spec)
  RuboCop::RakeTask.new do |task|
    task.requires << 'rubocop-performance'
  end

  desc 'Build the main JavaScript files'
  task :compile do
    Assets.new.combine
  end

  desc 'Build the main JavaScript files and all game-specific files'
  task :compile_all do
    Assets.new.combine(:all)
  end

  desc 'Run spec in parallel'
  task :spec_parallel do
    ParallelTests::CLI.new.run(['--type', 'rspec'])
  end

  task default: %i[compile spec_parallel rubocop]

  desc 'Check YARD documentation coverage and warnings'
  task :yard_check do
    sh 'yard stats --no-cache --fail-on-warning --protected --no-private {lib,assets}/**/*.rb'
  end

  namespace :route_graph do
    # Require the comparator once, inside the namespace so it's only
    # loaded on demand.
    def self.require_comparator
      require_relative 'lib/engine'
      require_relative 'lib/engine/route_graph/comparator'
    end

    def self.require_db
      require 'require_all'
      require_relative 'db'
      require_relative 'models'
      require_rel './models'
    end

    def self.print_entity_line(r, label: nil)
      status = r[:match] ? '✓' : '✗'
      t = r[:timing]
      id = label || r[:entity]
      line = "#{status} #{id}"
      line << "  old: #{t[:old]}μs"
      line << "  build: #{t[:new_build]}μs"
      line << "  walk: #{t[:new_walk]}μs"
      line << "  #{call_stats(r)}"
      line << " ERROR: #{r[:error]}" if r[:error]
      puts line
    end

    def self.print_diffs(r)
      %i[connected_nodes connected_paths reachable_hexes].each do |key|
        d = r[key]
        next if d[:extra].empty? && d[:missing].empty?

        puts "  #{key}: +#{d[:extra].size} / -#{d[:missing].size}"
      end
    end

    def self.print_detail_diffs(r, indent: '')
      %i[connected_nodes connected_paths reachable_hexes].each do |key|
        d = r[key]
        next if d[:extra].empty? && d[:missing].empty?

        puts "#{indent}#{key}:"
        d[:extra].each { |v| puts "#{indent}  + #{v}" }
        d[:missing].each { |v| puts "#{indent}  - #{v}" }
      end
    end

    def self.print_compare_results(results)
      if results.empty?
        puts 'No active entities to compare.'
        return
      end
      results.each_value do |r|
        print_entity_line(r)
        print_diffs(r) unless r[:match]
      end
      mismatches = results.count { |_, r| !r[:match] }
      puts "--- #{results.size} entities, #{mismatches} mismatches ---"
    end

    def self.print_replay_results(results)
      total_actions = results.keys.max
      mismatches = total_old_t = total_build_t = total_walk_t = 0
      total_old_calls = total_old_skipped = 0
      total_new_calls = total_new_skipped = total_new_edges = total_new_edges_skipped = 0
      entity_checks = 0
      results.sort_by { |action, _| action }.each do |action, entities|
        next if entities.empty?

        action_mismatches = entities.count { |_, r| !r[:match] }
        mismatches += action_mismatches
        prefix = action_mismatches.zero? ? '✓' : '✗'
        puts "#{prefix} Action #{action}/#{total_actions} " \
             "(#{entities.size} entities, " \
             "#{action_mismatches} mismatches)"

        entities.each do |eid, r|
          entity_checks += 1
          t = r[:timing]
          total_old_t += t[:old]
          total_build_t += t[:new_build]
          total_walk_t += t[:new_walk]
          total_old_calls += r[:walk_calls][:old][:all]
          total_old_skipped += r[:walk_calls][:old][:skipped]
          total_new_calls += r[:walk_calls][:new][:dfs_calls]
          total_new_skipped += r[:walk_calls][:new][:skipped].values.sum
          total_new_edges += r[:walk_calls][:new][:edges_traversed]
          total_new_edges_skipped += r[:walk_calls][:new][:edges_skipped].values.sum
          next if r[:match]

          puts "     #{eid}  old: #{t[:old]}μs  " \
               "build: #{t[:new_build]}μs  " \
               "walk: #{t[:new_walk]}μs"
          print_detail_diffs(r, indent: '       ')
        end
      end
      check_count = results.size
      return puts '=== No results ===' if check_count.zero?

      avg_old = total_old_t / check_count
      avg_build = total_build_t / check_count
      avg_walk = total_walk_t / check_count
      old_skip_pct = total_old_calls.zero? ? 0 : (100 * total_old_skipped / total_old_calls)
      new_skip_pct = total_new_calls.zero? ? 0 : (100 * total_new_skipped / total_new_calls)
      puts "=== Total: #{mismatches} mismatches across #{check_count} checkpoints ==="
      puts "    #{entity_checks} entity-checks"
      puts "    old: #{total_old_t}μs  build: #{total_build_t}μs  walk: #{total_walk_t}μs"
      puts "    avg: #{avg_old}μs / #{avg_build}μs / #{avg_walk}μs"
      puts '    total calls: ' \
           "old: #{total_old_calls} (skipped #{old_skip_pct}%), " \
           "new: #{total_new_calls} (skipped #{new_skip_pct}%), " \
           "edges walked: #{total_new_edges} (skipped #{total_new_edges_skipped})"
    end

    # Builds a single-line stats summary showing the method call comparison of
    # the old and new graphs.
    def self.call_stats(comparison)
      # Old shape: { all:, skipped:, not_skipped: }
      # New shape: { time:, dfs_calls:, skipped: {reason=>n},
      #              edges_traversed:, edges_skipped: {reason=>n} }
      old, new = comparison[:walk_calls].fetch_values(:old, :new)
      return '' if !old || !new

      old_skip_pct = old[:all].zero? ? 0 : (100 * old[:skipped] / old[:all])
      new_skip_pct = new[:dfs_calls].zero? ? 0 : (100 * new[:skipped].values.sum / new[:dfs_calls])

      'calls: ' \
        "old: #{old[:all]} (skipped #{old_skip_pct}%), " \
        "new: #{new[:dfs_calls]} (skipped #{new_skip_pct}%), " \
        "edges walked: #{new[:edges_traversed]} (skipped #{new[:edges_skipped].values.sum})"
    end

    # Runs a block of code repeatedly and outputs timing statistics.
    def self.benchmark(timed_loops: 20, warmup_loops: 3, label: '', &block)
      timings = []
      warmup_loops.times { yield block }
      timed_loops.times do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
        yield block
        finish = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
        timings << (finish - start)
      end
      mean = timings.sum / timings.size
      median = timings.sort[timings.size / 2]
      min, max = timings.minmax
      puts "#{label}mean #{mean}μs, median #{median}μs, min #{min}μs, max #{max}μs"
    end

    desc 'Compare graphs for a game at its final state (usage: rake route_graph:compare[id])'
    task :compare, [:id] do |_t, args|
      require_comparator
      require_db
      game = Engine::Game.load(args[:id].to_i)
      results = Engine::RouteGraph::Comparator.compare_all(game)
      puts "=== Game #{args[:id]} (#{game.class.title}) ==="
      print_compare_results(results)
    end

    desc 'Replay a game from a fixture JSON file (usage: rake route_graph:replay_file[path,interval])'
    task :replay_file, %i[path interval] do |_t, args|
      require_comparator
      interval = (args[:interval] || 10).to_i
      puts "=== Replaying #{File.basename(args[:path])} (interval: #{interval}) ==="
      results = Engine::RouteGraph::Comparator.compare_replay(
        args[:path], interval: interval
      )
      print_replay_results(results)
    end

    desc 'Replay a game and compare graphs at intervals (usage: rake route_graph:replay[id,interval])'
    task :replay, %i[id interval] do |_t, args|
      require_comparator
      require_db
      id = args[:id].to_i
      interval = (args[:interval] || 10).to_i
      puts "=== Replaying game #{id} (interval: #{interval}) ==="
      results = Engine::RouteGraph::Comparator.compare_replay(
        id, interval: interval
      )
      print_replay_results(results)
    end

    desc 'Compare graphs from a fixture JSON file (usage: rake route_graph:compare_file[path])'
    task :compare_file, [:path] do |_t, args|
      require_comparator
      game = Engine::Game.load(args[:path])
      results = Engine::RouteGraph::Comparator.compare_all(game)
      puts "=== #{File.basename(args[:path])} (#{game.class.title}) ==="
      if results.empty?
        puts 'All match — no mismatches.'
      else
        results.each_value do |r|
          print_entity_line(r)
          print_diffs(r) unless r[:match]
        end
        mismatches = results.count { |_, r| !r[:match] }
        puts "--- #{results.size} entities, #{mismatches} mismatches ---"
      end
    end

    desc 'Compare graphs for all fixtures of a title (usage: rake route_graph:fixtures[1846])'
    task :fixtures, [:title] do |_t, args|
      require_comparator
      title = args[:title]
      dir = "public/fixtures/#{title}"
      files = Dir.glob("#{dir}/*.json")
      raise "No fixtures found in #{dir}/" if files.empty?

      total_mismatches = total_old_t = total_build_t = total_walk_t = 0
      entity_checks = 0
      files.sort.each do |file|
        game = Engine::Game.load(file)
        results = Engine::RouteGraph::Comparator.compare_all(game)
        mismatches = results.count { |_, r| !r[:match] }
        total_mismatches += mismatches
        results.each_value do |r|
          entity_checks += 1
          t = r[:timing]
          total_old_t += t[:old]
          total_build_t += t[:new_build]
          total_walk_t += t[:new_walk]
        end
        prefix = mismatches.zero? ? '✓' : '✗'
        puts "#{prefix} #{File.basename(file)} (#{results.size} entities, #{mismatches} mismatches)"
      rescue StandardError => e
        puts "✗ #{File.basename(file)} ERROR: #{e.message}"
      end
      avg_old = total_old_t / entity_checks
      avg_build = total_build_t / entity_checks
      avg_walk = total_walk_t / entity_checks
      puts "=== #{files.size} fixtures, #{total_mismatches} total mismatches ==="
      puts "    #{entity_checks} entity-checks"
      puts "    old: #{total_old_t}μs  build: #{total_build_t}μs  walk: #{total_walk_t}μs"
      puts "    avg: #{avg_old}μs / #{avg_build}μs / #{avg_walk}μs"
    end

    desc 'Benchmark graph calculation times on a game'
    task :benchmark, [:id, :entity] do |_t, args|
      require_comparator
      require_db

      game = Engine::Game.load(args[:id].to_i)
      entity = game.corporation_by_id(args[:entity])
      graph = Engine::RouteGraph::Graph.new(game, statistics: false)
      walker = Engine::RouteGraph::GraphWalker.new(graph, entity, statistics: false)

      benchmark(label: 'build: ') { graph.rebuild! }
      benchmark(label: 'walk:  ') do
        graph.invalidate!
        walker.reachable_hexes
      end

      # carry out one run with statisics to show the walk call counts
      walker = Engine::RouteGraph::GraphWalker.new(graph, entity, statistics: true)
      walker.reachable_hexes
      stats = walker.statistics
      skip_pct = 100 * stats[:skipped].values.sum / stats[:dfs_calls]
      puts "dfs calls: #{stats[:dfs_calls]} (skipped #{skip_pct}%), " \
           "edges walked: #{stats[:edges_traversed]} " \
           "(skipped #{stats[:edges_skipped].values.sum})"
    end
  end

end
migrate = lambda do |env, version, truncate = false|
  ENV['RACK_ENV'] = env
  require_relative 'db'
  require 'logger'
  Sequel.extension :migration
  DB.loggers << Logger.new($stdout) if DB.loggers.empty?
  DB[:actions].truncate if truncate && DB.tables.include?(:actions)
  Sequel::Migrator.apply(DB, 'migrate', version)
end

desc 'Migrate development database to latest version'
task :dev_up do
  migrate.call('development', nil)
end

desc 'Migrate development database to version x (0 if no arg given)'
task :dev_down, [:version] do |_t, args|
  migrate.call('development', args[:version].to_i, true)
end

desc 'Migrate development database down to version x (0 if no arg given) and then back up'
task :dev_bounce, [:version] do |_t, args|
  migrate.call('development', args[:version].to_i, true)
  Sequel::Migrator.apply(DB, 'migrate')
end

desc 'Migrate production database to latest version'
task :prod_up do
  migrate.call('production', nil)
end

desc 'irb with -I lib/ -I assets/app/'
task :irb do
  sh 'irb -I lib/ -I assets/app/'
end

# Shell

irb = proc do |env|
  ENV['RACK_ENV'] = env
  trap('INT', 'IGNORE')
  dir, base = File.split(FileUtils::RUBY)
  cmd = if base.sub!(/\Aruby/, 'irb')
          File.join(dir, base)
        else
          "#{FileUtils::RUBY} -S irb"
        end
  sh "#{cmd} -r ./models"
end

desc 'Open irb shell in test mode'
task :test_irb do
  irb.call('test')
end

desc 'Open irb shell in development mode'
task :dev_irb do
  irb.call('development')
end

desc 'Open irb shell in production mode'
task :prod_irb do
  irb.call('production')
end

# Other

desc 'Annotate Sequel models'
task 'annotate' do
  ENV['RACK_ENV'] = 'development'
  require_relative 'models'
  DB.loggers.clear
  require 'sequel/annotate'
  Sequel::Annotate.annotate(Dir['models/*.rb'])
end

desc 'Precompile assets for production'
task :precompile do
  require_relative 'lib/assets'
  assets = Assets.new(cache: false, compress: true, gzip: true)
  assets.combine(:all)

  # Copy to the pin directory
  git_rev = `git rev-parse --short HEAD`.strip
  version_epochtime = Time.now.strftime('%s')
  pin_dir = Assets::OUTPUT_BASE + Assets::PIN_DIR
  File.write(Assets::OUTPUT_BASE + '/assets/version.json', JSON.dump(
    hash: git_rev,
    url: "https://github.com/tobymao/18xx/commit/#{git_rev}",
    version_epochtime: version_epochtime,
  ))
  FileUtils.mkdir_p(pin_dir)
  assets.pin("#{pin_dir}#{git_rev}.js.gz")

  assets.clean_intermediate_output_files
end

desc 'Profile loading data'
task 'stackprof', [:json] do |_task, args|
  require 'stackprof'
  require_relative 'lib/engine'
  starttime = Time.new
  StackProf.run(mode: :cpu, out: 'stackprof.dump', raw: true, interval: 10) do
    10.times do
      Engine::Game.load(args[:json])
    end
  end
  endtime = Time.new
  puts "#{endtime - starttime} seconds"
end

desc 'Migrate JSON'
task 'migrate_json', [:json] do |_task, args|
  require_relative 'models'
  require_relative 'lib/engine'
  require_relative 'migrate_game'
  migrate_json(args[:json])
end

desc 'Format and compress fixtures matching public/fixtures/*/<id>.json'
task 'fixture_format', [:id, :pretty] do |_task, args|
  Dir.glob("public/fixtures/*/#{args[:id]}.json").each do |filename|
    format_fixture_json(filename, pretty: args[:pretty])
  end
end

def format_fixture_json(filename, pretty: nil)
  orig_text = File.read(filename)
  data = JSON.parse(orig_text)

  settings = data['fixture_format'] || {}

  # remove player names
  data['players'].each.with_index do |player, index|
    player['name'] = "Player #{index + 1}" unless /^(Player )?(\d+|[A-Z])$/.match?(player['name'])
  end

  data['user'] = { 'id' => 0, 'name' => 'You' } unless settings['keep_user']
  data['description'] = '' unless settings['keep_description']

  # remove or  chats, unless chat arg was "keep"
  if settings['chat'] == 'scrub'
    data['actions'].each do |action|
      action['message'] = 'chat' if action['type'] == 'message'
    end
  elsif settings['chat'] != 'keep'
    data['actions'].filter! do |action|
      action['type'] != 'message'
    end
  end

  data['result'].transform_values!(&:to_i)

  if data['game_end_reason'].nil?
    game = Engine::Game.load(data).maybe_raise!
    data['game_end_reason'] = game.game_end_reason
  end

  # TODO: get rid of undone actions

  # if 'pretty' arg is given, any value other than "0" will produce
  # readable/diffable JSON; if arg is not given or is "0", the JSON will be
  # compressed to a single line with minimal whitespace
  if !pretty.nil? && pretty != '0'
    out_text = JSON.pretty_generate(data)
    return if out_text == orig_text

    File.write(filename, out_text)
    puts "Wrote #{filename} in \"pretty\" format"
    puts 'Use `make fixture_format` to compress it and all other fixtures before submitting a PR'
  else
    out_text = data.to_json
    return if out_text == orig_text

    File.write(filename, out_text)
    puts "Wrote #{filename}"
  end
end

desc 'Add game from DB to fixtures/, downloading it if necessary'
task 'fixture_import', [:id] do |_task, args|
  require_relative 'db'
  require_relative 'scripts/import_game'

  # get game from DB
  retried = false
  begin
    game_id = args[:id].to_i
    db_game = ::Game[game_id]
    raise "Cannot find game in local DB: #{game_id}" if db_game.nil?

    puts 'Found game in local DB'
  rescue RuntimeError => e
    raise e if retried

    # if game wasn't in DB, import to DB from 18xx.games API, then try once
    # more
    puts 'Downloading game from 18xx.games...'
    import_game(game_id)
    retried = true
    retry
  end

  game = Engine::Game.load(db_game)

  # get the game data needed to dump game to JSON
  game_data = db_game.to_h
  game_data[:actions] = game.raw_actions.map(&:to_h)

  # this is required for opening fixtures in the browser at /fixture/<title>/<id>
  game_data[:loaded] = true

  user = 1000
  group = 1000

  # ensure proper fixtures dir exists
  dir = File.join('public', 'fixtures', game.meta.fixture_dir_name)
  FileUtils.mkdir_p(dir)
  FileUtils.chown(user, group, dir)

  # dump game to JSON file
  filename = File.join(dir, "#{game_id}.json")
  File.write(filename, JSON.pretty_generate(game_data))
  FileUtils.chown(user, group, filename)

  format_fixture_json(filename, pretty: true)

  sh "git add '#{filename}'"
end

desc 'Refresh the upstream disposable email blocklist (preserves custom additions below the marker)'
task 'disposable:refresh' do
  require 'net/http'
  require_relative 'lib/disposable_email'

  url = URI('https://raw.githubusercontent.com/disposable-email-domains/' \
            'disposable-email-domains/main/disposable_email_blocklist.conf')
  upstream = Net::HTTP.get(url).strip
  raise 'empty upstream response' if upstream.empty?

  path = DisposableEmail::PATH
  marker = DisposableEmail::MARKER

  custom = "#{marker}\n"
  if File.exist?(path)
    lines = File.read(path).lines
    idx = lines.index { |line| line.strip == marker }
    custom = lines[idx..].join if idx
  end

  File.write(path, "#{upstream}\n#{custom}")
  puts "Refreshed #{path}"
end

desc 'Mine the disposable list for shared MX backends (candidates for BANNED_MX_DOMAINS)'
task 'disposable:mx_cluster', [:min] do |_task, args|
  require 'resolv'
  require_relative 'lib/disposable_email'

  min = (args[:min] || 5).to_i
  domains = File.foreach(DisposableEmail::PATH)
                .map { |line| line.strip.downcase }
                .reject { |d| d.empty? || d.start_with?('#') }
                .uniq
  parent = ->(host) { host.to_s.downcase.chomp('.').split('.').last(2).join('.') }

  queue = Queue.new
  domains.each { |d| queue << d }
  counts = Hash.new { |h, k| h[k] = { n: 0, examples: [] } }
  mutex = Mutex.new

  workers = Array.new(40) do
    Thread.new do
      loop do
        domain = begin
          queue.pop(true)
        rescue ThreadError
          break
        end
        hosts = begin
          Resolv::DNS.open do |dns|
            dns.timeouts = 2
            dns.getresources(domain, Resolv::DNS::Resource::IN::MX).map { |mx| mx.exchange.to_s }
          end
        rescue StandardError
          []
        end
        next if hosts.empty?

        mutex.synchronize do
          hosts.map { |h| parent.call(h) }.uniq.each do |p|
            counts[p][:n] += 1
            counts[p][:examples] << domain if counts[p][:examples].size < 5
          end
        end
      end
    end
  end
  workers.each(&:join)

  banned = DisposableEmail::BANNED_MX_DOMAINS
  puts "# mx_backend | disposable_domains | examples  (>= #{min}; * already banned)"
  counts.select { |_, v| v[:n] >= min }.sort_by { |_, v| -v[:n] }.each do |p, v|
    puts "#{p} | #{v[:n]} | #{v[:examples].join(', ')}#{banned.include?(p) ? ' *' : ''}"
  end
  puts "\nReview before adding -- EXCLUDE legit shared infra (cloudflare.net, google.com, " \
       'mailgun.org, amazonaws.com, outlook.com, zoho.com, protonmail.ch, yandex.net, ovh.net, ' \
       'registrar-servers.com, privateemail.com, above.com, hostedmxserver.com).'
end
