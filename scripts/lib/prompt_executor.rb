# frozen_string_literal: true

require 'faraday'
require 'active_support/all'
require 'active_model'
require 'fileutils'

require_relative 'comfyui/workflow_json_builder'

ENDPOINT_BASE_URL = 'http://192.168.11.7:8188'
COMFYUI_OUTPUT_DIR = '/Volumes/miyana'
IMAGES_OUTPUT_BASE_DIR = './images_output'

# 非同期のプロンプト実行を行う
class PromptAsyncExecutor # rubocop:disable Metrics/ClassLength
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :positive_file_path, :string, default: './tmp/tmp_positive.txt'
  attribute :negative_file_path, :string, default: './tmp/tmp_negative.txt'
  attribute :batch_size, :integer, default: 10
  attribute :width, :integer, default: 1024
  attribute :height, :integer, default: 1024
  attribute :seed, :integer, default: rand(1000..5_143_156_182_854)

  def request_prompt
    conn = Faraday::Connection.new(url: ENDPOINT_BASE_URL)
    conn.adapter Faraday.default_adapter
    conn.headers { 'Content-Type' => 'application/json' }
    conn.response :logger
    response = conn.post('/prompt') do |request|
      request.body = request_json.to_json
    end
    JSON.parse(response.body)['prompt_id']
  end

  private

  def load_prompt_file(file_path)
    File.read(file_path).split.join(' ').gsub('"', '\"')
  end

  def request_json
    { prompt: Comfyui::WorkflowJsonBuilder.new.base_json }
  end

  def old_request_json # rubocop:disable Metrics/MethodLength
    JSON.parse(<<~JSON)
      {
          "prompt": {
              "3": {
                  "class_type": "KSampler",
                  "inputs": {
                      "latent_image": [
                          "5",
                          0
                      ],
                      "model": [
                          "4",
                          0
                      ],
                      "negative": [
                          "7",
                          0
                      ],
                      "positive": [
                          "6",
                          0
                      ],
              "seed": #{seed},
              "steps": 30,
              "cfg": 6.0,
              "sampler_name": "dpmpp_2m",
              "scheduler": "karras",
              "denoise": 1.0
                      }
              },
              "4": {
                  "class_type": "CheckpointLoaderSimple",
                  "inputs": {
                      "ckpt_name": "waiNSFWIllustrious_v140.safetensors"
                  }
              },
              "5": {
                  "class_type": "EmptyLatentImage",
                  "inputs": {
                      "batch_size": #{batch_size},
                      "width": #{width},
                      "height": #{height}
                  }
              },
              "6": {
                  "class_type": "CLIPTextEncode",
                  "inputs": {
                      "clip": [
                          "4",
                          1
                      ],
                      "text": "#{load_prompt_file(positive_file_path)}"
                  }
              },
              "7": {
                  "class_type": "CLIPTextEncode",
                  "inputs": {
                      "clip": [
                          "4",
                          1
                      ],
                      "text": "#{load_prompt_file(negative_file_path)}"
                  }
              },
              "8": {
                  "class_type": "VAEDecode",
                  "inputs": {
                      "samples": [
                          "3",
                          0
                      ],
                      "vae": [
                          "4",
                          2
                      ]
                  }
              },
              "9": {
                  "class_type": "SaveImage",
                  "inputs": {
                      "filename_prefix": "miyana/test",
                      "images": [
                          "8",
                          0
                      ]
                  }
              }
          }#{'            '}
      }
    JSON
  end
end

# プロンプトの実行状態を確認するクラス
class PromptQueueChecker
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :prompt_id, :string

  def finished?
    conn = Faraday::Connection.new(url: ENDPOINT_BASE_URL)
    conn.adapter Faraday.default_adapter
    conn.response :logger
    response = conn.get('/queue')
    response_json_hash = JSON.parse(response.body).deep_symbolize_keys

    prompt_not_in_queue?(response_json_hash[:queue_running]) &&
      prompt_not_in_queue?(response_json_hash[:queue_pending])
  end

  private

  def prompt_not_in_queue?(queue)
    return true if queue.blank?

    queue.each do |item|
      return false if item.second == prompt_id
    end

    true
  end
end

# プロンプトの非同期処理が終わるのを待つ
class PromptWaiter
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :prompt_id, :string

  def wait_until_finished
    loop do
      sleep 3

      break if finished?
    end

    file_infos
  end

  private

  def prompt_queue_checker
    @prompt_queue_checker ||= PromptQueueChecker.new(prompt_id:)
  end

  def finished?
    prompt_queue_checker.finished?
  end

  def find_history
    conn = Faraday::Connection.new(url: ENDPOINT_BASE_URL)
    conn.adapter Faraday.default_adapter
    conn.response :logger
    conn.get("/history/#{prompt_id}")
  end

  def file_infos
    response = find_history

    outputs = JSON.parse(response.body).deep_symbolize_keys.dig(:"#{prompt_id}", :outputs)

    return if outputs.blank?

    outputs.keys
    outputs.keys.map { |key| outputs[key][:images] }.flatten.pluck(:filename)
  end
end

# ComfyUI により出力されたプロンプトの画像を特定の箇所へコピーする
class PromptImagesCopier
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :filenames, array: :string, default: []
  attribute :comfyui_output_dir, :string, default: COMFYUI_OUTPUT_DIR
  attribute :images_output_dir, :string, default: IMAGES_OUTPUT_BASE_DIR

  def copy
    FileUtils.mkdir_p images_output_dir

    filenames.each do |filename|
      comfyui_file = File.join(comfyui_output_dir, filename)
      wait_file_sync(comfyui_file)
      FileUtils.copy(comfyui_file, images_output_dir)
    end
  end

  private

  def wait_file_sync(file_path)
    loop do
      break if File.exist? file_path

      sleep 1
    end
  end
end
