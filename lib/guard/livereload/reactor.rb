require 'multi_json'
require "reel"

module Guard
  class LiveReload < Plugin
    class Reactor < Reel::Server::HTTP
      attr_reader :web_sockets, :options

      def initialize(opts)
        @web_sockets = []
        @options = opts
        UI.info "LiveReload is waiting for a browser to connect."
        UI.debug @options
        super(options[:host], options[:port].to_i, &method(:on_connection))
      end

      def reload_browser(paths = [])
        msg = "Reloading browser: #{paths.join(' ')}"
        UI.info msg
        if options[:notify]
          Notifier.notify(msg, title: 'Reloading browser', image: :success)
        end

        paths.each do |path|
          data = _data(path)
          UI.debug data
          web_sockets.each { |ws| ws << MultiJson.encode(data) }
        end
      end

      def on_connection(conn)
        while req = conn.request
          if req.websocket?
            web_sockets << req.websocket
            conn.detach
            route_websocket req.websocket
            return
          else
            route_request conn, req
          end
        end
      end

      def route_request(conn, req)
        case req.url
        when %r{^/livereload\.js.*}
          UI.debug "Serve /livereload.js"
          conn.respond :ok, {"content-type" => 'application/javascript'}, serve_livereload_js
        when "/"
          conn.respond :ok, {"content-type" => 'text/html'}, serve_index_html
        else
          conn.respond :not_found, "Not Found"
        end
      end

      def route_websocket(ws)
        UI.debug "Browser connected. Response HELLO"
        hello = livereload_hello
        UI.debug hello
        ws << hello
      end

    private

      def _data(path)
        data = {
          command: 'reload',
          path:    "#{Dir.pwd}/#{path}",
          liveCSS: options[:apply_css_live]
        }
        if options[:override_url] && File.exist?(path)
          data[:overrideURL] = '/' + path
        end
        data
      end

      def serve_livereload_js
        open(File.join(File.dirname(File.expand_path(__FILE__)), "..", "..", "..", "vendor", "assets", "livereload.js")).read
      end

      def serve_index_html
        open(File.join(File.dirname(File.expand_path(__FILE__)), "..", "..", "..", "vendor", "assets", "example.html")).read
      end

      def livereload_hello
        MultiJson.encode(:command => 'hello', :protocols => ['http://livereload.com/protocols/official-7'], :serverName => 'guard-livereload')
      end

    end
  end
end
