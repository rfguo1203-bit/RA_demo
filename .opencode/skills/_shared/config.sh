#!/usr/bin/env bash

# Shared server-side configuration for interactive BEHAVIOR skills.

# =========================
# Root paths
# =========================

export WORK_ROOT="${WORK_ROOT:-/home/robots/g00806422/demo}"
export BEHAVIOR_ROOT="${BEHAVIOR_ROOT:-$WORK_ROOT/../BEHAVIOR-1K}"
export OPENPI_ROOT="${OPENPI_ROOT:-$WORK_ROOT/openpi-comet}"
export OPENPI_DIR="${OPENPI_DIR:-$OPENPI_ROOT}"

# =========================
# Cache
# =========================

export CHECKPOINT_ROOT="${CHECKPOINT_ROOT:-$WORK_ROOT/checkpoints}"
export CACHE_ROOT="${CACHE_ROOT:-$WORK_ROOT/cache}"
export OPENPI_DATA_HOME="${OPENPI_DATA_HOME:-$CACHE_ROOT/openpi}"
export HF_HOME="${HF_HOME:-$CACHE_ROOT/huggingface}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$CACHE_ROOT/xdg}"

# =========================
# BEHAVIOR dataset
# =========================

export PATH_TO_BEHAVIOR_1K="${PATH_TO_BEHAVIOR_1K:-$BEHAVIOR_ROOT}"
export DATA_ROOT="${DATA_ROOT:-$BEHAVIOR_ROOT/datasets/2026-challenge-demos}"
export DATASET_PATH="${DATASET_PATH:-$DATA_ROOT}"
export REPO_ID="${REPO_ID:-behavior-1k/2026-challenge-demos}"

# =========================
# Task defaults
# =========================

export TASK_NAME="${TASK_NAME:-turning_on_radio}"
export INSTANCE_INDICES="${INSTANCE_INDICES:-0}"
export NUM_ROLLOUTS="${NUM_ROLLOUTS:-1}"
export MODE="${MODE:-public_test}"
export MAX_STEPS="${MAX_STEPS:-}"
export K_STEPS="${K_STEPS:-20}"
export MAX_HOST_ROUNDS="${MAX_HOST_ROUNDS:-50}"

# =========================
# VLA server
# =========================

export UV_BIN="${UV_BIN:-uv}"
export SERVER_HOST="${SERVER_HOST:-127.0.0.1}"
export SERVER_PORT="${SERVER_PORT:-8127}"
export SERVER_START_TIMEOUT_SECONDS="${SERVER_START_TIMEOUT_SECONDS:-900}"
export CONTROL_MODE="${CONTROL_MODE:-receeding_horizon}"
export MAX_LEN="${MAX_LEN:-32}"
export POLICY_CONFIG="${POLICY_CONFIG:-pi05_b1k-base}"
export RADIO_CKPT="${RADIO_CKPT:-$WORK_ROOT/ckpts/sunshk/pi05_turn_on_the_radio_sunshk}"
export HALLOWEEN_CKPT="${HALLOWEEN_CKPT:-}"

# =========================
# Env server
# =========================

export ENV_SERVER_HOST="${ENV_SERVER_HOST:-127.0.0.1}"
export ENV_SERVER_PORT="${ENV_SERVER_PORT:-8137}"
export ENV_SERVER_START_TIMEOUT_SECONDS="${ENV_SERVER_START_TIMEOUT_SECONDS:-900}"
export ENV_WRAPPER="${ENV_WRAPPER:-omnigibson.eval.wrappers.DefaultWrapper}"
export WRITE_VIDEO="${WRITE_VIDEO:-1}"
export VIDEO_FPS="${VIDEO_FPS:-30}"
export HEADLESS="${HEADLESS:-1}"
export ROBOT_CONFIG="${ROBOT_CONFIG:-}"

# =========================
# GPU
# =========================

export SERVER_CUDA_VISIBLE_DEVICES="${SERVER_CUDA_VISIBLE_DEVICES:-1}"
export EVAL_CUDA_VISIBLE_DEVICES="${EVAL_CUDA_VISIBLE_DEVICES:-0}"

# =========================
# Python
# =========================

export BEHAVIOR_PYTHON="${BEHAVIOR_PYTHON:-/home/robots/miniconda3/envs/behavior/bin/python}"

# =========================
# Runtime state
# =========================

export BEHAVIOR_INTERACTIVE_ROOT="${BEHAVIOR_INTERACTIVE_ROOT:-$WORK_ROOT/logs/behavior_interactive}"
