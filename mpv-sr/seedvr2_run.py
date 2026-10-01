#!/usr/bin/env python3
"""Run the installed SeedVR2 CLI on Spark with explicit phase memory cleanup."""
from functools import wraps
from pathlib import Path
import os
import runpy
import sys


def with_memory_release(cleanup, clear_memory):
    """Release unused allocator blocks only after upstream model cleanup returns."""
    @wraps(cleanup)
    def release(*args, **kwargs):
        result = cleanup(*args, **kwargs)
        clear_memory(deep=True, force=True)
        return result
    return release


def main():
    repo = Path.home() / 'seedvr2-bench/ComfyUI-SeedVR2_VideoUpscaler'
    # Set this before the dependency warmup imports torch, as the upstream CLI does.
    os.environ.setdefault('PYTORCH_CUDA_ALLOC_CONF', 'backend:cudaMallocAsync')

    # SeedVR2 installs a flash_attn stub. Warm these imports before that stub can
    # confuse transformers' package-metadata checks on systems without FlashAttention.
    import transformers.modeling_flash_attention_utils  # noqa: F401
    import transformers.integrations.flash_attention  # noqa: F401
    from transformers import AutoImageProcessor  # noqa: F401
    from diffusers.loaders import single_file_model  # noqa: F401
    import diffusers.models.autoencoders.vae  # noqa: F401
    import diffusers.models.transformers  # noqa: F401

    sys.path.insert(0, str(repo))
    from src.core import generation_phases
    from src.optimization.memory_manager import clear_memory

    # On UMA the CPU and CUDA allocators compete for the same physical memory.
    # Upstream only performs deep cleanup between streaming chunks. Also release
    # unused blocks after DiT and VAE disposal, before the next phase allocates.
    for name in ('cleanup_dit', 'cleanup_vae'):
        original = getattr(generation_phases, name)
        setattr(generation_phases, name, with_memory_release(original, clear_memory))
    print('[runner] enabled allocator cleanup after DiT and VAE disposal', flush=True)
    sys.argv[0] = str(repo / 'inference_cli.py')
    runpy.run_path(sys.argv[0], run_name='__main__')


if __name__ == '__main__':
    main()
