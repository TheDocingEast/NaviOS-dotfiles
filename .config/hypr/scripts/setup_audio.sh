#!/bin/bash
# ~/.config/hypr/scripts/setup_audio.sh

# Ждём пока PipeWire поднимется
until pactl info &>/dev/null; do
  sleep 0.5
done

sleep 1 # небольшой буфер после готовности

pactl load-module module-null-sink sink_name=VirtualMic sink_properties=device.description=VirtualMic
pactl load-module module-null-sink sink_name=Combined sink_properties=device.description=Combined
pactl load-module module-loopback source=alsa_input.usb-3142_fifine_Microphone-00.analog-stereo sink=Combined latency_msec=1
pactl load-module module-loopback source=VirtualMic.monitor sink=Combined latency_msec=1
pactl load-module module-virtual-source source_name=CombinedMic master=Combined.monitor
