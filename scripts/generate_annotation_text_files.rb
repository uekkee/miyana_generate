# frozen_string_literal: true

require 'optimist'

opts = Optimist.options do
  opt :trigger_tag, 'Trigger tag of LoRA model', type: :string, required: true
  opt :images_dir, 'Directory containing images', type: :string, required: true
  opt :positive_prompt_path, 'Path to the positive prompt file', type: :string, required: true
end

trigger_tag = opts[:trigger_tag]
images_dir = opts[:images_dir]
positive_prompt_path = opts[:positive_prompt_path]

def create_annotation_text(trigger_tag:, positive_prompt_path:)
  tags = File
         .read(positive_prompt_path)
         .split(',')
         .map(&:strip)
         .map { |tag| tag.include?('(') ? tag.gsub(/\(([\w\s\d]+):.+\)/) { Regexp.last_match(1).to_s } : tag } # 強調タグは除去
  tags.prepend(trigger_tag) # トリガータグを先頭に追加
  tags.join(', ')
end

annotation_txt =  create_annotation_text(trigger_tag:, positive_prompt_path:)

Dir.glob('*.png', base: images_dir).map do |filename|
  File.write(File.join(images_dir, filename.sub('.png', '.txt')), annotation_txt)
  p "Created annotation text file for #{filename}"
end
