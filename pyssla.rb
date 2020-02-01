require 'securerandom'
require 'mini_magick'

MiniMagick.logger.level = Logger::DEBUG

UPLOAD_DIR = './public/uploads'
DEFAULT_DITHER = 'FloydSteinberg'
MAX_TOTAL_SIZE = 100_000_000
FILES_KEEP_FOR = 24*60*60

get '/' do
  local_name = nil

  erb :index, locals: { local_name: local_name }
end

post '/upload' do
  dir_cleanup
  file = params[:file][:tempfile]
  local_name = SecureRandom.uuid
  initial_resize(file, local_name)

  erb :index, locals: { local_name: local_name }
end

get %r{/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})} do |image_name|
  # cache_control :no_store
  return 404 unless File.exist?(File.join(UPLOAD_DIR, image_name))

  zoom = params[:zoom] == 'true'
  html = params[:html] == 'true'
  dither = case params[:d]
  when 'None' then nil
  when 'Riemersma' then 'Riemersma'
  else DEFAULT_DITHER
  end

  png_path = process(image_name, params, zoom: zoom, dither: dither)

  if html
    image = MiniMagick::Image.open(png_path)
    pixels = image.get_pixels
    headers "Content-Disposition" => "attachment; filename=pyssla.html"
    erb :export, layout: false, locals: { pixels: pixels, palette: palette }
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

def dir_cleanup
  delete_before = Time.now - FILES_KEEP_FOR
  files = all_files
  files_to_delete, files = files.partition{ |file| file[:time] < delete_before }
  total_size = files.inject(0){ |acc, f| acc + f[:size] }
  while total_size > MAX_TOTAL_SIZE do
    file_to_delete, *files = files
    total_size -= file_to_delete[:size]
    files_to_delete << file_to_delete
  end
  filenames_to_delete = files_to_delete.map{ |f| f[:name] }
  File.delete(*filenames_to_delete)
end

def all_files
  filenames = Dir["#{UPLOAD_DIR}/*"]
  files = filenames.map { |filename|
    f = File.new(filename)
    {
      name: filename,
      size: f.size,
      time: f.ctime,
    }
  }
  files.sort_by!{ |f| f[:time] }
end

def process(image_name, coords, dither:, zoom: false)
  png_path = File.join(UPLOAD_DIR, "#{image_name}.png")
  image = MiniMagick::Tool::Convert.new do |img|
    img << File.join(UPLOAD_DIR, image_name)
    img.limits(time: 10)
    img.crop "#{coords[:w]}x#{coords[:h]}+#{coords[:x]}+#{coords[:y]}"
    img.resize "#{coords[:resW]}x#{coords[:resH]}"
    dither ? img.dither(dither) : img.dither.+
    img.remap File.expand_path("./pyssla.gif")
    if zoom
      img.scale '2000%'
    end
    img << png_path
  end
  png_path
end

def palette
  @palette ||= [
    [255, 121, 232],
    [217, 204, 108],
    [0, 137, 253],
    [0, 126, 62],
    [136, 139, 232],
    [215, 108, 88],
    [182, 50, 73],
    [82, 31, 36],
    [20, 29, 46],
    [235, 254, 252],
  ]
end
