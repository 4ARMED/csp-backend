#!/usr/bin/env ruby

require 'sinatra'
require 'json'
require 'mongo'
require 'json/ext'
require 'uri'
require 'cgi'

configure do
  set :server, :puma
  Mongo::Logger.logger.level = ::Logger::FATAL
  host = ENV['CSP_MONGODB_HOST'] || '127.0.0.1'
  database = ENV['CSP_MONGODB_DB'] || 'csp'
  user = ENV['CSP_MONGODB_USER'] || ''
  password = ENV['CSP_MONGODB_PASSWORD'] || ''

  db = Mongo::Client.new([ host ], { :database => database, :user => user, :password => password, :server_selection_timeout => 10 })
  set :mongo_db, db
  set :mongo_collection, db[:csp]
end

helpers do
  def get_hostname_from_url(url)
    u = URI.parse(url)
    if [80, 443].include? u.port
      u.host
    else
      "#{u.host}:#{u.port}"
    end
  end

  def remove_path_from_url(url)
    u = URI.parse(url)
    "#{u.scheme}://#{u.host}:#{u.port}"
  end

  def build_csp(reported_blocks, unsafe=false)
    content_security_policy = "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'self'; plugin-types 'self'; sandbox 'self'; report-uri #{request.scheme}://#{request.host_with_port}/report; "
    directives = {}

    reported_blocks.each do |block|
      directive = block['csp-report']['effective-directive']
      blocked_uri = block['csp-report']['blocked-uri']

      if directive.nil?
        # some reports don't contain effective-directive, don't know why
        directive = block['csp-report']['violated-directive'].split(/\s/)[0]
        next if directive.nil?
      end

      if /^http/.match(blocked_uri)
        whitelist_src = remove_path_from_url(blocked_uri)
      end

      if /^self$/.match(blocked_uri)
        whitelist_src = 'self'
      end

      /^(inline)|^(eval)/.match(blocked_uri) do |match|
        whitelist_src = "'unsafe-#{match[0]}'" if unsafe === "1"
      end

      next if whitelist_src.nil?

      if directives.has_key? directive
        directives[directive] << whitelist_src
      else
        directives[directive] = [ whitelist_src ]
      end
    end

    directives.each do |dir, value|
      next if value.nil?
      policy = "#{dir} #{value.uniq.join(' ')}"
      content_security_policy << policy + '; '
    end

    { :policy => content_security_policy }.to_json
  end
end

get '/_healthz' do
  # I would not describe this as a robust health check but it at least means
  # we can tie in to the Mongo cluster monitoring without having to send queries
  # and wait for a timeout
  db = settings.mongo_db

  if db.cluster.topology.instance_of? Mongo::Cluster::Topology::Unknown
    status "500"
    body "cluster in unknown state"
  else
    if db.cluster.servers.empty?
      status "500"
      body "no servers"
    else
      status "200"
      body "ok"
    end
  end
end

post '/report' do
  content_type :json
  collection = settings.mongo_collection

  csp_report = JSON.parse(request.body.read.to_s)
  hostname = get_hostname_from_url(csp_report['csp-report']['document-uri'])
  csp_report['csp-report']['document-uri'] = hostname
  begin
    result = collection.insert_one csp_report
    "ok"
  rescue Mongo::Error::OperationFailure => e
    Mongo::Logger.logger.debug "#{e.message}"
    "error"
  end

end

get '/policy/:hostname/?' do
  content_type :json

  collection = settings.mongo_collection
  reported_blocks = collection.find({ "csp-report.document-uri": CGI.unescape(params[:hostname])})
  build_csp reported_blocks, params[:unsafe]
end

delete '/policy/:hostname/?' do
  content_type :json

  collection = settings.mongo_collection
  collection.delete_many({ "csp-report.document-uri": CGI.unescape(params[:hostname])}) unless params[:hostname].nil?
end
