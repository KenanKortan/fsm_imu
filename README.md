# Freespace FSM-9 IMU ROS Node

## Attribution

This repository is a fork/adaptation of the original `fsm_imu` ROS node by Jordan Ford:

https://github.com/jsford/fsm_imu

The original project provides the ROS node for reading the Hillcrest Labs Freespace FSM-9 IMU through `libfreespace` and publishing `sensor_msgs/Imu` data.

This fork adds ROS Noetic/Ubuntu 20.04 WSL2 setup documentation, `usbipd-win` USB passthrough workflow, HID/USB permission helper scripts, troubleshooting notes, and verified launch instructions for the tested environment.

Original authorship and Git history are preserved.

## License Note

The upstream repository does not currently include an explicit license file, and `package.xml` lists `<license>TODO</license>`. Original source code remains subject to the upstream author's rights. This fork preserves attribution and history and adds documentation/setup scripts for the tested WSL2 environment.

# Freespace FSM-9 ROS Node

Unofficial ROS Noetic node for the Hillcrest Labs Freespace FSM-9 9-axis IMU.

This package reads MotionEngine output from the FSM-9 through the Hillcrest/Freespace `libfreespace` library and publishes standard ROS `sensor_msgs/Imu` messages.

## Tested Environment

* Windows host machine
* WSL2
* Ubuntu 20.04.6 LTS
* ROS Noetic
* `usbipd-win` for USB passthrough from Windows to WSL2
* Hillcrest Labs Freespace FSM-9 IMU
* Device VID:PID: `1d5a:c0e0`

## ROS Output

The node publishes:

| Topic       | Type              | Rate                 |
| ----------- | ----------------- | -------------------- |
| `/imu/data` | `sensor_msgs/Imu` | approximately 125 Hz |

Default launch parameters:

| Parameter   | Default     | Meaning                             |
| ----------- | ----------- | ----------------------------------- |
| `period_us` | `8000`      | Sensor period in microseconds       |
| `frame_id`  | `/imu`      | Frame ID used in ROS message header |
| `topic`     | `/imu/data` | Output IMU topic                    |

Since `period_us = 8000`, the expected output rate is:

```text
1 / 0.008 s = 125 Hz
```

## Project Structure

```text
fsm_imu/
├── CMakeLists.txt
├── package.xml
├── README.md
├── cmake/
│   └── FindFreespace.cmake
├── docs/
│   ├── 1000-3075-FSM-9-Datasheet_1.pdf
│   └── fsm-9.png
├── launch/
│   └── fsm9.launch
└── src/
    └── fsm_imu_node.cpp
```

## Software Architecture

```text
FSM-9 IMU hardware
  ↓ USB HID
Windows host
  ↓ usbipd-win
WSL2 Ubuntu 20.04
  ↓ /dev/bus/usb/... and /dev/hidraw*
libfreespace
  ↓ freespace_readMessage()
fsm_imu_node
  ↓ sensor_msgs/Imu
/imu/data
```

## Build Dependency

This package depends on Hillcrest/Freespace `libfreespace`.

The CMake module `cmake/FindFreespace.cmake` searches for:

```text
/usr/local/include/freespace/freespace.h
/usr/include/freespace/freespace.h
/usr/local/lib/libfreespace.so
/usr/lib/libfreespace.so
/lib/libfreespace.so
```

If the package fails to build, confirm that `libfreespace.so` and the Freespace headers are installed.

## Launch File

The default launch file is:

```bash
roslaunch fsm_imu fsm9.launch
```

It starts:

```text
Node name: /fsm_imu
Executable: fsm_imu_node
Topic: /imu/data
Message type: sensor_msgs/Imu
Frame ID: /imu
Period: 8000 us
Rate: ~125 Hz
```

## WSL2 USB Setup

The FSM-9 is physically connected to Windows and passed into Ubuntu WSL2 using `usbipd-win`.

### 1. Start Ubuntu WSL2

In PowerShell:

```powershell
wsl -d Ubuntu-20.04
```

Keep this Ubuntu terminal open.

### 2. Attach FSM-9 to WSL2

In PowerShell:

```powershell
usbipd list
usbipd attach --wsl --busid 2-1
usbipd list
```

The FSM-9 should appear as:

```text
1d5a:c0e0  USB Input Device  Attached
```

The bus ID may change. Use the current bus ID shown by:

```powershell
usbipd list
```

## Running the Node in Ubuntu

A helper script is used to fix WSL2 USB/HID permissions and launch the ROS node:

```bash
~/fsm9_wsl_fix_and_run.sh
```

This script:

1. Finds the FSM-9 in `lsusb` using VID:PID `1d5a:c0e0`.
2. Fixes permissions on `/dev/bus/usb/...`.
3. Fixes permissions on `/dev/hidraw*`.
4. Sources the ROS/catkin environment.
5. Runs `roslaunch fsm_imu fsm9.launch`.

## Verify Operation

Open a second Ubuntu terminal and run:

```bash
source /opt/ros/noetic/setup.bash
source ~/catkin_ws/devel/setup.bash
```

List topics:

```bash
rostopic list
```

Expected:

```text
/imu/data
/rosout
/rosout_agg
```

Check message type:

```bash
rostopic type /imu/data
```

Expected:

```text
sensor_msgs/Imu
```

Check rate:

```bash
rostopic hz /imu/data
```

Expected:

```text
average rate: approximately 125 Hz
```

Check one message:

```bash
rostopic echo -n 1 /imu/data
```

Expected fields include:

```text
header
orientation
angular_velocity
linear_acceleration
```

## Troubleshooting

### `usbipd: error: The selected WSL distribution is not running`

Open Ubuntu first:

```powershell
wsl -d Ubuntu-20.04
```

Keep the Ubuntu terminal open, then retry:

```powershell
usbipd attach --wsl --busid 2-1
```

### FSM-9 not found in Ubuntu

Check PowerShell:

```powershell
usbipd list
```

The device should show as `Attached`.

Then check Ubuntu:

```bash
lsusb | grep -i 1d5a
```

Expected:

```text
ID 1d5a:c0e0 Hillcrest Laboratories Freespace(R) Adapter F
```

### Permission errors

Check HID permissions:

```bash
ls -l /dev/hidraw*
```

If they are root-only, run:

```bash
~/fsm9_wsl_fix_and_run.sh
```

or manually:

```bash
sudo chmod 666 /dev/hidraw*
```

### `Error opening device: -6`

This can happen if the device is already open, if a stale ROS node is running, or if WSL has stale duplicate USB/HID devices.

First stop old ROS processes:

```bash
killall -9 rosmaster roslaunch fsm_imu_node 2>/dev/null || true
```

Then detach and reattach from PowerShell:

```powershell
usbipd detach --busid 2-1
usbipd attach --wsl --busid 2-1
```

If the problem persists, restart WSL:

```powershell
wsl --shutdown
```

Then reopen Ubuntu and attach the device again.

### Duplicate FSM-9 entries in `lsusb`

If Ubuntu shows multiple entries like:

```text
Bus 001 Device 002: ID 1d5a:c0e0 ...
Bus 001 Device 003: ID 1d5a:c0e0 ...
```

detach and reattach the device:

```powershell
usbipd detach --busid 2-1
usbipd attach --wsl --busid 2-1
```

If needed:

```powershell
wsl --shutdown
```

## Known Limitations

* The node selects the first Freespace device returned by `libfreespace`.
* Multiple or stale Freespace devices can cause open errors.
* Magnetometer data is read internally but not currently published as a separate `sensor_msgs/MagneticField` topic.
* Covariance values are published as zeros.
* The default `frame_id` is `/imu`; for TF-based systems, `imu` without the leading slash may be preferable.
* The node uses `ros::Time::now()` rather than a hardware timestamp.

## Useful Commands

Record IMU data:

```bash
rosbag record /imu/data
```

Echo IMU data:

```bash
rostopic echo /imu/data
```

Check node info:

```bash
rosnode info /fsm_imu
```

Check rate:

```bash
rostopic hz /imu/data
```

