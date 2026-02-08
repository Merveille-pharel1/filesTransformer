require "bundler/inline"

gemfile do
    source "http://rubygems.org"
    gem "faraday"

    # https://github.com/lostisland/faraday-multipart
    gem "faraday-multipart"
end

require "faraday"
require "faraday/multipart"
require "base64"
require "json"

server = Faraday.new("http://localhost:4567") do |f|
  f.request :multipart
end

# Upload - Cas positif

puts "Upload Positive"

pass = "ping"
output_type = "json"

data = {
  title: "file upload",
  password: pass,
  original_file: Faraday::Multipart::FilePart.new("ping-offline.txt", "text/plain"),
  options: {type: "ping", format: output_type}
}

response = server.post("/files", data, {"Authorization" => "Basic #{Base64.encode64("alice:pwda")}"}) 

if response.status == 201
  location = response.headers['Content-Location']
  puts "Upload du fichier réussi. Emplacement: #{location}"
else
  puts "#{response.body}"
end


# Upload - Cas alternatif

# puts "\nUpload Alternative"

# pass = nil
# output_type = "application/xml"

# data = {
#   title: "file upload",
#   password: pass,
#   original_file: Faraday::Multipart::FilePart.new("dig-file.txt", "text/plain"),
#   options: {type: "xlm", format: output_type}
# }

# response = server.post("/files", data, {"Authorization" => "Basic #{Base64.encode64("dave:pwdd")}"}) 

# if response.status == 201
#     puts "Upload du fichier réussi. Emplacement: #{response.headers['Content-Location']}"
# else
#     puts "#{response.body}"
# end


# # Liste - Cas positif

# puts "\nListe Positive"
# response = server.get "/files"
# liste = JSON.parse(response.body)
# puts "#{JSON.pretty_generate liste}"


# # Liste - Cas alternative

# puts "\nListe Alternative"

 
# response = server.get "/files", nil, {"Authorization" => "Basic #{Base64.encode64("dave:pwdd")}"}
# liste = JSON.parse(response.body)
# puts "#{JSON.pretty_generate liste}"



# # Recupération - Cas Positive
# puts "\nRecupération de fichier Positive"

# response = server.get "#{location}", nil, {"Authorization" => "Basic #{Base64.encode64("dave:pwdd")}"}
# puts "#{response.body}"


# # Recupération - Cas Alternative
# puts "\nRecupération de fichier Alternative"

# response = server.get "#{location}", nil, {"Authorization" => "Basic #{Base64.encode64("bob:pwdb")}"}
# puts "#{response.body}"


# # Modification - Cas positif
# puts "\nModification du pwd du fichier Positive"

# response = server.patch "#{location}", "newpass", {"Authorization" => "Basic #{Base64.encode64("dave:pwdd")}"}
# puts "Modification réussie."


# # Modification - Cas alternatif
# puts "\nModification du pwd du fichier Alternative"

# response = server.patch "#{location}", "pwd", {"Authorization" => "Basic #{Base64.encode64("bob:pwdb")}"}
# puts "#{response.body}"

# # Deletion - Cas positif
# puts "\nSuppression de fichier Positive"

# response = server.delete "#{location}", nil, {"Authorization" => "Basic #{Base64.encode64("dave:pwdd")}"}

# if response.status == 204
#     puts "Suppression réussie"
# else
#     puts "#{response.body}"
# end

# # Deletion - Cas alternatif
# puts "\nSuppression de fichier Alternative"

# response = server.delete "#{location}", nil, {"Authorization" => "Basic #{Base64.encode64("bob:pwdb")}"}

# if response.status == 204
#     puts "Suppression réussie"
# else
#     puts "#{response.body}"
# end


