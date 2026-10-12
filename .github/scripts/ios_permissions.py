#!/usr/bin/env python3
"""Add the permission_handler preprocessor macros to the iOS Podfile.

Usage: ios_permissions.py ios/Podfile

permission_handler compiles only the permission code whose PERMISSION_* macro
is set. Without these macros the camera and location checks are no-ops on iOS.
The macros are added once, after flutter_additional_ios_build_settings.
"""
import sys

MARKER = "flutter_additional_ios_build_settings(target)"
BLOCK = """
    # permission_handler: compile only the permissions the app uses (SEC-005, PLAT-001)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_LOCATION=1',
      ]
    end"""


def main() -> int:
    path = sys.argv[1]
    text = open(path, encoding="utf-8").read()
    if "PERMISSION_CAMERA=1" in text:
        print("permission macros already present")
        return 0
    if text.count(MARKER) != 1:
        print(f"expected exactly one '{MARKER}' in {path}", file=sys.stderr)
        return 1
    text = text.replace(MARKER, MARKER + BLOCK, 1)
    open(path, "w", encoding="utf-8").write(text)
    print("permission macros added")
    return 0


if __name__ == "__main__":
    sys.exit(main())
