#!/usr/bin/env bash
set -euo pipefail

echo "[fsm9] Checking for FSM-9 USB device..."

# Find the bus/device for the FSM-9 using VID:PID 1d5a:c0e0
line="$(lsusb | awk '/1d5a:c0e0/ {print $2, $4}' | head -n1)"

if [ -z "${line}" ]; then
  echo "[fsm9] ERROR: FSM-9 not found in lsusb."
  echo "[fsm9] Make sure the device is attached from Windows PowerShell:"
  echo "       usbipd list"
  echo "       usbipd attach --wsl --busid <BUSID>"
  exit 1
fi

bus="$(echo "$line" | awk '{print $1}')"
dev="$(echo "$line" | awk '{print $2}' | tr -d ':')"

usb_node="/dev/bus/usb/${bus}/${dev}"

echo "[fsm9] Found FSM-9 at ${usb_node}"

echo "[fsm9] Fixing USB device permissions..."
sudo chmod 666 "${usb_node}"

echo "[fsm9] Checking hidraw devices..."
if ls /dev/hidraw* >/dev/null 2>&1; then
  echo "[fsm9] Fixing hidraw permissions..."
  sudo chmod 666 /dev/hidraw*
  ls -l /dev/hidraw*
else
  echo "[fsm9] WARNING: No /dev/hidraw* devices found."
  echo "[fsm9] The ROS node may fail if the FSM-9 HID interface was not created."
fi

echo "[fsm9] Sourcing ROS environment..."
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash

echo "[fsm9] Launching FSM-9 ROS node..."
exec roslaunch fsm_imu fsm9.launch
