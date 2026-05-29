import pytest
import torch
import torch_npu  


def test_fsdp_import():
    try:
        from torch.distributed.fsdp import FullyShardedDataParallel as FSDP
    except ImportError:
        pytest.skip("FSDP not available in this environment")
    assert FSDP is not None


def test_npu_available():
    assert torch.npu.is_available(), "NPU is not available"
    print(f"NPU device count: {torch.npu.device_count()}")
    if torch.npu.device_count() > 0:
        print(f"Current NPU device: {torch.npu.current_device()}")
