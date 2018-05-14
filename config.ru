require 'logger'
class ::Logger; alias_method :write, :<<; end
logger = ::Logger.new('app.log', 'weekly')
use Rack::CommonLogger, logger

require './niki.rb'

run Rack::URLMap.new('/niki' => Niki)

# map '/' do
#   run NicroWiki.new(
#     logger: logger,
#     userfile: './users.yml',
#   )
# end

