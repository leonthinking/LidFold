"""Validate data at the notarized-release publication boundary."""
import json
import plistlib
import re
import sys


def accepted_notarization(path):
    with open(path, encoding="utf-8") as source:
        result = json.load(source)
    if not isinstance(result, dict) or result.get("status") != "Accepted":
        raise ValueError("Notarization was not accepted; no release archive will be produced")


def app_version(path):
    with open(path, "rb") as source:
        version = plistlib.load(source).get("CFBundleShortVersionString")
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Expected a three-part numeric App version")
    return version


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: release_support.py version|notary-accepted FILE")
        if sys.argv[1] == "version":
            print(app_version(sys.argv[2]))
        elif sys.argv[1] == "notary-accepted":
            accepted_notarization(sys.argv[2])
        else:
            raise ValueError("Unknown validation command")
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        sys.exit(str(error))
