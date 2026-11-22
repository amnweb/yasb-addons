# Contributing

You can share a widget, theme or layout you made for YASB. Each addon is submitted with an issue form, checked against
YASB, and added with a PR once a maintainer has reviewed it.

## Make an addon

1. Write a `manifest.json` next to your QML:

   ```json
   {
     "id": "yourlogin.clock",
     "title": "Clock",
     "description": "A clock with the date in its popup",
     "version": 1,
     "released": "2026-11-22",
     "yasbApi": 1
   }
   ```

   - `id` is your GitHub login and the addon's name, in lower case. The main QML file is named after the name:
     `Clock.qml` for `yourlogin.clock`.
   - `title` is at most 50 characters, `description` at most 200.
   - `version` is a whole number. `released` is the date of this version, written as YYYY-MM-DD.
   - `yasbApi` is the API version of the YASB you wrote it for.

2. Make a ZIP file:
   - **Widget or layout:** compress its folder, or the files themselves: its QML files, any other files it needs and
     `manifest.json`. The main QML file must be named after your id.
   - **Theme:** compress its one `.qml` file and `manifest.json`.
   - `.exe` and `.dll` files are not accepted.

## Submit an addon

Open a [Submit an addon](../../issues/new?template=submit-addon.yaml) issue and fill it in:

- **Type:** widget, theme or layout.
- **Files:** your ZIP file.
- **About:** what your addon is, how to use it and what it needs. This text becomes the README of your addon.
- **Screenshot:** square or close to it (from 3:4 to 4:3); it is cropped to a square. Required for a widget or
  layout. A theme can skip it: a palette of its colours is made for it.
- **Images:** up to 5 more screenshots, optional.

The submission is checked against YASB. If it passes, a PR is opened with your files and the issue is closed with a
link to it. If not, the issue gets a comment saying what to fix, and you can submit again.

## Update an addon

Raise `version` in your `manifest.json` above the last one, then open an
[Update an addon](../../issues/new?template=update-addon.yaml) issue with the new ZIP file and what changed. What
changed is added to the change log in your addon's README. A new About text, screenshot or images replace the old
ones; leave them empty to keep them. Only the author of an addon can update it.

## License

By submitting an addon, you agree that it is published under this repository's [MIT License](LICENSE).
