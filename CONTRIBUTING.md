# How to share your addon

There are two ways. You need only one of them:

- **[Share it in yasb-addons](#share-it-in-yasb-addons).** You send us your addon. We check it, and everyone can find it
  with `yasbc addons search`.
- **[Share it from your own GitHub repository](#share-it-from-your-own-github-repository).** Your addon stays in your
  repository, and you give people the link.

In all examples your GitHub name is `john`. Replace it with yours.

---

# Share it in yasb-addons

## 1. Prepare the folder

### A widget

Your widget is called Weather. The folder:

```
Weather/
  Weather.qml
  manifest.json
```

The file `manifest.json`:

```json
{
  "id": "john.weather",
  "title": "Weather",
  "description": "The weather for your city",
  "version": 1,
  "released": "2026-11-23"
}
```

Other files your widget needs, such as icons, go into the same folder.

### A layout

The same as a widget, with your layout's file instead: `Island.qml` and `"id": "john.island"`.

### A theme

The same, but only two files: `Ocean.qml` and `manifest.json` with `"id": "john.ocean"`.

### A full config

Your whole YASB config folder, with `manifest.json` next to `config.yaml`:

```
yasb/
  config.yaml
  manifest.json
  layouts/
  themes/
  widgets/
```

The file `manifest.json`:

```json
{
  "id": "john.frame",
  "title": "Frame",
  "description": "A frame around the whole screen",
  "version": 1,
  "released": "2026-11-23"
}
```

## 2. Send it

1. Make a ZIP of the folder.
2. Open the form **[Submit an addon](../../issues/new?template=submit-addon.yaml)**.
3. Choose the type: Widget, Theme, Layout or Config.
4. Upload the ZIP and a screenshot. The screenshot is a square image, at least 800x800. We resize it to 800x800, and
   crop it if it is not square. Not needed for a theme, we generate one.
5. In **About**, write what your addon does, what it needs, and what people have to change, such as their city.
6. Submit the form.

You get an answer in a few minutes. If something is wrong, it says what. Fix it and send the form again. If everything is
fine, we look at your addon and add it. Then people install it with:

```
yasbc addons install john.weather
```

## 3. Update it later

1. Change your files.
2. In `manifest.json`, change `"version": 1` to `"version": 2`.
3. Make a new ZIP and send it with the form **[Update an addon](../../issues/new?template=update-addon.yaml)**.

---

# Share it from your own GitHub repository

You don't need a ZIP, a form or our approval here.

## 1. Prepare the repository

Make a new public repository on GitHub. Its files must be at the top, not in a subfolder.

### A widget

Your repository is `github.com/john/my-weather`:

```
Weather.qml
manifest.json
README.md
```

The file `manifest.json`:

```json
{
  "id": "john.weather",
  "type": "widget",
  "title": "Weather",
  "description": "The weather for your city",
  "version": 1,
  "released": "2026-11-23"
}
```

Here `manifest.json` has a `type`, because there is no form where you choose it.

### A layout

The same, with `"type": "layout"`.

### A theme

The same, with `"type": "theme"`.

### A full config

Your repository is `github.com/john/my-config`:

```
config.yaml
manifest.json
layouts/
themes/
widgets/
README.md
```

The file `manifest.json`:

```json
{
  "id": "john.frame",
  "type": "config",
  "title": "Frame",
  "description": "A frame around the whole screen",
  "version": 1,
  "released": "2026-11-23"
}
```

## 2. Share the link

Upload your files and give people this command:

```
yasbc addons install https://github.com/john/my-weather
```

YASB shows them a warning that nobody has checked your addon, and asks if they want to install it.

In your README, write what your addon does, what it needs, and what people have to change.

## 3. Update it later

1. Change your files.
2. In `manifest.json`, change `"version": 1` to `"version": 2`.
3. Push to GitHub.

People get it with `yasbc addons update`.

---

# Good to know

**The id** is your GitHub name, a dot and the addon's name, all in small letters. The addon's name has only letters and
numbers. The QML file has the same name: `john.weather` needs `Weather.qml`. Only a config needs no such file.

**Full configs:** the widgets, themes and layouts inside need no `manifest.json` of their own. When someone installs your
config, it replaces theirs. YASB saves theirs first.

**Paths:** a path such as `C:/Users/john/Pictures` works only on your PC. Write this instead:

- In QML: `Environment.value("USERPROFILE") + "/Pictures"`, with `import Yasb` at the top
- In `config.yaml`: `$env:USERPROFILE/Pictures`

**Never share** your `.env` file, it can hold your passwords. `.exe` and `.dll` files are not allowed.

**Your own repository** holds one addon. Two widgets need two repositories.

**License:** addons in yasb-addons are published under the [MIT License](LICENSE). In your own repository, you choose.
