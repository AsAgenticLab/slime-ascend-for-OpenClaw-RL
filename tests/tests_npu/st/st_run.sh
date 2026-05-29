#!/bin/bash

# 使用 -print0 处理路径中的空格
#SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR=/workspace/slime-ascend/tests/tests_npu/st
test_scripts=$(find "$SCRIPT_DIR" -name "run-*.sh")
for script in $test_scripts; do
    echo "正在执行脚本: $script"

    # 执行脚本，并捕获错误
    if ! bash "$script"; then
        echo "脚本执行失败: $script"
        exit 1
    fi

    echo "任务执行完成": $script
    ray stop --force
    ps -ef | grep torchrun | grep -v grep | awk '{print $2}' | xargs -r kill -9
    echo "计算资源清理完成"

done