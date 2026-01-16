#!/usr/bin/env python3
"""Find an available simulator for a given platform."""

import json
import sys


def find_simulator(platform: str) -> str | None:
    """Find the first available simulator for the given platform.

    Args:
        platform: The platform name (iOS, watchOS, tvOS)

    Returns:
        The UDID of an available simulator, or None if not found.
    """
    data = json.load(sys.stdin)
    devices = data["devices"]
    runtime_prefix = f"com.apple.CoreSimulator.SimRuntime.{platform}"

    for runtime, devs in devices.items():
        if runtime.startswith(runtime_prefix):
            for device in devs:
                if device.get("isAvailable", False):
                    return device["udid"]
    return None


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <platform>", file=sys.stderr)
        print("Example: xcrun simctl list devices available -j | ./find-simulator.py iOS", file=sys.stderr)
        return 1

    platform = sys.argv[1]
    udid = find_simulator(platform)

    if udid:
        print(udid)
        return 0
    else:
        print(f"No available simulator found for platform: {platform}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
