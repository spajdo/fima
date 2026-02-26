#!/bin/bash

source ./common.command

start_vm_machine_default() {
  if ! podman machine ls --format "{{.Running}}" | grep -q "true"; then
    echo "Starting Podman default machine..."
    podman machine start
  fi
}

start_vm_machine() {
  local machine_name="${1:-podman-machine-default}"
  if ! podman machine ls --format "{{.Name}} {{.Running}}" | grep -q "${machine_name} true"; then
    echoDebug "Starting Podman machine: $machine_name..."
    podman machine start --name "$machine_name"
  else
    echoDebug "Machine $machine_name is already running."
  fi
}

stop_vm_machine_default() {
  if podman machine ls --format "{{.Running}}" | grep -q "true"; then
    echo "Stopping Podman default machine..."
    podman machine stop
  fi
}

stop_vm_machine() {
  local machine_name="${1:-podman-machine-default}"
  if podman machine ls --format "{{.Name}} {{.Running}}" | grep -q "${machine_name} true"; then
    echoDebug "Stopping Podman machine: $machine_name..."
    podman machine stop --name "$machine_name"
  else
    echoDebug "Machine $machine_name is not running."
  fi
}

start_service() {
  local name="$1"
  if ! podman ps --format "{{.Names}}" | grep -q "$name"; then
    echoDebug "Starting service $name..."
    podman start "$name"
  fi
}

stop_service() {
  local name="$1"
  if podman ps --format "{{.Names}}" | grep -q "$name"; then
    echoDebug "Stopping service $name..."
    podman stop "$name"
  fi
}