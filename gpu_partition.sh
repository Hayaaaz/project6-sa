#!/usr/bin/env bash
# gpu_partition.sh — carve one NVIDIA data-center GPU into MIG instances.
# Reference/teaching script for System Administration and Maintenance, Chapter 6. Read it; do not blind-run it.
#
# Verified against the A100/H100/H200/B200 MIG model (max 7 instances).
# Requires: nvidia-smi, root, a MIG-capable GPU (A100/H100/H200/B200/RTX PRO 6000 Blackwell),
# and that NO process is using the GPU (MIG mode toggle resets the device).
#
# SAFETY: enabling/disabling MIG resets the GPU. Never run on a card with live work.
set -euo pipefail

GPU="${1:-0}"   # GPU index to partition (default 0)

echo "==> GPU $GPU before partitioning:"
nvidia-smi -i "$GPU" --query-gpu=name,memory.total,mig.mode.current --format=csv

# 1) Enable MIG mode (idempotent; no-op if already enabled). Resets the GPU.
echo "==> Enabling MIG mode on GPU $GPU (this resets the device)..."
sudo nvidia-smi -i "$GPU" -mig 1

# 2) List the GPU Instance (GI) profiles this card supports.
echo "==> Available GPU Instance profiles:"
sudo nvidia-smi mig -i "$GPU" -lgip

# 3) Create a mixed partition: one 3g (large) + four 1g (small) = 7 compute slices.
#    Profile IDs vary by card; -lgip prints the IDs. On H100 80GB: 9=3g.40gb, 19=1g.10gb.
#    Edit the IDs below to match YOUR card's -lgip output before running.
echo "==> Creating GPU Instances (one 3g.large + four 1g.small)..."
sudo nvidia-smi mig -i "$GPU" -cgi 9,19,19,19,19 -C   # -C also creates the Compute Instances

# 4) Show the resulting instances. Each is an isolated, addressable device.
echo "==> Partition result:"
sudo nvidia-smi mig -i "$GPU" -lgi
nvidia-smi -L | grep -i mig || true

cat <<'NOTE'

Done. Each MIG instance now appears as its own MIG-<UUID>. Pin a workload to one with:
  CUDA_VISIBLE_DEVICES=MIG-<UUID>  python serve.py
To tear it all down (free the slices, then disable MIG):
  sudo nvidia-smi mig -i 0 -dci && sudo nvidia-smi mig -i 0 -dgi && sudo nvidia-smi -i 0 -mig 0
Remember: the MIG ceiling is 7 instances even on a 180GB B200 — memory grows, slice count does not.
NOTE
