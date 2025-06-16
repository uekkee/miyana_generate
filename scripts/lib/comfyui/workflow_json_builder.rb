module Comfyui
  class WorkflowJsonBuilder
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_reader :checkpoint_node, :latent_image_node,
                :negative_prompt_node, :load_lora_nodes, :positive_prompt_node

    def initialize
      @current_node_index = 3
    end

    def base_json
      build_checkpoint_node
      build_latent_image_node(width: 1376, height: 1024, batch_size: 1)
      build_negative_prompt_json(text: 'bad quality,worst quality,worst detail,sketch,censor,nsfw',
                                 clip_index: checkpoint_node.index)
      build_load_lora_nodes(lora_names: ['miyanabase_wai_part_try_250614_2038.safetensors',
                                         'miyanakimono_20250615_0702.safetensors'],
                            first_model_index: checkpoint_node.index, first_clip_index: checkpoint_node.index)
      build_positive_prompt_node(text: "masterpiece,best quality,amazing quality,\n1girl, miyanabase, miyanakimono, looking at viewer, walking at beach",
                                 clip_index: 14) # FIXME: clip_index: load_lora_nodes.last.index)

      # FIXME: changing node index will be removed finally
      latent_image_node.index = 5
      negative_prompt_node.index = 11
      load_lora_nodes.first.index = 12
      load_lora_nodes.last.index = 14
      positive_prompt_node.index = 6

      {
        '3': ksampler_json,
        "#{checkpoint_node.index}": checkpoint_node.json,
        "#{latent_image_node.index}": latent_image_node.json,
        "#{positive_prompt_node.index}": positive_prompt_node.json,
        '8': vae_decode_json,
        '9': save_image_json,
        "#{negative_prompt_node.index}": negative_prompt_node.json,
        "#{load_lora_nodes.first.index}": load_lora_nodes.first.json,
        "#{load_lora_nodes.last.index}": load_lora_nodes.last.json
      }
    end

    private

    def assign_node(json)
      @current_node_index += 1

      WorkflowNode.new(index: @current_node_index, json:)
    end

    def ksampler_json
      {
        inputs: {
          seed: rand(100..100_000), steps: 25, cfg: 7, sampler_name: 'dpmpp_2m', scheduler: 'karras', denoise: 1,
          model: ['14', 0], positive: ['6', 0], negative: ['11', 0], latent_image: ['5', 0]
        },
        class_type: 'KSampler',
        _meta: { title: 'KSampler' }
      }
    end

    def build_checkpoint_node
      @checkpoint_node = assign_node(
        {
          inputs: { ckpt_name: 'waiNSFWIllustrious_v140.safetensors' },
          class_type: 'CheckpointLoaderSimple',
          _meta: { title: 'Load Checkpoint' }
        }
      )
    end

    def build_latent_image_node(width:, height:, batch_size:)
      @latent_image_node = assign_node(
        {
          inputs: { width:, height:, batch_size: },
          class_type: 'EmptyLatentImage',
          _meta: { title: 'Empty Latent Image' }
        }
      )
    end

    def build_positive_prompt_node(text:, clip_index:)
      @positive_prompt_node = assign_node(
        {
          inputs: { text:, clip: [clip_index.to_s, 1] },
          class_type: 'CLIPTextEncode',
          _meta: { title: 'CLIP Text Encode (Prompt)' }
        }
      )
    end

    def build_negative_prompt_json(text:, clip_index:)
      @negative_prompt_node = assign_node(
        {
          inputs: { text:, clip: [clip_index.to_s, 1] },
          class_type: 'CLIPTextEncode',
          _meta: { title: 'CLIP Text Encode (Negative Prompt)' }
        }
      )
    end

    def vae_decode_json
      {
        inputs: { samples: ['3', 0], vae: ['4', 2] },
        class_type: 'VAEDecode',
        _meta: { title: 'VAE Decode' }
      }
    end

    def save_image_json
      {
        inputs: { filename_prefix: 'miyana/results', images: ['8', 0] },
        class_type: 'SaveImage',
        _meta: { title: 'Save Image' }
      }
    end

    def build_load_lora_nodes(lora_names:, first_model_index:, first_clip_index:)
      last_load_lora_node = nil

      @load_lora_nodes = lora_names.map do |lora_name|
        # FIXME: changing node index will be removed finally
        # model_index = last_load_lora_node ? last_load_lora_node.index : first_model_index
        # clip_index = last_load_lora_node ? last_load_lora_node.index : first_clip_index
        model_index = last_load_lora_node ? 12 : first_model_index
        clip_index = last_load_lora_node ? 12 : first_clip_index

        last_load_lora_node = assign_node(
          load_lora_json(lora_name:, strength_model: 1, strength_clip: 1, model_index:, clip_index:)
        )
      end
    end

    def load_lora_json(lora_name:, strength_model:, strength_clip:, model_index:, clip_index:)
      {
        inputs: {
          lora_name:,
          strength_model:,
          strength_clip:,
          model: [model_index.to_s, 0],
          clip: [clip_index.to_s, 1]
        },
        class_type: 'LoraLoader', _meta: { title: "Load LoRA - #{lora_name}" }
      }
    end

    class WorkflowNode
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :index, :integer
      attribute :json
    end
  end
end
