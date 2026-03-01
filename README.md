# mac-image-compressor

A lightweight macOS SwiftUI app to batch-compress images.

## Features

- Select multiple images at once
- Choose output format: JPEG / PNG / HEIC / WebP
- Quality slider
- Max width resize
- Optional metadata preservation
- Output logs with before/after size and savings

## Build & Run

```bash
swift build
swift run
```

> Running `swift run` opens the macOS app window.

## Usage

1. Click **Select Images** and choose one or more files.
2. Click **Select Output Folder**.
3. Pick output format and quality.
4. Click **Compress Now**.

Compressed files are written as:

`<original-name>-compressed.<ext>`

## Supported input types

PNG, JPEG, TIFF, HEIC, GIF, BMP, WebP
