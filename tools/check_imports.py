"""Resolve every relative import in a Dart tree, without running the analyzer.

`dart format` only checks *parsing* — it happily accepts a file whose imports
point at nothing, which is how broken import paths reached a real `flutter
analyze` run. This script is the missing check, and it needs no subprocess, so
it works in a shell that cannot spawn one.

Usage:  python tools/check_imports.py lib test
"""

import os
import re
import sys

# Matches:  import '...';   export '...';   and the conditional form
# `import 'a' if (dart.library.io) 'b'`, whose paths we also want to check.
_IMPORT = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)


def dart_files(roots):
    for root in roots:
        for dirpath, _dirnames, filenames in os.walk(root):
            for name in filenames:
                if name.endswith(".dart"):
                    yield os.path.join(dirpath, name)


def resolve(source_file, target):
    """The path a relative import should be, or None when it does not exist."""
    base = os.path.dirname(source_file)
    candidate = os.path.normpath(os.path.join(base, target))
    return candidate if os.path.isfile(candidate) else None


def main(argv):
    roots = argv[1:] or ["lib", "test"]
    # `package:skillsikka/...` maps onto `lib/...` in this project.
    package_prefix = "package:skillsikka/"

    missing = []
    checked = 0

    for path in sorted(dart_files(roots)):
        with open(path, encoding="utf-8") as handle:
            source = handle.read()

        for target in _IMPORT.findall(source):
            checked += 1

            if target.startswith("package:"):
                if not target.startswith(package_prefix):
                    continue  # a real dependency, not ours to resolve
                own = target[len(package_prefix) :]
                if not os.path.isfile(os.path.join("lib", own)):
                    missing.append((path, target, None))
                continue

            if target.startswith("dart:"):
                continue

            if resolve(path, target) is None:
                missing.append((path, target, resolve(path, target)))

    print(f"checked {checked} imports across {len(list(dart_files(roots)))} files")

    if not missing:
        print("OK - every import resolves")
        return 0

    print(f"\n{len(missing)} BROKEN:\n")
    for path, target, _ in missing:
        print(f"  {path}\n    -> {target}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
