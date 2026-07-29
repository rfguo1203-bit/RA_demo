#!/usr/bin/env bash


# =========================
# Root paths
# =========================

export WORK_ROOT="/home/robots/g00806422/demo"

export BEHAVIOR_ROOT="$WORK_ROOT/../BEHAVIOR-1K"

export OPENPI_ROOT="$WORK_ROOT/openpi-comet"
export OPENPI_DIR="$OPENPI_ROOT"


# =========================
# Cache
# =========================

export CHECKPOINT_ROOT="$WORK_ROOT/checkpoints"

export CACHE_ROOT="$WORK_ROOT/cache"

export OPENPI_DATA_HOME="$CACHE_ROOT/openpi"

export HF_HOME="$CACHE_ROOT/huggingface"

export XDG_CACHE_HOME="$CACHE_ROOT/xdg"


# =========================
# BEHAVIOR dataset
# =========================

export PATH_TO_BEHAVIOR_1K="$BEHAVIOR_ROOT"

export DATA_ROOT="$BEHAVIOR_ROOT/datasets/2026-challenge-demos"

export DATASET_PATH="$DATA_ROOT"

export REPO_ID="behavior-1k/2026-challenge-demos"


# =========================
# Task
# =========================

export TASK_NAME="turning_on_radio"

# =========================
# Policy server
# =========================

export SERVER_HOST="127.0.0.1"
export SERVER_PORT="8127"


export CONTROL_MODE="receeding_horizon"

export MAX_LEN="32"


export POLICY_CONFIG="pi05_b1k-base"


export RADIO_CKPT="$WORK_ROOT/ckpts/sunshk/pi05_turn_on_the_radio_sunshk"


# =========================
# GPU
# =========================

export SERVER_CUDA_VISIBLE_DEVICES="1"

export EVAL_CUDA_VISIBLE_DEVICES="0"


# =========================
# Python
# =========================

export BEHAVIOR_PYTHON="/home/robots/miniconda3/envs/behavior/bin/python"
