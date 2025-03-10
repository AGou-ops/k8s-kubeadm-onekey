#!/usr/bin/env bash

set -e  # 遇到错误退出
set -o pipefail  # 防止错误被管道吞掉

# 检查运行时环境
if command -v nerdctl &>/dev/null; then
    RUNTIME="nerdctl"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
elif command -v ctr &>/dev/null; then
    RUNTIME="ctr"
else
    echo "[ERROR] No supported container runtime found (nerdctl, docker, ctr)"
    exit 1
fi

echo "[INFO] Using runtime: $RUNTIME"

# 获取所有命名空间的镜像，并去重
IMAGES_FILE="images.txt"
kubectl get pods --all-namespaces -o jsonpath='{..image}' | tr -s '[[:space:]]' '\n' | sort -u > "$IMAGES_FILE"

echo "[INFO] Found $(wc -l < "$IMAGES_FILE") unique images."

# 拉取并保存镜像
while read -r IMAGE; do
    [ -z "$IMAGE" ] && continue  # 跳过空行

    FILENAME=$(echo "$IMAGE" | tr '/:' '_').tar
    echo "[INFO] Processing image: $IMAGE -> $FILENAME"

    # 拉取镜像
    case "$RUNTIME" in
        nerdctl|docker)
            #$RUNTIME pull "$IMAGE"
            $RUNTIME save -o "$FILENAME" "$IMAGE"
            ;;
        ctr)
            #ctr --namespace k8s.io images pull "$IMAGE"
            ctr --namespace k8s.io images export "$FILENAME" "$IMAGE"
            ;;
    esac

    echo "[INFO] Saved $IMAGE as $FILENAME"
done < "$IMAGES_FILE"

echo "[INFO] All images exported successfully!"
