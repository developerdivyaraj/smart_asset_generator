# 🛠️ Asset Generator

A simple and flexible Dart/Flutter CLI tool to auto-generate asset reference classes and barrel files — making asset management and file exports clean, consistent, and error-free.

---

## ✨ Features

✅ Automatically scans asset folders and generates Dart class with constant paths  
✅ Supports nested folders and various file types (`.png`, `.svg`, `.json`, etc.)  
✅ Converts file names to `camelCase` constants for easy reference  
✅ Works in Flutter and pure Dart projects  
✅ Fully customizable class name and output structure  
✅ Also supports **barrel file generation**: auto-exports multiple Dart files from any directory  
✅ CLI-ready, no runtime dependency

---

## 📦 Use Cases

- Generate an `AppImages` class to avoid hardcoding asset paths
- Organize all custom widgets via a single `widget_exports.dart` barrel file
- Reduce boilerplate and avoid human error in large projects
- Keep imports clean and scalable in modular architecture

---

## 🚀 Getting Started

### 🔧 Installation

In your Flutter/Dart project’s `pubspec.yaml`:

```yaml
dev_dependencies:
  asset_generator:
    path: ../asset_generator  # or replace with Git/hosted version
```

Then run:

```bash
flutter pub get
```

---

## 🏃‍♂️ CLI Usage

### 🖼️ Generate Asset Reference Class

```bash
dart run asset_generator <asset_path> [class_name]
```

| Argument      | Required | Description                                   |
|---------------|----------|-----------------------------------------------|
| `asset_path`  | ✅       | Path to your assets folder (e.g. `assets/icons`) |
| `class_name`  | ❌       | Class name to generate (default: `AppAssets`)   |

#### ✅ Example

```bash
dart run asset_generator assets/images AppImages
```

**Generates:**

```dart
// lib/generated/app_images.dart
class AppImages {
  AppImages._();

  static const String icGoogle = 'ic_google.png';
  static const String icArrowRight = 'ic_arrow_right.svg';
}
```

Use it like:

```dart
Image.asset(AppImages.icGoogle);
```

---

### 📦 Generate Barrel File

```bash
dart run asset_generator barrel <directory> [output_file_name]
```

| Argument          | Required | Description                                         |
|-------------------|----------|-----------------------------------------------------|
| `directory`       | ✅       | Directory containing Dart files to export          |
| `output_file_name`| ❌       | Output file name (default: `imports.dart`)           |

#### ✅ Example
```bash
dart run asset_generator barrel lib
```

```bash
dart run asset_generator barrel lib/widgets widget_exports
```

**Generates:**

```dart
// lib/widgets/widget_exports.dart
export 'button/custom_button.dart';
export 'form/input_field.dart';
export 'layout/grid_view.dart';
```

This allows clean imports in your app:

```dart
import 'package:your_app/widgets/widget_exports.dart';
```

---

## 📂 Output Paths

| Command                      | Output Location                         |
|------------------------------|------------------------------------------|
| Asset class                  | `lib/generated/{class_name}.dart`        |
| Barrel file                  | `{directory}/{output_file_name}.dart`    |

---

## 📄 License

**MIT License**  
© 2025 [Divyarajsinh Jadeja](https://github.com/DivyarajsinhJadeja)

---

## 🙌 Contributions

PRs and issues are welcome!  
If you find this tool helpful, consider giving it a ⭐️ on GitHub.