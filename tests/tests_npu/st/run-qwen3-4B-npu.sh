#为了确保 Ray 的子进程（Worker）也能拿到这个变量
export PYTHONPATH=$PYTHONPATH:/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:/usr/local/Ascend/ascend-toolkit/latest/opp/built-in/op_impl/ai_core/tbe
unset http_proxy https_proxy
set -ex

# will prevent ray from buffering stdout/stderr
export PYTHONBUFFERED=1

export PYTHONPATH="/workspace/Megatron-LM:/workspace/sglang/python:/workspace/MindSpeed:/workspace/Megatron-Bridge/src:$PYTHONPATH"
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export HYDRA_FULL_ERROR=1
export CUDA_DEVICE_MAX_CONNECTIONS=1

# Slime enabled by default
export SLIME_ENABLE_PROFILING=False

export RAY_EXPERIMENTAL_NOSET_ASCEND_RT_VISIBLE_DEVICES=1
export RAY_DEBUG=1
export RAY_DEDUP_LOGS=0

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export HCCL_HOST_SOCKET_PORT_RANGE=60000-60050
export HCCL_NPU_SOCKET_PORT_RANGE=61000-61050

source "/home/slime-ascend_CI/slime-ascend/models/qwen3-4B.sh"
#权重路径换成本地
CKPT_ARGS=(
   --hf-checkpoint /home/slime-ascend_CI/slime-ascend/weights/qwen3-4b-sft
   --ref-load /home/slime-ascend_CI/slime-ascend/weights/qwen3-4b-sft_torch_dist
   --load /root/slime
   --save /root/slime
   --save-interval 20
)

ROLLOUT_ARGS=(
   --prompt-data /home/slime-ascend_CI/slime-ascend/datasets/dapo-math-17k/dapo-math-17k.jsonl   #路径更换
   --input-key prompt
   --label-key label
   --apply-chat-template
   --rollout-shuffle
   --rm-type deepscaler
   --num-rollout 1
   --rollout-batch-size 8
   --n-samples-per-prompt 8
   --rollout-max-response-len $((1024 * 2))
   --rollout-temperature 1

   --global-batch-size 64
   --balance-data
)

EVAL_ARGS=(
   --eval-interval 20
   --eval-prompt-data aime /home/slime-ascend_CI/slime-ascend/datasets/aime-2024/aime-2024.jsonl  #路径更换
   --n-samples-per-eval-prompt 1
   --eval-max-response-len 16384
   --eval-top-p 1
)

PERF_ARGS=(
   --tensor-model-parallel-size 2
   --sequence-parallel
   --pipeline-model-parallel-size 1
   --context-parallel-size 1
   --expert-model-parallel-size 1
   --expert-tensor-parallel-size 1
   #--num-experts 16
   --recompute-granularity full
   --recompute-method uniform
   --recompute-num-layers 1

   --use-dynamic-batch-size
   --max-tokens-per-gpu 8192
)

GRPO_ARGS=(
   --advantage-estimator grpo
   --use-kl-loss
   --kl-loss-coef 0.00
   --kl-loss-type low_var_kl
   --entropy-coef 0.00
   --eps-clip 0.2
   --eps-clip-high 0.28
)

OPTIMIZER_ARGS=(
   --optimizer adam
   --lr 1e-6
   --lr-decay-style constant
   --weight-decay 0.1
   --adam-beta1 0.9
   --adam-beta2 0.98

   --optimizer-cpu-offload
   --overlap-cpu-optimizer-d2h-h2d
   --use-precision-aware-optimizer
   --use-distributed-optimizer
)

SGLANG_ARGS=(
   --rollout-num-gpus-per-engine 2
   --sglang-mem-fraction-static 0.7
   --sglang-cuda-graph-max-bs 16
   --sglang-max-running-requests 64
   
   # ======================= NPU 添加参数 =======================
   --sglang-device npu
)

MISC_ARGS=(
   # default dropout in megatron is 0.1
   --attention-dropout 0.0
   --hidden-dropout 0.0
   # should be good for model performance
   --accumulate-allreduce-grads-in-fp32
   --attention-softmax-in-fp32
   # need to comment this when using model with MLA
   --attention-backend flash

   --moe-token-dispatcher-type alltoall
   # --no-gradient-accumulation-fusion
   --train-iters 1
   --no-gradient-accumulation-fusion
   --no-masked-softmax-fusion
   --no-bias-dropout-fusion
)

# launch the master node of ray in container
export MASTER_ADDR=${MASTER_ADDR:-"127.0.0.1"}
ray start --head --dashboard-host=0.0.0.0 --dashboard-port=8265 --disable-usage-stats

export PYTHONPATH="/workspace/slime-ascend:/workspace/sglang/python:/workspace/Megatron-LM:/workspace/Megatron-Bridge/src:$PYTHONPATH"
RUNTIME_ENV_JSON='{
  "env_vars": {
    "PYTHONPATH": "/workspace/slime-ascend:/workspace/Megatron-LM:/workspace/MindSpeed:/workspace/sglang/python:/workspace/Megatron-Bridge/src:/usr/local/Ascend/cann-8.5.0/python/site-packages:/usr/local/Ascend/cann-8.5.0/opp/built-in/op_impl/ai_core/tbe",
    "PYTORCH_NPU_ALLOC_CONF": "expandable_segments:True",
    "PYTHONUNBUFFERED": "1",
    "CUDA_DEVICE_MAX_CONNECTIONS": "1",
    "ASCEND_TOOLKIT_HOME": "/usr/local/Ascend/ascend-toolkit/latest/",
    "ASCEND_HOME_PATH": "/usr/local/Ascend/ascend-toolkit/latest/",
    "HCCL_IF_IP": "127.0.0.1",
    "TP_SOCKET_IFNAME": "lo",
    "GLOO_SOCKET_IFNAME": "lo"
  }
}'
LD_LIBRARY_PATH="/usr/local/Ascend/ascend-toolkit/latest/lib64:/usr/local/Ascend/driver/lib64/driver:/usr/local/python3.11.14/lib"
cd /workspace/slime-ascend
ray job submit --address="http://127.0.0.1:8265" \
   --runtime-env-json="${RUNTIME_ENV_JSON}" \
   -- python3 train.py \
   --actor-num-nodes 1 \
   --actor-num-gpus-per-node 4 \
   --rollout-num-gpus 4 \
   --num-gpus-per-node 4 \
   --num-steps-per-rollout 1 \
   ${MODEL_ARGS[@]} \
   ${ROLLOUT_ARGS[@]} \
   ${OPTIMIZER_ARGS[@]} \
   ${GRPO_ARGS[@]} \
   ${WANDB_ARGS[@]} \
   ${PERF_ARGS[@]} \
   ${SGLANG_ARGS[@]} \
   ${MISC_ARGS[@]} \
   ${SPEC_ARGS[@]} \
   ${CKPT_ARGS[@]} \
   ${EVAL_ARGS[@]}; \
   echo "Training finished, cleaning up..." && \
   rm -rf /root/slime