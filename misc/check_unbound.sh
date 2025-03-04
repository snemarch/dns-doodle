#!/bin/bash

UNBOUND1_IP="192.168.100.2"
UNBOUND2_IP="192.168.100.3"
FLOATING_IP="192.168.100.100"

# Find the actual interface names assigned to the Unbound containers
UNBOUND1_IF=$(ip -4 addr show | grep "inet $UNBOUND1_IP" | awk '{print $NF}')
UNBOUND2_IF=$(ip -4 addr show | grep "inet $UNBOUND2_IP" | awk '{print $NF}')

# Function to assign the floating IP to a container
assign_ip() {
    local target_if=$1
    if ! ip addr show dev "$target_if" | grep -q "$FLOATING_IP"; then
        echo "Assigning $FLOATING_IP to $target_if"
        ip addr add "$FLOATING_IP/24" dev "$target_if"
    fi
}

# Function to remove the floating IP from a container
remove_ip() {
    local target_if=$1
    if ip addr show dev "$target_if" | grep -q "$FLOATING_IP"; then
        echo "Removing $FLOATING_IP from $target_if"
        ip addr del "$FLOATING_IP/24" dev "$target_if"
    fi
}

# Check if unbound1 is healthy
if docker inspect --format '{{.State.Health.Status}}' unbound1 2>/dev/null | grep -q "healthy"; then
    echo "Unbound1 is healthy - assigning floating IP"
    assign_ip "$UNBOUND1_IF"
    remove_ip "$UNBOUND2_IF"
    exit 0  # Unbound1 gets the floating IP
fi

# Check if unbound2 is healthy
if docker inspect --format '{{.State.Health.Status}}' unbound2 2>/dev/null | grep -q "healthy"; then
    echo "Unbound2 is healthy - assigning floating IP"
    assign_ip "$UNBOUND2_IF"
    remove_ip "$UNBOUND1_IF"
    exit 0  # Unbound2 gets the floating IP
fi

# If neither container is healthy, remove the floating IP entirely
echo "No healthy Unbound instances - removing floating IP"
remove_ip "$UNBOUND1_IF"
remove_ip "$UNBOUND2_IF"
exit 1
