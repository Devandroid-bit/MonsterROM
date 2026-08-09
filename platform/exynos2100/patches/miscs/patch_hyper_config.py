#!/usr/bin/env python3

import copy
import json
import os
import sys
import tempfile


ALIASES = {
    "CPULittleMinFreq": "CPUMinFreq",
    "DDRMinFreq": "MIFMinFreq",
}

UNSUPPORTED_REFERENCES = {
    "CoreNumBigMin",
    "CoreNumMax",
    "CoreNumMin",
    "DDRMaxFreq",
    "LPMBias",
}

UNSUPPORTED_RESOURCES = {
    "CoreNumMax",
    "CoreNumMin",
    "DEX2OAT_SHARE",
    "FOREGROUND_SHARE",
    "KERNEL_CPU_MAX_CORE_NOTIFY",
    "SYSTEM_SHARE",
    "TOPAPP_SHARE",
}


def load_json(path):
    with open(path, encoding="utf-8") as stream:
        return json.load(stream)


def write_json_atomic(path, data):
    directory = os.path.dirname(path)
    fd, temporary = tempfile.mkstemp(prefix=".config_vendor.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, ensure_ascii=True)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch_hyper_config.py CHIPSET_JSON VENDOR_JSON")

    chipset_path, vendor_path = sys.argv[1:]
    chipset = load_json(chipset_path)
    vendor = load_json(vendor_path)

    vendor["Resources"] = [
        resource
        for resource in vendor.get("Resources", [])
        if resource.get("Name") not in UNSUPPORTED_RESOURCES
    ]

    known_resources = {
        resource.get("Name")
        for config in (chipset, vendor)
        for resource in config.get("Resources", [])
        if resource.get("Name")
    }

    mapped = 0
    removed = 0
    for hint in vendor.get("Hints", []):
        original = hint.get("ResoureList")
        if original is None:
            continue

        adapted = []
        for request in original:
            name = request.get("Resource")
            if name in ALIASES:
                request = copy.copy(request)
                request["Resource"] = ALIASES[name]
                name = request["Resource"]
                mapped += 1

            if name in UNSUPPORTED_REFERENCES:
                removed += 1
                continue
            if name not in known_resources:
                raise ValueError(
                    f"HYPER hint {hint.get('Hint')} references unknown resource {name}"
                )
            adapted.append(request)

        hint["ResoureList"] = adapted

    write_json_atomic(vendor_path, vendor)
    print(f"HYPER-HAL: mapped {mapped} requests and removed {removed} unsupported requests")


if __name__ == "__main__":
    main()
