#!/bin/bash

# Parse GPU utilization from nvidia-smi
usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)

echo "{ \"text\": \"󰍹 ${usage}%\", \"tooltip\": \"GPU usage: ${usage}%\nGPU temp: ${temp}°C\" }"
