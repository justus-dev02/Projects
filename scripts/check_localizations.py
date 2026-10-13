#!/usr/bin/env python3
"""Verifies that every user-facing string is translated into German.

Usage:
    scripts/check_localizations.py <DerivedDataPath>

Run it after an Xcode build (the build writes `*.stringsdata` files containing every
localizable key the compiler found). The script fails when

* a key used in code is missing from the target's String Catalog,
* a key has no German translation, or a translation is not marked "translated",
* the format specifiers of a translation do not match the English key
  (e.g. "%@" in English but "%lld" in German).

Keys that exist in a catalog but no longer in code are reported as warnings.
"""

import glob
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = {
    "ProjectsCore": ROOT / "Packages/ProjectsKit/Sources/ProjectsCore/Resources/Localizable.xcstrings",
    "ProjectsData": ROOT / "Packages/ProjectsKit/Sources/ProjectsData/Resources/Localizable.xcstrings",
    "ProjectsDesignSystem": ROOT / "Packages/ProjectsKit/Sources/ProjectsDesignSystem/Resources/Localizable.xcstrings",
    "Projects": ROOT / "Projects/Resources/Localizable.xcstrings",
    "ProjectsWidgets": ROOT / "ProjectsWidgets/Localizable.xcstrings",
}
REQUIRED_LANGUAGES = ["de"]
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\df|#@\w+@)")


def extracted_keys(derived_data: Path) -> dict[str, set[str]]:
    keys: dict[str, set[str]] = defaultdict(set)
    for path in glob.glob(str(derived_data / "Build/Intermediates.noindex/**/*.stringsdata"), recursive=True):
        parts = Path(path).parts
        if "Objects-normal" not in parts:
            continue
        target = parts[parts.index("Objects-normal") - 1].removesuffix(".build").removesuffix("-t")
        data = json.loads(Path(path).read_text())
        for entry in data.get("tables", {}).get("Localizable", []):
            keys[target].add(entry["key"])
    return keys


def specifier_types(text: str) -> Counter:
    """Counts specifier types, ignoring positions; plural substitutions count as one integer."""
    kinds = []
    for match in SPECIFIER.findall(text):
        kind = re.sub(r"\d+\$", "", match)
        kinds.append("%lld" if kind.startswith("%#@") else kind)
    return Counter(kinds)


def values_of(localization: dict, category: str = "other") -> list[tuple[str, str]]:
    """All (plural category, string) pairs of a localization, including plural variations."""
    values = []
    if "stringUnit" in localization:
        unit = localization["stringUnit"]
        if unit.get("state") != "translated":
            return []
        values.append((category, unit["value"]))
    for variants in localization.get("variations", {}).values():
        for name, variant in variants.items():
            values.extend(values_of(variant, name))
    return values


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    keys = extracted_keys(Path(sys.argv[1]))
    if not keys:
        print("error: no .stringsdata files found – build the app first", file=sys.stderr)
        return 2

    errors, warnings = [], []
    for target, catalog_path in CATALOGS.items():
        catalog = json.loads(catalog_path.read_text())["strings"]
        used = keys.get(target, set())
        for key in sorted(used):
            entry = catalog.get(key)
            if entry is None:
                errors.append(f"{target}: missing in catalog: {key!r}")
                continue
            for language in REQUIRED_LANGUAGES:
                localization = entry.get("localizations", {}).get(language)
                values = values_of(localization) if localization else []
                if not values:
                    errors.append(f"{target}: no translated '{language}' value for {key!r}")
                    continue
                expected = specifier_types(key)
                for category, value in values:
                    # Substitution variants contain %arg instead of the specifier.
                    if "%arg" in value or "substitutions" in localization:
                        continue
                    actual = specifier_types(value)
                    if category in ("zero", "one"):
                        # "1 task" may be written as "Task" – the count may be omitted.
                        expected_without_count = expected - Counter({"%lld": 1})
                        if actual in (expected, expected_without_count):
                            continue
                    if actual != expected:
                        errors.append(f"{target}: format specifiers differ for {key!r}: {value!r}")
        for key in sorted(set(catalog) - used):
            warnings.append(f"{target}: stale key (not used in code): {key!r}")

    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    total = sum(len(v) for v in keys.values())
    print(f"Checked {total} keys in {len(CATALOGS)} catalogs: {len(errors)} errors, {len(warnings)} warnings.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
