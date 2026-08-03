#!/usr/bin/env bash


## CUDA 13.0

export CUDA_HOME=/root/g00806422/envs/cuda-13.0
export CUDA_PATH="$CUDA_HOME"
export CUDACXX="$CUDA_HOME/bin/nvcc"

export PATH="$CUDA_HOME/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

echo "CUDA_HOME=$CUDA_HOME"
nvcc --version