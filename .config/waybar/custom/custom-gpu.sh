#!/bin/bash

# Parse GPU utilization from nvidia-smi
usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

echo "{ \"text\": \"󰍹  ${usage}%\", \"tooltip\": \"NVIDIA GPU usage: ${usage}%\" }"
