require 'securerandom'
require 'mini_magick'

get '/' do
  local_name = nil

  erb :index, locals: { local_name: local_name }
end

post '/upload' do
  @filename = params[:file][:filename]
  file = params[:file][:tempfile]
  local_name = SecureRandom.uuid

  File.open("./public/uploads/#{local_name}", 'wb') do |f|
    f.write(file.read)
  end
  
  erb :index, locals: { local_name: local_name }
end

get '/cropped/:image' do
  cache_control :no_store
  p params
  result = process(params[:image], params)
  content_type :png
  s = StringIO.new
  result.write(s)
  s.string
end

def process(image_name, coords)
  image = MiniMagick::Image.open("./public/uploads/#{image_name}")

  image.crop "#{coords[:w]}x#{coords[:h]}+#{coords[:x]}+#{coords[:y]}"
  image.resize "29x29"
  image.dither "FloydSteinberg"
  image.remap "./pyssla.gif"
  image.format 'png'
  # convert ~/Downloads/image.jpeg -scale 29x29 -dither FloydSteinberg -remap ~/Pictures/pyksla.gif ~/Downloads/output2.png
  image
end
