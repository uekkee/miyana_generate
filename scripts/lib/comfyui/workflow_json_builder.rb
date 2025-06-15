module Comfyui
  class WorkflowJsonBuilder
    def base_json
      {
        '3': {
          inputs: { seed: rand(100..100_000), steps: 25, cfg: 7, sampler_name: 'dpmpp_2m', scheduler: 'karras', denoise: 1,
                    model: ['14', 0], positive: ['6', 0], negative: ['11', 0], latent_image: ['5', 0] }, class_type: 'KSampler', _meta: { title: 'KSampler' }
        },
        '4': { inputs: { ckpt_name: 'waiNSFWIllustrious_v140.safetensors' }, class_type: 'CheckpointLoaderSimple',
               _meta: { title: 'Load Checkpoint' } },
        '5': { inputs: { width: 1376, height: 1024, batch_size: 1 }, class_type: 'EmptyLatentImage',
               _meta: { title: 'Empty Latent Image' } },
        '6': {
          inputs: {
            text: 'masterpiece,best quality,amazing quality, 1girl, miyanabase, miyanakimono, looking at viewer, walking at beach', clip: [
              '14', 1
            ]
          }, class_type: 'CLIPTextEncode', _meta: { title: 'CLIP Text Encode (Prompt)' }
        },
        '8': { inputs: { samples: ['3', 0], vae: ['4', 2] }, class_type: 'VAEDecode', _meta: { title: 'VAE Decode' } },
        '9': { inputs: { filename_prefix: 'miyana/results', images: ['8', 0] }, class_type: 'SaveImage',
               _meta: { title: 'Save Image' } },
        '11': { inputs: { text: "bad quality,worst quality,worst detail,sketch,censor,\nnsfw", clip: ['4', 1] },
                class_type: 'CLIPTextEncode', _meta: { title: 'CLIP Text Encode (Prompt)' } },
        '12': {
          inputs: { lora_name: 'miyanabase_wai_part_try_250614_2038.safetensors', strength_model: 1.0000000000000002,
                    strength_clip: 1, model: ['4', 0], clip: ['4', 1] }, class_type: 'LoraLoader', _meta: { title: 'Load LoRA' }
        },
        '14': {
          inputs: { lora_name: 'miyanakimono_20250615_0702.safetensors', strength_model: 1, strength_clip: 1, model: ['12', 0],
                    clip: ['12', 1] }, class_type: 'LoraLoader', _meta: { title: 'Load LoRA' }
        }
      }
    end
  end
end
