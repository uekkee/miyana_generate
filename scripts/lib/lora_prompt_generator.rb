# frozen_string_literal: true

require 'fileutils'

# Markdownをパースしてマップ化
class MapParser
  attr_reader :headers

  def initialize(filepath)
    @filepath = filepath
    @headers = []
  end

  def parse
    maps = {}
    current_category = nil
    header_parsed = false
    border_line_skipped = false

    File.readlines(@filepath).each do |line|
      line.strip!
      if line.start_with?('### ')
        current_category = line.sub('### ', '').strip
        maps[current_category] ||= []
        header_parsed = false
        border_line_skipped = false
      elsif line.start_with?('|')
        cols = line.split('|').map(&:strip)[1..] # first element will be empty string
        if !header_parsed && cols[1] == 'タグ名'
          @headers = cols[2..]
          header_parsed = true
        elsif header_parsed && !border_line_skipped
          border_line_skipped = true
        elsif header_parsed
          tag = cols[1]
          values = @headers.zip(cols[2..]).to_h
          maps[current_category] << { tag: tag, values: values }
        end
      end
    end
    maps
  end
end

# 出力生成
class PromptGenerator
  OUTPUT_DIR = 'prompts_output'

  def initialize(lora_name:, style_pos:, style_neg:, attr_pos:, attr_neg:, styles:, compositions:)
    @lora_name = lora_name
    @style_pos = style_pos
    @style_neg = style_neg
    @attr_pos = attr_pos
    @attr_neg = attr_neg
    @styles = styles
    @compositions = compositions
  end

  def generate
    @styles.each do |style|
      @compositions.each do |comp|
        outdir = File.join(OUTPUT_DIR, @lora_name, "#{style}_#{comp}")
        FileUtils.mkdir_p(outdir)

        File.write(File.join(outdir, 'positive_prompt.txt'), generate_prompt(@style_pos, @attr_pos, style, comp))
        File.write(File.join(outdir, 'negative_prompt.txt'), generate_prompt(@style_neg, @attr_neg, style, comp))
      end
    end
  end

  def generate_prompt(style_map, attr_map, style, comp)
    blocks = []

    style_map.each_value do |tags|
      lines = tags.map { |t| format_tag(t[:tag], t[:values][style]) }.compact
      blocks << lines.join("\n") unless lines.empty?
    end

    attr_map.each_value do |tags|
      lines = tags.map { |t| format_tag(t[:tag], t[:values][comp]) }.compact
      blocks << lines.join("\n") unless lines.empty?
    end

    "#{blocks.reject(&:empty?).join("\n\n")}\n"
  end

  def format_tag(tag, value)
    return nil if value == 'x'
    return "#{tag}," if value == 'o'

    "(#{tag}:#{value}),"
  end
end

# 特定のディレクトリレイアウトで「スタイル」x「構図」の全組み合わせのプロンプトを生成するクラス
class LoraPromptGenerator
  STYLE_MAP_POSITIVE_FILENAME = 'style_map_positive.md'
  STYLE_MAP_NEGATIVE_FILENAME = 'style_map_negative.md'
  ATTR_MAP_POSITIVE_FILENAME = 'attribute_map_positive.md'
  ATTR_MAP_NEGATIVE_FILENAME = 'attribute_map_negative.md'

  def initialize(lora_name:)
    @lora_name = lora_name
  end

  def generate
    style_pos_parser = MapParser.new(map_file_path(filename: STYLE_MAP_POSITIVE_FILENAME))
    style_pos = style_pos_parser.parse
    styles = style_pos_parser.headers

    style_neg_parser = MapParser.new(map_file_path(filename: STYLE_MAP_NEGATIVE_FILENAME))
    style_neg = style_neg_parser.parse

    attr_pos_parser = MapParser.new(map_file_path(filename: ATTR_MAP_POSITIVE_FILENAME))
    attr_pos = attr_pos_parser.parse
    compositions = attr_pos_parser.headers

    attr_neg_parser = MapParser.new(map_file_path(filename: ATTR_MAP_NEGATIVE_FILENAME))
    attr_neg = attr_neg_parser.parse

    PromptGenerator.new(lora_name: @lora_name, style_pos:, style_neg:, attr_pos:, attr_neg:, styles:,
                        compositions:).generate
  end

  private

  def source_dir
    @lora_root_dir = File.join('src', @lora_name)
  end

  def map_file_path(filename:)
    File.join(source_dir, filename)
  end
end
