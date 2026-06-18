# frozen_string_literal: true

# Opal frontend files use backticks/`%x{}` for inline JavaScript (with a
# `# backtick_javascript: true` magic comment). When loaded by CRuby
# during spec runs), these execute as shell commands and produce dash
# shell errors.
#
# This patches the backtick operator so that any command originating from
# a file with the `# backtick_javascript: true` magic comment returns an
# empty string instead of running a shell command.
# The original backtick is restored after all specs finish.

orig_backtick = Kernel.instance_method(:`)
MAGIC_COMMENT = '# backtick_javascript: true'
$opal_files_cache = {}

Kernel.define_method(:`) do |cmd|
  path = caller_locations(1, 1)&.first&.path || ''

  unless $opal_files_cache.key?(path)
    $opal_files_cache[path] = begin
      File.foreach(path).first(3).any? { |line| line.start_with?(MAGIC_COMMENT) }
    rescue
      false
    end
  end

  return '' if $opal_files_cache[path]

  orig_backtick.bind_call(self, cmd)
end

at_exit do
  Kernel.define_method(:`) do |cmd|
    orig_backtick.bind_call(self, cmd)
  end
end
