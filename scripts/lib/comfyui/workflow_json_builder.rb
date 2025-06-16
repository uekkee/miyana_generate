module Comfyui
  class WorkflowJsonBuilder
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_reader :checkpoint_node, :latent_image_node,
                :negative_prompt_node, :load_lora_nodes, :positive_prompt_node,
                :ksampler_node, :vae_decode_node, :save_image_node

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
                                 clip_index: load_lora_nodes.last.index)
      build_ksampler_node(seed: rand(1000..999_999_999),
                          model_index: load_lora_nodes.last.index,
                          positive_index: positive_prompt_node.index,
                          negative_index: negative_prompt_node.index,
                          latent_image_index: latent_image_node.index)
      build_vae_decode_node(sample_index: ksampler_node.index, vae_index: checkpoint_node.index)
      build_save_image_node(filename_prefix: 'miyana/results', image_index: vae_decode_node.index)

      {
        "#{ksampler_node.index}": ksampler_node.json,
        "#{checkpoint_node.index}": checkpoint_node.json,
        "#{latent_image_node.index}": latent_image_node.json,
        "#{positive_prompt_node.index}": positive_prompt_node.json,
        "#{vae_decode_node.index}": vae_decode_node.json,
        "#{save_image_node.index}": save_image_node.json,
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

    def build_ksampler_node(seed:, model_index:, positive_index:, negative_index:, latent_image_index:)
      @ksampler_node = assign_node(
        {
          inputs: {
            seed:, steps: 25, cfg: 7, sampler_name: 'dpmpp_2m', scheduler: 'karras', denoise: 1,
            model: [model_index.to_s, 0], positive: [positive_index.to_s, 0], negative: [negative_index.to_s, 0],
            latent_image: [latent_image_index.to_s, 0]
          },
          class_type: 'KSampler', _meta: { title: 'KSampler' }
        }
      )
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

    def build_vae_decode_node(sample_index:, vae_index:)
      @vae_decode_node = assign_node(
        {
          inputs: { samples: [sample_index.to_s, 0], vae: [vae_index.to_s, 2] },
          class_type: 'VAEDecode',
          _meta: { title: 'VAE Decode' }
        }
      )
    end

    def build_save_image_node(filename_prefix:, image_index:)
      @save_image_node = assign_node(
        {
          inputs: { filename_prefix:, images: [image_index.to_s, 0] },
          class_type: 'SaveImage', _meta: { title: 'Save Image' }
        }
      )
    end

    def build_load_lora_nodes(lora_names:, first_model_index:, first_clip_index:)
      last_load_lora_node = nil

      @load_lora_nodes = lora_names.map do |lora_name|
        model_index = last_load_lora_node ? last_load_lora_node.index : first_model_index
        clip_index = last_load_lora_node ? last_load_lora_node.index : first_clip_index

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
