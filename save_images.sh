#!/usr/bin/env bash

set -e
set -o pipefail

mkdir containerd_images || echo

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

IMAGES_FILE="images.txt"
kubectl get pods --all-namespaces -o jsonpath='{..image}' | tr -s '[[:space:]]' '\n' | sort -u >"$IMAGES_FILE"

echo "[INFO] Found $(wc -l <"$IMAGES_FILE") unique images."

while read -r IMAGE; do
	[ -z "$IMAGE" ] && continue # 跳过空行

	FILENAME=$(echo "$IMAGE" | tr '/:' '_').tar
	echo "[INFO] Processing image: $IMAGE -> $FILENAME"

	# 拉取镜像
	case "$RUNTIME" in
	nerdctl | docker)
		#$RUNTIME pull "$IMAGE"
		$RUNTIME save -o containerd_images/"$FILENAME" "$IMAGE"
		;;
	ctr)
		#ctr --namespace k8s.io images pull "$IMAGE"
		ctr --namespace k8s.io images export containerd_images/"$FILENAME" "$IMAGE"
		;;
	esac

	echo "[INFO] Saved $IMAGE as $FILENAME"
done <"$IMAGES_FILE"

echo "[INFO] All images exported successfully!"
