require 'logger'
class ::Logger; alias_method :write, :<<; end
logger = ::Logger.new('app.log', 'weekly')
use Rack::CommonLogger, logger

require './niki.rb'

map '/' do
  run Niki.new(
    logger: logger,
    userfile: './users.yml'
  )
end

