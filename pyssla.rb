require 'securerandom'
require 'mini_magick'

MiniMagick.logger.level = Logger::DEBUG

UPLOAD_DIR = './public/uploads'
DEFAULT_DITHER = 'FloydSteinberg'

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

get %r{/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})} do |image_name|
  cache_control :no_store
  return 404 unless File.exist?(File.join(UPLOAD_DIR, image_name))

  zoom = params[:zoom] == 'true'
  csv = params[:csv] == 'true'
  dither = case params[:d]
  when 'None' then nil
  when 'Riemersma' then 'Riemersma'
  else DEFAULT_DITHER
  end

  png_path = process(image_name, params, zoom: zoom, dither: dither)

  if csv
    image = MiniMagick::Image.open(png_path)
    pixels = image.get_pixels
    p pixels
    'OK'
  else
    content_type :png
    headers "Content-Disposition" => "attachment; filename=pyssla.png" if params[:download] == 'true'
    File.read(png_path)
  end
end

def initial_resize(tmp_image, local_name)
  image = MiniMagick::Tool::Convert.new do |img|
    img << tmp_image.path
    img.resize '600x600>'
    img << File.join(UPLOAD_DIR, local_name)
  end
end

def process(image_name, coords, dither:, zoom: false)
  png_path = File.join(UPLOAD_DIR, "#{image_name}.png")
  image = MiniMagick::Tool::Convert.new do |img|
    img << File.join(UPLOAD_DIR, image_name)
    img.crop "#{coords[:w]}x#{coords[:h]}+#{coords[:x]}+#{coords[:y]}"
    img.resize "29x29"
    dither ? img.dither(dither) : img.dither.+
    img.remap File.expand_path("./pyssla.gif")
    if zoom
      img.filter 'Box'
      img.resize '2000%'
    end
    img << png_path
  end
  png_path
end
