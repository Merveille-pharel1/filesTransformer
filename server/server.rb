require "bundler/inline"

gemfile do
    source "http://rubygems.org"

    gem "sinatra-contrib"

    gem "rackup"
    gem "puma"
end

require "sinatra/base"
require "sinatra/reloader"
require_relative "auth.rb"
require "json"
require "date"
require "securerandom"
require "fileutils"

class MySinatraApp < Sinatra::Base

    configure :development do
        register Sinatra::Reloader
    end

    def sha256(value)
        nil if value.nil? || value.empty?

        OpenSSL::HMAC.hexdigest("sha256", SHA_KEY, value)
    end

    def authorize
        auth =  Rack::Auth::Basic::Request.new(request.env) 

        return unless auth.provided? && auth.basic? && auth.credentials

        username, password = auth.credentials 

        user = authenticate(username, password)

        @user_id = user[:id] unless user.nil?
  
    end

    DATABASE = "saved_files.json"
    DIR_PATH = './uploads'

    File.write(DATABASE, "[]") unless File.exist?(DATABASE)
    FileUtils.mkdir_p(DIR_PATH)

    def readFile 
        File.read(DATABASE)
    end

    
    before do
        authorize

        @files = JSON.parse readFile, symbolize_names: true rescue []
    end

    def guard!
        auth_required = [
            401,
            { "WWW-Authenticate" => "Basic" },
            "Invalid credentials"
        ]

        # HALT interrompt IMMEDIATEMENT la requête et retourne le resultat
        halt auth_required unless @user_id
    end

    get "/" do
        send_file File.join(__dir__, "../index.html")
    end

    get "/files" do 

        processed_files = @files.sort_by do |file|  
            [
                file[:user] == @user_id ? 0 : 1,
                -DateTime.parse(file[:timestamp]).strftime('%Q').to_i,
                file[:name]
            ]
        end

        processed_files.map! do |file|
            file.slice(:uuid, :name, :timestamp).merge({private: !file[:password].nil?, mine: file[:user] == @user_id})
        end

        [200, {"Content-Type": "application/json"}, processed_files.to_json]
    end

    get "/login" do

        guard!
   
        redirect "/", 303
    end

    get "/files/:uuid" do

        pass = request.env["rack.request.query_hash"]["pass"]
        uuid = params[:uuid]

        search_file = @files.find {|file| file[:uuid] == uuid}

        return [404, "File not found"] if search_file.nil?

        if (@user_id.nil? || search_file[:user] != @user_id) && (!search_file[:password].nil? && search_file[:password] != pass)
            return [403, "Access denied"]
        end

        path = "#{DIR_PATH}/#{search_file[:user]}/#{search_file[:uuid]}"
        name_extension = Dir.glob("#{path}.{json,yaml}").first
        
        send_file File.join(__dir__, name_extension)
    end

    post "/files" do

        guard!

        file = params[:original_file]
        password = (!params[:password] || params[:password].empty?) ? nil : params[:password]
        file_options = JSON.parse params[:options], symbolize_names: true

        halt 400, "No file uploaded." if file.nil? || file[:tempfile].nil?

        unless ["ls", "dig", "ping"].include?(file_options[:type]) && ["json", "yaml"].include?(file_options[:format])
            halt 400, "Invalid options."
        end

        sys_output = (file_options[:format] == "yaml") ? "y" : "p"

        uuid = SecureRandom.uuid
        timestamp = DateTime.now.to_s

        
        output_path = "#{DIR_PATH}/#{@user_id}/#{uuid}.#{file_options[:format]}"
        FileUtils.mkdir_p(File.dirname(output_path))

        
        success = system(
            "jc",
            "--#{file_options[:type]}",
            "-#{sys_output}",
            in:  file[:tempfile].path,
            out: output_path
        )

        unless success
            File.delete(output_path) if File.exist?(output_path)
            halt 400, "jc: Error - #{file_options[:type]} parser could not parse the input data."
        end


        file_info = {
            name: file[:filename],
            timestamp: timestamp,
            password: password,
            uuid: uuid,
            user: @user_id
        }

        @files << file_info
        File.write(DATABASE, JSON.pretty_generate(@files))

        [201, { "Content-Location" => "/files/#{uuid}" }, ""]

    end


    patch "/files/:uuid" do

        guard!

        uuid = params[:uuid]
        password = request.body.read

        search_file = @files.find {|file| file[:uuid] == uuid && file[:user] == @user_id}

        halt [404, "File not found"] if search_file.nil?

        search_file[:password] = password.empty? ? nil : password

        File.write DATABASE, JSON.pretty_generate(@files)
            
        204
    end

    delete "/files/:uuid" do

        guard!

        uuid = params[:uuid]

        search_file = @files.find {|file| file[:uuid] == uuid && file[:user] == @user_id}

        halt [404, "File not found"] if search_file.nil?

        path = DIR_PATH + "/" + @user_id.to_s + "/" + search_file[:uuid]
        file_path = Dir.glob("#{path}.{json,yaml}").first

        FileUtils.rm(file_path)

        @files.delete search_file 

        File.write DATABASE, JSON.pretty_generate(@files)

        204

    end


    run! if app_file == $0
end