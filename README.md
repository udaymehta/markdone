<p align="center">
	<img src="assets/icon/combined.png" alt="MarkDone app icon" width="90" height="90" style="border-radius: 15%;" />
</p>

<h1 align="center">MarkDone!</h1>

<p align="center">
	<a href="https://github.com/udaymehta/markdone/releases/latest">
		<img src="https://img.shields.io/github/v/release/udaymehta/markdone?display_name=tag&label=latest%20release" alt="Latest release" />
	</a>
	<a href="https://github.com/udaymehta/markdone/releases/latest">
		<img src="https://img.shields.io/badge/download-latest%20release-6c47ff" alt="Download latest release" />
	</a>
</p>

A local-first task manager built with Flutter that stores everything as plain Markdown files.

## What it does

Each project is a `.md` file with YAML frontmatter for project settings and HTML comments for task metadata. Your data stays on your device in files you can read, edit, move, or sync however you want.

- Projects stored as readable Markdown files
- No cloud accounts, no proprietary databases
- Works alongside Obsidian, git, Syncthing, or anything that handles files
- Task metadata is tucked into HTML comments so the Markdown stays clean

## Screenshots

<table>
	<tr>
		<td align="center">
			<a href="assets/screenshots/homepage.jpg">
				<img src="assets/screenshots/homepage.jpg" alt="Home screen" width="260" />
			</a>
			<br />
			<strong>Home</strong>
		</td>
		<td align="center">
			<a href="assets/screenshots/task_create.jpg">
				<img src="assets/screenshots/task_create.jpg" alt="Create task screen" width="260" />
			</a>
			<br />
			<strong>Create Task</strong>
		</td>
	</tr>
	<tr>
		<td align="center">
			<a href="assets/screenshots/todo_personal.jpg">
				<img src="assets/screenshots/todo_personal.jpg" alt="Personal project screen" width="260" />
			</a>
			<br />
			<strong>Personal Project</strong>
		</td>
		<td align="center">
			<a href="assets/screenshots/todo_taxes.jpg">
				<img src="assets/screenshots/todo_taxes.jpg" alt="Taxes project screen" width="260" />
			</a>
			<br />
			<strong>Project Tasks</strong>
		</td>
	</tr>
	<tr>
		<td align="center">
			<a href="assets/screenshots/dday.jpg">
				<img src="assets/screenshots/dday.jpg" alt="D-Day tracking screen" width="260" />
			</a>
			<br />
			<strong>D-Day</strong>
		</td>
		<td align="center">
			<a href="assets/screenshots/archive.jpg">
				<img src="assets/screenshots/archive.jpg" alt="Archive screen" width="260" />
			</a>
			<br />
			<strong>Archive</strong>
		</td>
	</tr>
	<tr>
		<td align="center">
			<a href="assets/screenshots/project_create.jpg">
				<img src="assets/screenshots/project_create.jpg" alt="Project Create" width="260" />
			</a>
			<br />
			<strong>Project Create</strong>
		</td>
		<td align="center">
			<a href="assets/screenshots/settings.jpg">
				<img src="assets/screenshots/settings.jpg" alt="Settings screen" width="260" />
			</a>
			<br />
			<strong>Settings</strong>
		</td>
	</tr>
</table>

Click any screenshot to view it full size.

## Install

### Android

Download the latest APK from:

<a href="https://github.com/udaymehta/markdone/releases/latest">
    <img src="./assets/badge_github.png" height="50">
</a>

## Features

- **Markdown storage** — projects are `.md` files with YAML frontmatter, editable in any text editor
- **Custom reminders** — local notifications with flexible scheduling
- **Recurring tasks** — configurable repeat intervals stored in Markdown metadata
- **D-Day tracking** — countdown badges on projects with a dedicated D-Day overview screen
- **Drag-to-reorder** — manual task ordering with persistent sort positions
- **Swipe gestures** — swipe right to complete, swipe left to delete
- **Project background colors** — per-project color tinting on both the detail page and home cards
- **Archive** — completed projects can be archived and restored
- **Calendar sync** — optional integration with device calendar
- **Custom folder** — point to any directory, including an Obsidian vault
- **Font size scaling** — adjustable global text size (0.8x to 1.4x)
- **Dark mode** and accent color customization

## File format

Projects are stored as Markdown files with this structure:

```md
---
title: Ship something
created: 2026-03-06
dday: 2026-03-20
description: stop overthinking, start shipping
bg_color: "#33ff6b35"
sync_calendar: true
---

- [ ] finish feature <!-- {"id":"0d6bc622","alarm":"2026-03-10T09:00:00.000","reminder":"2w","recurrence":{"frequency":"daily","interval":3}} -->
- [x] write tests
```

The YAML frontmatter holds project-level settings. Each task is a standard Markdown checkbox. App-specific metadata (IDs, alarms, recurrence) lives in HTML comments after each task line, so the file remains valid Markdown.

## Building locally

Requires a working [Flutter](https://docs.flutter.dev/get-started/install) installation.

### 1. Get dependencies

```bash
flutter pub get
```

### 2. Build the APK

```bash
flutter build apk --release
```

### 3. Install

The built APK will be at:

`build/app/outputs/flutter-apk/app-release.apk`

For debug builds, use `flutter run` as usual.

## Storage

By default, files are stored in a local `markdone` folder. You can change this to any directory in Settings — useful if you want your tasks inside an Obsidian vault or a synced folder.

## Disclaimer

A good portion of the code in this project was written with AI assistance. This started as a personal tool for my own workflow. Sharing it in case it's useful to someone else.
