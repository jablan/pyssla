require 'securerandom'
require 'mini_magick'

# MiniMagick.logger.level = Logger::DEBUG

get '/' do
  local_name = nil

  erb :index, locals: { local_name: local_name }
end

post '/upload' do
  # @filename = params[:file][:filename]
  file = params[:file][:tempfile]
  p file
  local_name = SecureRandom.uuid
  initial_resize(file, local_name)

  erb :index, locals: { local_name: local_name }
end

get '/cropped/:image' do
  cache_control :no_store
  image_name = params[:image]
  process(image_name, params)
  content_type :png
  File.read("./public/uploads/#{image_name}.png")
end

def initial_resize(tmp_image, local_name)
  image = MiniMagick::Tool::Convert.new do |img|
    img << tmp_image.path
    img.resize "600x600>"
    img << "./public/uploads/#{local_name}"
  end
end

def process(image_name, coords)
  image = MiniMagick::Tool::Convert.new do |img|
    img << "./public/uploads/#{image_name}"
    img.crop "#{coords[:w]}x#{coords[:h]}+#{coords[:x]}+#{coords[:y]}"
    img.resize "29x29"
    img.dither "FloydSteinberg"
    img.remap File.expand_path("./pyssla.gif")
    img << "./public/uploads/#{image_name}.png"
  end
end
