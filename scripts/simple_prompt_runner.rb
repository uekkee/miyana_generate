# frozen_string_literal: true

# シンプルにプロンプトを実行・出力画像を取得するコマンドラインツールです
#
# help: bundle exec ruby scripts/simple_prompt_runner.rb --help

require 'optimist'

require_relative 'lib/prompt_executor'

opts = Optimist.options do
  opt :loop, 'loop (default: 1)', type: :integer, default: 1
  opt :batch_size, 'batch_size (default: 10)', type: :integer
  opt :width, 'image width (default: 1024)', type: :integer
  opt :height, 'image height (default: 1024)', type: :integer
  opt :positive_file_path, 'positive prompt file path (default: ./tmp/tmp_positive.txt)', type: :string
  opt :negative_file_path, 'negative prompt file path (default: ./tmp/tmp_negative.txt)', type: :string
end

def run(options)
  seed = rand(1000..5_143_156_182_854)
  prompt_id = PromptAsyncExecutor.new(options.merge(seed:)).request_prompt
  filenames = PromptWaiter.new(prompt_id:).wait_until_finished
  PromptImagesCopier.new(filenames:).copy
end

loop = opts[:loop] || 1
options = opts.slice(:batch_size, :width, :height, :positive_file_path, :negative_file_path).compact

p "Running with loop: #{loop}, options: #{options.inspect}"
loop.times { run(options) }
