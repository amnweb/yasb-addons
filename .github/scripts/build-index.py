import hashlib
import json
from pathlib import Path

TYPES = {"widgets": "widget", "themes": "theme", "layouts": "layout", "configs": "config"}
MANIFEST = "manifest.json"
INDEX = Path("index.json")


def read_addon(addon: Path, kind: str) -> dict | None:
    folders = sorted(
        (path for path in addon.iterdir() if path.is_dir() and path.name.isdigit()), key=lambda p: int(p.name)
    )
    if not folders:
        return None
    manifests = [json.loads((folder / MANIFEST).read_text(encoding="utf-8-sig")) for folder in folders]
    login, name = addon.parent.name, addon.name
    return {
        "id": f"{login}.{name}",
        "type": kind,
        "author": login,
        "title": manifests[-1]["title"],
        "description": manifests[-1]["description"],
        "versions": [
            {
                "version": int(folder.name),
                "released": manifest["released"],
                "sha256": hashlib.sha256((folder / f"{name}.zip").read_bytes()).hexdigest(),
            }
            for folder, manifest in zip(folders, manifests, strict=True)
        ],
    }


def main() -> None:
    addons = [
        entry
        for folder, kind in TYPES.items()
        for addon in sorted(Path(folder).glob("*/*"))
        if addon.is_dir() and (entry := read_addon(addon, kind)) is not None
    ]
    addons.sort(key=lambda entry: entry["id"])
    INDEX.write_text(
        json.dumps({"addons": addons}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n"
    )
    print(f"index.json lists {len(addons)} addon(s).")


if __name__ == "__main__":
    main()
