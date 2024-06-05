# Virtual Machine Orchestrator

## Description

This is a `sh` script created by Gari Arellano Zubía to orchestrate actions on virtual machines using `virsh` and SSH. It allows managing virtual machines through various actions such as start, stop, restart, define, undefine, list, and create new virtual machines.

## Features

- **Start**: Boot a specific virtual machine.
- **Stop**: Shut down a virtual machine.
- **Restart**: Reboot a virtual machine.
- **Define**: Define a new virtual machine.
- **Undefine**: Remove the definition of a virtual machine.
- **List**: List all virtual machines.
- **Create**: Create a new virtual machine by cloning a base image.

## Usage

### Help

To get help on using the script, run:

```sh
./orchestrator-vm.sh help
