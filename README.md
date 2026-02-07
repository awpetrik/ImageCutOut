# ImageCutOut

![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-18A2EB?style=for-the-badge&logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Core ML](https://img.shields.io/badge/Core_ML-3399CC?style=for-the-badge&logo=apple&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)


<img width="2652" height="1632" alt="image" src="https://github.com/user-attachments/assets/d4508304-79ed-4893-9897-c8fb52e19bb6" />


Production-grade macOS app for retail Category Managers to generate clean product cutouts in batch or per-image, with offline-first processing and optional AI metadata.

## Highlights
- macOS 13+ SwiftUI app
- Core ML + Vision segmentation (offline)
- Core Image for compositing, edge refinement, padding, shadows
- Async batch pipeline with concurrency controls
- Provider-agnostic AI integrations (OpenAI + Custom REST)
- Keychain for API keys, UserDefaults for settings
- Security-scoped bookmarks for folders

## Project Structure
```
ImageCutOut/
  App/                App entry + state + commands
  Models/             Data models & settings
  Services/           Core processing pipeline + storage
  Services/AI/        Provider protocol + implementations
  UI/                 SwiftUI views
  UI/Components/      Reusable UI elements
  UI/Editors/         Mask editor
  Utilities/          Helpers (async semaphore, image IO, watermark)
```

## Setup
1. Open `ImageCutOut.xcodeproj` in Xcode (macOS 13+).
2. Build and run the `ImageCutOut` target.
3. (Optional) Add a Core ML segmentation model:
   - Add a `.mlmodel` or `.mlpackage` to the `ImageCutOut` target.
   - Name it `SegmentationModel` (or update `SegmentationModelFactory` in `ImageCutOut/Services/SegmentationModel.swift`).
4. Configure AI providers in **Settings** (API keys stored in Keychain).

## How to Add a Core ML Model
- Add the model to the Xcode project.
- Ensure the compiled model ends up in the app bundle (Xcode does this automatically).
- Update `SegmentationModelFactory.loadModel(named:)` if you want a custom model name.

## Running a Batch
1. Click **Open Files** or **Open Folder**.
2. Adjust **Cutout Settings** and **Batch Settings** if needed.
3. Click **Start Batch**.
4. Use **Batch Queue** to monitor progress.

## Export Package
1. Click **Select Output Folder**.
2. Click **Export All** or **Export Approved**.
3. If **ZIP** export is enabled, the app will create a `.zip` beside the export folder.

## CSV SKU Mapping
Import a CSV with headers:
```
sku,filename_pattern,brand,category,variant
```
Patterns support `*` wildcards or `/regex/`.

## AI Provider Configuration
Supported provider types in MVP:
- OpenAI (default base URL: `https://api.openai.com/v1`)
- Custom REST endpoint

API keys are stored in Keychain; everything else is in UserDefaults.

## Build Instructions
1. `Product > Scheme > ImageCutOut`
2. `Product > Build` or `Cmd+B`
3. Run with `Cmd+R`

## Testing Checklist
- [ ] Drag & drop single image
- [ ] Drag & drop folder (recursive on/off)
- [ ] Batch processing with cancel/pause/resume
- [ ] Export PNG + JPG + ZIP
- [ ] CSV import mapping
- [ ] Mask editor erase/restore
- [ ] Log export
- [ ] AI provider test connection
- [ ] Security-scoped bookmark access to output folder

## Notes
- When no segmentation model is present, the pipeline still runs but outputs are marked **Needs Review**.
- AI features are optional and never required for cutout processing.
