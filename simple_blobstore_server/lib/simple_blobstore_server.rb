require "digest/sha1"
require "fileutils"
require "set"
require "optparse"
require "pp"
require "yaml"

require "sinatra"
require "uuidtools"

module Bosh
  module Blobstore
    class SimpleBlobstoreServer < Sinatra::Base

      BUFFER_SIZE = 16 * 1024

      def initialize(config)
        super
        @path = config["path"]
        @nginx_path = config["nginx_path"]

        if File.exists?(@path)
          raise "Invalid path" unless File.directory?(@path)
        else
          FileUtils.mkdir_p(@path)
        end

        raise "Invalid user list" unless config["users"].kind_of?(Hash)
        @users = Set.new
        config["users"].each do |username, password|
          @users << [username, password]
        end
        raise "Must have at least one user" if @users.empty?
      end

      def get_file_name(object_id)
        sha1 = Digest::SHA1.hexdigest(object_id)
        File.join(@path, sha1[0, 2], object_id)
      end

      def get_nginx_path(object_id)
        sha1 = Digest::SHA1.hexdigest(object_id)
        "#{@nginx_path}/#{sha1[0, 2]}/#{object_id}"
      end

      def generate_object_id
        UUIDTools::UUID.random_create.to_s
      end

      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="Authenticate")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && @users.include?(@auth.credentials)
      end

      before do
        protected!
      end

      post "/resources" do
        if params[:content] && params[:content][:tempfile]
          # Process uploads coming directly to the simple blobstore
          object_id = generate_object_id
          file_name = get_file_name(object_id)

          tempfile = params[:content][:tempfile]

          FileUtils.mkdir_p(File.dirname(file_name))
          FileUtils.copy_file(tempfile.path, file_name)

          status(200)
          content_type(:text)
          object_id
        elsif params["content.name"] && params["content.path"]
          # Process uploads arriving via nginx
          object_id = generate_object_id
          file_name = get_file_name(object_id)

          FileUtils.mkdir_p(File.dirname(file_name))
          FileUtils.mv(params["content.path"], file_name)

          status(200)
          content_type(:text)
          object_id
        else
          error(400)
        end
      end

      get "/resources/:id" do
        file_name = get_file_name(params[:id])
        if File.exist?(file_name)
          if @nginx_path
            status(200)
            content_type "application/octet-stream"
            response["X-Accel-Redirect"] = get_nginx_path(params[:id])
            nil
          else
            send_file(file_name)
          end
        else
          error(404)
        end
      end

      delete "/resources/:id" do
        file_name = get_file_name(params[:id])
        if File.exist?(file_name)
          status(204)
          FileUtils.rm(file_name)
        else
          error(404)
        end
      end

    end
  end
end
