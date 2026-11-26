import datetime
import difflib
import fnmatch
import html
import io
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
import zipfile
from functools import cache
from pathlib import Path, PurePosixPath

TYPES = {"Widget": "widgets", "Theme": "themes", "Layout": "layouts", "Config": "configs"}
FOLDER_TYPES = {folder: kind for kind, folder in TYPES.items()}
MANIFEST = "manifest.json"
CONFIG = "config.yaml"
# What a config folder holds that YASB makes, or that is not part of the config
LEFT_OUT_FOLDERS = {"__pycache__", ".git", "dumps"}
LEFT_OUT_FILES = ("*.log", "*.log.*")
MANIFEST_KEYS = ("id", "title", "description", "version", "released")
README = "README.md"
# The marker tells the change log apart from an About text with its own Changes heading
CHANGES_HEADING = "<!-- changes -->\n## Changes\n"
ASSETS = "assets"
COVER = "cover.png"
PREVIEW = "preview-"
MAX_IMAGES = 5
COVER_SIZE = 800
JPEG_SIGNATURE = b"\xff\xd8\xff"
FORMS = {"[submit-addon]:": "submit", "[update-addon]:": "update"}
FORM_FIELDS = {
    "submit": {"Type": "type", "Files": "files", "About": "about", "Cover": "cover", "Images": "images"},
    "update": {
        "Files": "files",
        "What changed": "changes",
        "Cover": "cover",
        "Images": "images",
    },
}
ERROR_FILE = "error.log"
DIFF_FILE = "addon-diff.md"
ID_RE = re.compile(r"([a-z0-9-]+)\.([a-z][a-z0-9]*)")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
MAX_TITLE = 50
MAX_DESCRIPTION = 200
# GitHub refuses comments over 65536 characters
MAX_DIFF = 60000
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
URL_RE = re.compile(r'\]\((https://[^)\s]+)\)|src="(https://[^"]+)"|(https://\S+)')
FENCE_RE = re.compile(r" {0,3}(`{3,}|~{3,})")


class SubmissionError(Exception):
    pass


def parse_issue_body(body: str, fields: dict[str, str]) -> dict[str, str]:
    labels = list(fields)
    headings = []
    next_label = 0
    fence = ""
    position = 0
    for line in body.splitlines(keepends=True):
        start = position
        position += len(line)
        text = line.rstrip()
        if fence:
            closing = text.strip()
            if closing and set(closing) == {fence[0]} and len(closing) >= len(fence):
                fence = ""
            continue
        opening = FENCE_RE.match(text)
        if opening:
            fence = opening.group(1)
            continue
        for index in range(next_label, len(labels)):
            if text == f"### {labels[index]}":
                headings.append((fields[labels[index]], start, position))
                next_label = index + 1
                break
    data = {}
    for index, (key, _, start) in enumerate(headings):
        end = headings[index + 1][1] if index + 1 < len(headings) else len(body)
        value = body[start:end].strip()
        data[key] = "" if value == "_No response_" else value
    return data


def extract_urls(value: str) -> list[str]:
    urls = []
    for match in URL_RE.finditer(value or ""):
        url = next(group for group in match.groups() if group)
        if url not in urls:
            urls.append(url)
    return urls


def download(url: str, field: str) -> bytes:
    try:
        with urllib.request.urlopen(
            urllib.request.Request(url, headers={"User-Agent": "yasb-addons"}), timeout=60
        ) as r:
            return r.read()
    except (urllib.error.URLError, OSError):
        raise SubmissionError(f"The file in the {field} field could not be downloaded.") from None


def read_zip(data: bytes) -> dict[str, bytes]:
    """The files in the ZIP by path; a ZIP made from a folder gives the files in that folder."""
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile:
        raise SubmissionError("The file in the Files field is not a ZIP file.") from None
    files: dict[str, bytes] = {}
    for info in archive.infolist():
        if info.is_dir():
            continue
        name = info.filename.replace("\\", "/")
        if name.startswith("/") or ":" in name or ".." in PurePosixPath(name).parts:
            raise SubmissionError(f"The ZIP file has a path outside its folder: {info.filename}")
        try:
            files[name] = archive.read(info)
        except (RuntimeError, NotImplementedError, OSError, zipfile.BadZipFile):
            raise SubmissionError(f"{info.filename} could not be read from the ZIP file.") from None
    if not files:
        raise SubmissionError("The ZIP file is empty.")
    if len({name.split("/", 1)[0] for name in files}) == 1 and all("/" in name for name in files):
        files = {name.split("/", 1)[1]: content for name, content in files.items()}
    folded = [name.casefold() for name in files]
    if duplicates := sorted({name for name in files if folded.count(name.casefold()) > 1}):
        raise SubmissionError(f"The ZIP file has files whose names differ only in case: {', '.join(duplicates)}")
    if archives := sorted(name for name in files if name.lower().endswith(".zip")):
        raise SubmissionError(f"The ZIP file holds another ZIP file: {', '.join(archives)}")
    if programs := sorted(name for name in files if name.lower().endswith((".exe", ".dll"))):
        raise SubmissionError(f"Addons can't include .exe or .dll files: {', '.join(programs)}")
    return files


def one_line(manifest: dict, key: str, limit: int) -> str:
    value = manifest[key]
    if not isinstance(value, str) or not value.strip():
        raise SubmissionError(f"`{key}` in {MANIFEST} must be text.")
    if value != value.strip() or "\n" in value or "\r" in value:
        raise SubmissionError(f"`{key}` in {MANIFEST} must be one line, with no spaces at its start or end.")
    if len(value) > limit:
        raise SubmissionError(f"`{key}` in {MANIFEST} has {len(value)} characters, at most {limit} are allowed.")
    return value


def read_manifest(files: dict[str, bytes], author: str) -> dict:
    if MANIFEST not in files:
        raise SubmissionError(f"The ZIP file has no {MANIFEST} next to your other files.")
    try:
        manifest = json.loads(files[MANIFEST].decode("utf-8-sig"))
    except (UnicodeDecodeError, ValueError) as e:
        raise SubmissionError(f"{MANIFEST} is not valid JSON: {e}") from None
    if not isinstance(manifest, dict):
        raise SubmissionError(f"{MANIFEST} must be a JSON object.")
    if missing := [key for key in MANIFEST_KEYS if key not in manifest]:
        raise SubmissionError(f"{MANIFEST} is missing: {', '.join(missing)}")
    if unknown := [key for key in manifest if key not in (*MANIFEST_KEYS, "type")]:
        raise SubmissionError(f"{MANIFEST} has unknown keys: {', '.join(unknown)}")

    match = ID_RE.fullmatch(manifest["id"]) if isinstance(manifest["id"], str) else None
    if match is None:
        raise SubmissionError(
            f"`id` in {MANIFEST} must be `<your GitHub login>.<name>` in lower case, with a name of letters and "
            f"digits that starts with a letter, such as `{author.lower()}.clock`."
        )
    if match[1] != author.lower():
        raise SubmissionError(f"`id` in {MANIFEST} must start with your GitHub login: `{author.lower()}.{match[2]}`.")
    one_line(manifest, "title", MAX_TITLE)
    one_line(manifest, "description", MAX_DESCRIPTION)

    version = manifest["version"]
    if type(version) is not int or version < 1:
        raise SubmissionError(f"`version` in {MANIFEST} must be a whole number, 1 or more.")

    released = manifest["released"]
    try:
        date = datetime.date.fromisoformat(released) if DATE_RE.fullmatch(str(released)) else None
    except ValueError:
        date = None
    if date is None:
        raise SubmissionError(f"`released` in {MANIFEST} must be a date written as YYYY-MM-DD.")
    # UTC+14 is the first time zone to reach each day
    if date > datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=14))).date():
        raise SubmissionError(f"`released` in {MANIFEST} is in the future: {released}")
    return manifest


def qml_file(files: dict[str, bytes], name: str, folder: str) -> str:
    """The QML file YASB loads: name.qml in any case, next to the manifest."""
    found = next((file for file in files if "/" not in file and file.casefold() == f"{name}.qml"), None)
    if found is None:
        raise SubmissionError(
            f"The ZIP file has no {name.capitalize()}.qml next to {MANIFEST}: the QML file must be named after "
            f"the name in your id."
        )
    if folder == "themes" and (others := sorted(set(files) - {found, MANIFEST})):
        raise SubmissionError(f"A theme is one QML file and {MANIFEST}, but the ZIP file also has: {', '.join(others)}")
    return found


def config_files(files: dict[str, bytes]) -> dict[str, bytes]:
    """A config's files without those YASB makes or that belong to its author's PC."""
    if CONFIG not in files:
        raise SubmissionError(f"The ZIP file has no {CONFIG} next to {MANIFEST}.")
    if secrets := sorted(file for file in files if PurePosixPath(file).name.lower().startswith(".env")):
        raise SubmissionError(f"A config can't include .env files, they can hold your keys: {', '.join(secrets)}")
    kept = {}
    for file, content in files.items():
        *folders, filename = PurePosixPath(file).parts
        if LEFT_OUT_FOLDERS.intersection(folders) or any(fnmatch.fnmatch(filename.lower(), g) for g in LEFT_OUT_FILES):
            continue
        # With the manifest of a copied built-in widget, YASB would replace the copy when it updates its own
        if filename == MANIFEST and len(folders) == 2 and folders[0] == "widgets" and "." not in folders[1]:
            continue
        kept[file] = content
    return kept


def find_addon(login: str, name: str) -> Path | None:
    return next((path for folder in TYPES.values() if (path := Path(folder, login, name)).is_dir()), None)


def versions(addon: Path) -> list[int]:
    return sorted(int(path.name) for path in addon.iterdir() if path.is_dir() and path.name.isdigit())


def download_images(urls: list[str], field: str, limit: int) -> list[tuple[bytes, str]]:
    """The images of a form field, each with its file extension."""
    if len(urls) > limit:
        raise SubmissionError(f"Please upload at most {limit} image(s) in the {field} field (found {len(urls)}).")
    images = []
    for number, url in enumerate(urls, 1):
        data = download(url, field)
        extension = "png" if data.startswith(PNG_SIGNATURE) else "jpg" if data.startswith(JPEG_SIGNATURE) else None
        if extension is None:
            raise SubmissionError(f"Image {number} in the {field} field is not a PNG or JPG image.")
        images.append((data, extension))
    return images


def square_cover(data: bytes) -> bytes:
    """The cover as PNG, cropped to a square around its middle and scaled down."""
    from PyQt6.QtCore import QBuffer, QIODevice, Qt
    from PyQt6.QtGui import QImage

    qml_engine()
    image = QImage.fromData(data)
    if image.isNull():
        raise SubmissionError("The cover could not be read as an image.")
    width, height = image.width(), image.height()
    side = min(width, height)
    if side < COVER_SIZE:
        raise SubmissionError(f"The cover is {width}x{height}. It must be at least {COVER_SIZE}x{COVER_SIZE}.")
    image = image.copy((width - side) // 2, (height - side) // 2, side, side)
    image = image.scaled(COVER_SIZE, COVER_SIZE, transformMode=Qt.TransformationMode.SmoothTransformation)
    buffer = QBuffer()
    buffer.open(QIODevice.OpenModeFlag.WriteOnly)
    image.save(buffer, "PNG")
    return bytes(buffer.data())


@cache
def qml_engine():
    """The application and an engine with YASB's QML types and modules, made once."""
    from core.qml_types import register_qml_types
    from PyQt6.QtGui import QGuiApplication
    from PyQt6.QtQml import QQmlEngine
    from settings import QML_IMPORT_PATH  # type: ignore

    app = QGuiApplication([])
    register_qml_types()
    engine = QQmlEngine()
    engine.addImportPath(QML_IMPORT_PATH)
    return app, engine


def qml_errors(path: Path, root: Path) -> list[str]:
    """Why the QML file in root does not compile against YASB's modules. It is never created, so none of it runs."""
    from PyQt6.QtCore import QUrl
    from PyQt6.QtQml import QQmlComponent

    component = QQmlComponent(qml_engine()[1], QUrl.fromLocalFile(str(path.resolve())))
    prefix = QUrl.fromLocalFile(str(root.resolve())).toString() + "/"
    errors = [error.toString().replace(prefix, "") for error in component.errors()]
    if not errors and component.status() != QQmlComponent.Status.Ready:
        errors = [f"{path.name} did not load."]
    return errors


def config_errors(root: Path) -> list[str]:
    """Why the config does not work in YASB, read with YASB's own code from the folder YASB_CONFIG_HOME names."""
    from core.config import ConfigError, load_config
    from core.theme_files import DEFAULT_THEME, config_qml_file
    from core.widget_files import outdated_widgets, undefined_widgets

    try:
        config = load_config()
    except ConfigError as e:
        return [f"{CONFIG}: {e.details or e}"]
    errors = [f"{CONFIG}: there is no widget {name}" for name in undefined_widgets(config)]
    errors += [f"widgets/{name}: {problem}" for name, problem in outdated_widgets(config).items()]
    named = {("layouts", bar.layout) for bar in config.bars.values()}
    named |= {("themes", bar.theme) for bar in config.bars.values()}
    for folder, name in sorted((folder, name) for folder, name in named if name and name.lower() != DEFAULT_THEME):
        path = config_qml_file(name, root.resolve() / folder)
        if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):
            errors.append(f"{CONFIG}: there is no {folder[:-1]} {name} in the ZIP file")
    for path in sorted(root.rglob("*.qml")):
        errors += qml_errors(path, root)
    return list(dict.fromkeys(errors))


def theme_colors(path: Path, scheme) -> dict:
    """The theme's colours in a colour scheme: colors.*, then those of its bar, popup and menu."""
    from PyQt6.QtCore import QUrl
    from PyQt6.QtGui import QColor
    from PyQt6.QtQml import QQmlComponent

    app, engine = qml_engine()
    app.styleHints().setColorScheme(scheme)
    app.processEvents()
    if app.styleHints().colorScheme() != scheme:
        raise RuntimeError(f"Qt did not switch to the {scheme.name} colour scheme.")
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(path.resolve())))
    theme = component.create()
    if theme is None:
        errors = "\n".join(error.toString() for error in component.errors())
        raise SubmissionError(f"{path.name} could not be created:\n{errors}")
    colors: dict[str, QColor] = {}
    for group in ("colors", "bar", "popup", "menu"):
        item = theme.property(group)
        meta = item.metaObject()
        for index in range(meta.propertyOffset(), meta.propertyCount()):
            value = meta.property(index).read(item)
            if isinstance(value, QColor):
                name = meta.property(index).name()
                colors[name if group == "colors" else f"{group}.{name}"] = value
    theme.deleteLater()
    return colors


def write_palette(path: Path, out: Path) -> None:
    """Draws the theme's colours, dark above light, each on the theme's own background with its own text colour."""
    from PyQt6.QtCore import QRectF, Qt
    from PyQt6.QtGui import QColor, QFont, QImage, QPainter

    sections = [theme_colors(path, Qt.ColorScheme.Dark), theme_colors(path, Qt.ColorScheme.Light)]
    columns, cell_width, cell_height, padding, swatch, scale = 4, 240, 56, 24, 40, 2
    rows = -(-max(len(colors) for colors in sections) // columns)
    width = padding * 2 + columns * cell_width
    section_height = padding * 2 + rows * cell_height - (cell_height - swatch)
    image = QImage(width * scale, section_height * len(sections) * scale, QImage.Format.Format_ARGB32_Premultiplied)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.setRenderHint(QPainter.RenderHint.TextAntialiasing)
    painter.scale(scale, scale)
    for number, colors in enumerate(sections):
        top = number * section_height
        background, text = QColor(colors["background"]), colors["text"]
        background.setAlpha(255)
        painter.fillRect(QRectF(0, top, width, section_height), background)
        for index, (name, color) in enumerate(colors.items()):
            x = padding + index % columns * cell_width
            y = top + padding + index // columns * cell_height
            painter.setPen(colors["border"])
            painter.setBrush(color)
            painter.drawRoundedRect(QRectF(x, y, swatch, swatch), 6, 6)
            hex_format = QColor.NameFormat.HexRgb if color.alpha() == 255 else QColor.NameFormat.HexArgb
            painter.setPen(text)
            painter.setFont(QFont("Segoe UI", 10))
            painter.drawText(
                QRectF(x + swatch + 10, y, cell_width - swatch - 14, swatch / 2), Qt.AlignmentFlag.AlignBottom, name
            )
            painter.setPen(colors["textSecondary"])
            painter.setFont(QFont("Consolas", 9))
            painter.drawText(
                QRectF(x + swatch + 10, y + swatch / 2 + 2, cell_width, swatch / 2),
                Qt.AlignmentFlag.AlignTop,
                color.name(hex_format),
            )
    painter.end()
    # Square like a cover: scaled to fit, with each half's background filling the rest of its side
    square = QImage(COVER_SIZE, COVER_SIZE, QImage.Format.Format_ARGB32_Premultiplied)
    painter = QPainter(square)
    for number, colors in enumerate(sections):
        background = QColor(colors["background"])
        background.setAlpha(255)
        painter.fillRect(0, number * COVER_SIZE // 2, COVER_SIZE, COVER_SIZE // 2, background)
    fitted = image.scaled(
        COVER_SIZE,
        COVER_SIZE,
        Qt.AspectRatioMode.KeepAspectRatio,
        Qt.TransformationMode.SmoothTransformation,
    )
    painter.drawImage((COVER_SIZE - fitted.width()) // 2, (COVER_SIZE - fitted.height()) // 2, fitted)
    painter.end()
    out.parent.mkdir(parents=True, exist_ok=True)
    square.save(str(out), "PNG")


def source_files(folder: Path | None, name: str) -> dict[str, bytes]:
    if folder is None:
        return {}
    return {
        path.relative_to(folder).as_posix(): path.read_bytes()
        for path in sorted(folder.rglob("*"))
        if path.is_file() and path.name != f"{name}.zip"
    }


def text_lines(data: bytes) -> list[str]:
    return [line + "\n" for line in data.decode("utf-8-sig").splitlines()]


def write_readme(path: Path, manifest: dict, about: str, changes: str) -> None:
    """Title, description and About, then the versions newest first. The text above them is written once, when the
    addon is submitted, and an update only adds its version."""
    old = path.read_text(encoding="utf-8") if path.is_file() else ""
    head, _, log = old.partition(CHANGES_HEADING)
    if not old:
        install = f"```\nyasbc addons install {manifest['id']}\n```"
        head = f"# {manifest['title']}\n\n{manifest['description']}\n\n{install}\n\n{about}"
    entry = f"\n### Version {manifest['version']} ({manifest['released']})\n\n{changes or 'Initial release'}\n"
    path.write_text(f"{head.rstrip()}\n\n{CHANGES_HEADING}{entry}{log}", encoding="utf-8", newline="\n")


def write_diff(old: Path | None, new: Path, name: str) -> None:
    """A table of the files that differ, then the diff of each changed one, folded; added files are read in the PR."""
    before, after = source_files(old, name), source_files(new, name)
    rows, blocks = [], []
    size = 0
    for file in sorted(before.keys() | after.keys()):
        a, b = before.get(file), after.get(file)
        if a == b:
            continue
        status = "added" if a is None else "removed" if b is None else "changed"
        try:
            a_lines, b_lines = text_lines(a or b""), text_lines(b or b"")
        except UnicodeDecodeError:
            rows.append(f"| `{file}` | {status} | binary |")
            continue
        if status != "changed":
            rows.append(f"| `{file}` | {status} | {len(a_lines or b_lines)} |")
            continue
        diff = list(difflib.unified_diff(a_lines, b_lines, f"a/{file}", f"b/{file}"))[2:]
        added, removed = sum(line[0] == "+" for line in diff), sum(line[0] == "-" for line in diff)
        rows.append(f"| `{file}` | {status} | +{added} -{removed} |")
        if not diff:
            continue
        text = "".join(diff)
        fence = "`" * max([3, *(len(run) + 1 for run in re.findall(r"`+", text))])
        block = f"<details><summary>{html.escape(file)}</summary>\n\n{fence}diff\n{text}{fence}\n\n</details>\n"
        if size + len(block) > MAX_DIFF:
            block = f"<details><summary>{html.escape(file)}</summary>\n\nToo long for a comment.\n\n</details>\n"
        size += len(block)
        blocks.append(block)
    heading = f"## Changes from version {old.name} to {new.name}" if old else f"## Files in version {new.name}"
    table = "| File | Status | Lines |\n|---|---|---|\n" + "\n".join(rows)
    body = f"{heading}\n\n{table}\n\n" + "\n".join(blocks) if rows else f"{heading}\n\nNo changes.\n"
    Path(DIFF_FILE).write_text(body, encoding="utf-8", newline="\n")


def write_github_env(values: dict[str, str]) -> None:
    env_file = os.environ.get("GITHUB_ENV")
    if env_file:
        with open(env_file, "a", encoding="utf-8") as f:
            for key, value in values.items():
                delimiter = f"ghadelimiter_{uuid.uuid4()}"
                f.write(f"{key}<<{delimiter}\n{value}\n{delimiter}\n" if "\n" in value else f"{key}={value}\n")


def process() -> None:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not os.path.isfile(event_path):
        raise SubmissionError("GITHUB_EVENT_PATH is missing or the file does not exist.")
    with open(event_path, encoding="utf-8") as f:
        issue = json.load(f).get("issue", {})
    title = issue.get("title") or ""
    form = next((form for prefix, form in FORMS.items() if title.startswith(prefix)), None)
    if form is None:
        raise SubmissionError("The issue was not opened with the Submit an addon or Update an addon form.")
    fields = parse_issue_body(issue.get("body") or "", FORM_FIELDS[form])
    author = os.environ["ADDON_AUTHOR"]
    sys.path.insert(0, str(Path(os.environ.get("YASB_SRC", "yasb-repo/src")).resolve()))

    zip_urls = extract_urls(fields.get("files", ""))
    if len(zip_urls) != 1:
        raise SubmissionError(f"Please upload one ZIP file in the Files field (found {len(zip_urls)}).")
    files = read_zip(download(zip_urls[0], "Files"))
    manifest = read_manifest(files, author)
    login, name = manifest["id"].split(".")
    addon = find_addon(login, name)
    released = versions(addon) if addon is not None else []

    if form == "submit":
        kind = fields.get("type", "")
        if kind not in TYPES:
            raise SubmissionError(f"Please choose {', '.join(TYPES)} in the Type field (found '{kind}').")
        if addon is not None:
            raise SubmissionError(
                f"{manifest['id']} already exists. To publish a new version, use the Update an addon form."
            )
        folder, previous, changes = TYPES[kind], None, ""
    else:
        if addon is None or not released:
            raise SubmissionError(f"There is no addon {manifest['id']} yet. To add it, use the Submit an addon form.")
        folder, previous, changes = addon.parts[0], released[-1], fields.get("changes", "")
        kind = FOLDER_TYPES[folder]
        if manifest["version"] <= previous:
            raise SubmissionError(
                f"`version` in {MANIFEST} must be higher than {previous}, the latest version of {manifest['id']}."
            )
        if not changes:
            raise SubmissionError("Please write what changed in this version in the What changed field.")
    if manifest.get("type", kind.lower()) != kind.lower():
        raise SubmissionError(f"`type` in {MANIFEST} is {manifest['type']}, but this addon is a {kind.lower()}.")
    about = fields.get("about", "")
    if form == "submit" and not about:
        raise SubmissionError("Please write a few words about your addon in the About field.")
    addon = Path(folder, login, name)
    target = addon / str(manifest["version"])
    target.mkdir(parents=True)
    main_file = "The config"
    if folder == "configs":
        # YASB reads it when its modules are first loaded
        os.environ["YASB_CONFIG_HOME"] = str(target.resolve())
        files = config_files(files)
    else:
        main_file = qml_file(files, name, folder)

    # A theme's cover is its palette, so a cover uploaded for one is left out
    cover_urls = extract_urls(fields.get("cover", "")) if folder != "themes" else []
    cover = square_cover(download_images(cover_urls, "Cover", 1)[0][0]) if cover_urls else None
    if form == "submit" and cover is None and folder != "themes":
        raise SubmissionError(
            "Please upload a picture in the Cover field: it is required for a widget, layout or config."
        )
    images = download_images(extract_urls(fields.get("images", "")), "Images", MAX_IMAGES)

    for file, content in files.items():
        (target / file).parent.mkdir(parents=True, exist_ok=True)
        (target / file).write_bytes(content)

    if errors := config_errors(target) if folder == "configs" else qml_errors(target / main_file, target):
        raise SubmissionError(f"{main_file} does not load in YASB:\n" + "\n".join(errors))

    with zipfile.ZipFile(target / f"{name}.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for file, content in sorted(files.items()):
            archive.writestr(file, content)
    assets = addon / ASSETS
    assets.mkdir(exist_ok=True)
    if folder == "themes":
        write_palette(target / main_file, assets / COVER)
    if cover is not None:
        (assets / COVER).write_bytes(cover)
    if images:
        for old in assets.iterdir():
            if old.name.startswith(PREVIEW):
                old.unlink()
        for number, (data, extension) in enumerate(images, 1):
            (assets / f"{PREVIEW}{number}.{extension}").write_bytes(data)
    write_readme(addon / README, manifest, about, changes)
    write_diff(addon / str(previous) if previous is not None else None, target, name)

    write_github_env(
        {
            "ADDON_ID": manifest["id"],
            "ADDON_PATH": addon.as_posix(),
            "ADDON_TITLE": manifest["title"],
            "ADDON_DESCRIPTION": manifest["description"],
            "ADDON_TYPE": kind,
            "ADDON_VERSION": str(manifest["version"]),
            "ADDON_ACTION": "Add" if previous is None else "Update",
            "ADDON_CHANGES": f"## What changed\n\n{changes}" if changes else "",
        }
    )
    print(f"{manifest['id']} version {manifest['version']} written to {target.as_posix()}")


def main() -> None:
    # Windows runners default to cp1252 for redirected output
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    try:
        process()
    except SubmissionError as e:
        Path(ERROR_FILE).write_text(f"{e}\n", encoding="utf-8")
        print(e, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
