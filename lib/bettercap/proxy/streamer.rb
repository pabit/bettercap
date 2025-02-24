# encoding: UTF-8
=begin

BETTERCAP

Author : Simone 'evilsocket' Margaritelli
Email  : evilsocket@gmail.com
Blog   : http://www.evilsocket.net/

This project is released under the GPL 3 license.

=end

module BetterCap
module Proxy
# Handle data streaming between clients and servers for the BetterCap::Proxy::Proxy.
class Streamer
  # Initialize the class with the given +processor+ routine.
  def initialize( processor, sslstrip )
    @processor = processor
    @ctx       = Context.get
    @sslstrip  = SSLStrip::Strip.new( @ctx ) if sslstrip
  end

  # Return true if the +request+ was stripped.
  def was_stripped?(request, client)
    if @sslstrip
      request.client, _ = get_client_details( client )
      return @sslstrip.was_stripped?(request)
    end
    false
  end

  # Redirect the +client+ to a funny video.
  def rickroll( client )
    client_ip, client_port = get_client_details( client )

    Logger.warn "#{client_ip}:#{client_port} is connecting to us directly."

    client.write Response.redirect( "https://www.youtube.com/watch?v=dQw4w9WgXcQ" ).to_s
  end

  # Handle the HTTP +request+ from +client+.
  def handle( request, client, redirects = 0 )
    response = Response.new
    request.client, _ = get_client_details( client )

    Logger.debug "Handling #{request.method} request from #{request.client} ..."

    begin
      r = nil
      if @sslstrip
        r = @sslstrip.preprocess( request )
      end

      if r.nil?
        # call modules on_pre_request
        @processor.call( request, nil )

        self.send( "do_#{request.method}", request, response )
      else
        response = r
      end

      if response.textual?
        StreamLogger.log_http( request, response )
      else
        Logger.debug "[#{request.client}] -> #{request.to_url} [#{response.code}]"
      end

      if @sslstrip
        # do we need to retry the request?
        if @sslstrip.process( request, response ) == true
          # https redirect loop?
          if redirects < SSLStrip::Strip::MAX_REDIRECTS
            return self.handle( request, client, redirects + 1 )
          else
            Logger.info "[#{'SSLSTRIP'.red} #{request.client}] Detected HTTPS redirect loop for '#{request.host}'."
          end
        end
      end

      # Strip out a few security headers.
      strip_security( response )

      # call modules on_request
      @processor.call( request, response )

      client.write response.to_s
    rescue NoMethodError => e
      Logger.warn "Could not handle #{request.method} request from #{request.client} ..."
      Logger.exception e
    end
  end

  private

  # List of security headers to remove/patch from any response.
  # Thanks to Mazin Ahmed ( @mazen160 )
  SECURITY_HEADERS = {
    'X-Frame-Options'                     => nil,
    'X-Content-Type-Options'              => nil,
    'Strict-Transport-Security'           => nil,
    'X-WebKit-CSP'                        => nil,
    'Public-Key-Pins'                     => nil,
    'Public-Key-Pins-Report-Only'         => nil,
    'X-Content-Security-Policy'           => nil,
    'Content-Security-Policy-Report-Only' => nil,
    'Content-Security-Policy'             => nil,
    'X-Download-Options'                  => nil,
    'X-Permitted-Cross-Domain-Policies'   => nil,
    'Allow-Access-From-Same-Origin'       => '*',
    'Access-Control-Allow-Origin'         => '*',
    'Access-Control-Allow-Methods'        => '*',
    'Access-Control-Allow-Headers'        => '*',
    'X-Xss-Protection'                    => '0'
  }.freeze

  # Strip out a few security headers from +response+.
  def strip_security( response )
    SECURITY_HEADERS.each do |name,value|
      response[name] = value
    end
  end

  # Return the +client+ ip address and port.
  def get_client_details( client )
    _, client_port, _, client_ip = client.peeraddr
    [ client_ip, client_port ]
  end

  # Use a Net::HTTP object in order to perform the +req+ BetterCap::Proxy::Request
  # object, will return a BetterCap::Proxy::Response object instance.
  def perform_proxy_request(req, res)
    path         = req.path
    response     = nil
    http         = Net::HTTP.new( req.host, req.port )
    http.use_ssl = ( req.port == 443 )

    http.start do
      response = yield( http, path, req.headers )
    end

    res.convert_webrick_response!(response)
  end

  # Handle a CONNECT request, +req+ is the request object and +res+ the response.
  def do_CONNECT(req, res)
    Logger.error "You're using bettercap as a normal HTTP(S) proxy, it wasn't designed to handle CONNECT requests:\n\n#{req.to_s}"
  end

  # Handle a GET request, +req+ is the request object and +res+ the response.
  def do_GET(req, res)
    perform_proxy_request(req, res) do |http, path, header|
      http.get(path, header)
    end
  end

  # Handle a HEAD request, +req+ is the request object and +res+ the response.
  def do_HEAD(req, res)
    perform_proxy_request(req, res) do |http, path, header|
      http.head(path, header)
    end
  end

  # Handle a POST request, +req+ is the request object and +res+ the response.
  def do_POST(req, res)
    perform_proxy_request(req, res) do |http, path, header|
      http.post(path, req.body || "", header)
    end
  end

end
end
end
