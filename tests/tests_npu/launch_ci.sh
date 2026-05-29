#!/bin/bash
set -e

WORKSPACE=$1
pr_id=$2
branch=$3

echo "------------------------------------------------"
echo "🔍 预检：当前目标分支为 [ ${branch} ]，工作区为 [ ${WORKSPACE} ]"

# 1. 根据分支判断要使用的 Docker 镜像或容器名称
case "$branch" in
    "v0.2.2")
        DOCKER_IMAGE="slime-ascend_ci:0.2.2_no-patch"
        CONTAINER_NAME="slime-ascend-0.2.2-runner"
        ;;
    "main" | "master" | "v0.2.4")
        DOCKER_IMAGE="slime-ascend_ci:0.2.4_no-patch"
        CONTAINER_NAME="slime-ascend-0.2.4-runner"
        ;;
    *)
        echo "⚠️ 错误: 不支持的分支 [ ${branch} ]，支持的分支: 0.2.2/0.2.4"
        exit 1
        ;;
esac
echo "调度：即将启动容器 [ ${CONTAINER_NAME} ] (镜像: ${DOCKER_IMAGE})"

# 2. 启动容器并在容器内执行测试脚本
docker run --rm \
    --name "${CONTAINER_NAME}" \
    --device=/dev/davinci_manager \
    --device=/dev/devmm_svm \
    --device=/dev/hisi_hdc \
    --device=/dev/davinci0 \
    --device=/dev/davinci1 \
    --device=/dev/davinci2 \
    --device=/dev/davinci3 \
    --device=/dev/davinci4 \
    --device=/dev/davinci5 \
    --device=/dev/davinci6 \
    --device=/dev/davinci7 \
    -e ASCEND_RT_VISIBLE_DEVICES="0,1,2,3,4,5,6,7" \
    -e ASCEND_VISIBLE_DEVICES="0,1,2,3,4,5,6,7" \
    -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
    -v /usr/local/Ascend/firmware:/usr/local/Ascend/firmware \
    -v /usr/local/sbin/:/usr/local/sbin/ \
    -v /usr/sbin/:/usr/sbin/ \
    -v /home/:/home/ \
    -v /data/:/data/ \
    -v /efs_rl:/efs_rl \
    -v "${WORKSPACE}:/workspace/slime-ascend" \
    "${DOCKER_IMAGE}" \
    /bin/bash -c "bash /workspace/slime-ascend/tests/tests_npu/slime-ascend_ut.sh /workspace/slime-ascend ${pr_id} ${branch}"

echo "容器内任务执行完毕，容器已安全退出。"