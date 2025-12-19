
# 🛠️ Smart Asset Generator



A powerful and flexible Dart/Flutter CLI tool to **auto-generate asset reference classes**, **barrel files**, and **GetX module scaffolding** — making asset management and project structure consistent, clean, and fast.


---

## ✨ Features

✅ Automatically scans folders and generates asset reference classes (`AppImages`, etc.)
✅ Converts file names to `camelCase` constants
✅ Supports nested folders and all file types
✅ Barrel file generator to export Dart files from any directory
✅ Modular code generator for GetX (controller, binding, view)
✅ Project cloning with custom Android/iOS package names and optional path
✅ GitLab MR checker scaffold for GetX conventions
✅ CLI-ready with clean syntax
✅ Fully customizable output structure
✅ Works in Flutter and pure Dart projects
✅ Build Android APK / iOS IPA and upload to Loadly (Diawi alternative)
✅ One command to build both APK and IPA with install links printed

---

## 📦 Use Cases

* Generate `AppImages` class to avoid hardcoded asset strings
* Create `exports.dart` barrel file to group exports cleanly
* Scaffold complete module (binding/controller/view) with a single command
* Clone a Flutter project with new app name and package IDs
* Keep your imports scalable and clean in large projects


---

## 🚀 Installation

In your Flutter/Dart project’s `pubspec.yaml`:

```yaml
dev_dependencies:
  smart_asset_generator: <latest_version>
```

Then run:

```bash
flutter pub get
```

---

## 🏃 CLI Usage

Run using:

```bash
dart run smart_asset_generator <command> [arguments]
```

---

### 🔹 Commands Overview

| Command      | Description                                              |
|--------------|----------------------------------------------------------|
| `asset`      | Generate Dart class with asset paths                     |
| `barrel`     | Generate a barrel file that exports Dart files           |
| `module`     | Create a module with controller, binding, and view files |
| `clone`      | Clone the entire project with new package identifiers    |
| `apk`        | Build APK and upload to Loadly (Diawi alternative)       |
| `ipa`        | Build IPA (macOS only) and upload to Loadly              |
| `apps`       | Build both APK and IPA and upload to Loadly              |
| `init`       | Create `smart_asset_generator.yaml` to save API key       |
| `prchecker`  | Scaffold `.gitlab/pr_checker.py` for MR validations      |

---

### 🖼️ Generate Asset Class

```bash
dart run smart_asset_generator asset <asset_path> [class_name]
```

| Argument      | Required | Description                                  |
|---------------|----------|----------------------------------------------|
| `asset_path`  | ✅       | Path to folder containing asset files         |
| `class_name`  | ❌       | Class name (default: `AppAssets`)             |

#### ✅ Example

```bash
dart run smart_asset_generator asset assets/images AppImages
```

**Output:**
```
lib/generated/app_images.dart
```

---

### 📦 Generate Barrel File

```bash
dart run smart_asset_generator barrel <directory_path> [output_file_name]
```

| Argument           | Required | Description                                    |
|--------------------|----------|------------------------------------------------|
| `directory_path`   | ✅       | Folder to scan for `.dart` files               |
| `output_file_name` | ❌       | Output file name (default: `exports.dart`)     |

#### ✅ Example

```bash
dart run smart_asset_generator barrel lib/widgets widget_exports
```

**Output:**
```
lib/widgets/widget_exports.dart
```

---

### 🧱 Generate Module (GetX structure)

```bash
dart run smart_asset_generator module name=<module_name> location=<path> [export=<barrel_file_path>]
```

| Argument      | Required | Description                                           |
|---------------|----------|-------------------------------------------------------|
| `name`        | ✅       | Module name (`home`, `profile`, etc.)                 |
| `location`    | ✅       | Where to create the module (e.g., `lib/modules`)      |
| `export`      | ❌       | Optional barrel file path to append exports to        |

#### ✅ Example

```bash
dart run smart_asset_generator module name=home location=lib/modules
```

**Creates:**

```
lib/modules/home/
├── bindings/home_binding.dart
├── controller/home_controller.dart
└── view/home_page.dart
```

Also appends exports to:
```
lib/modules/exports.dart
```

You can override export file:

```bash
dart run smart_asset_generator module name=login location=lib/ui export=lib/ui/index.dart
```

---

### 🔁 Clone Existing Project

```bash
dart run smart_asset_generator clone name=<new_project_name> android=<android_package> ios=<ios_package> [path=<directory_path>]
```

| Argument     | Required | Description                                                                 |
|--------------|----------|-----------------------------------------------------------------------------|
| `name`       | ✅       | New Flutter project name in `snake_case`                                    |
| `android`    | ✅       | New Android package name (e.g., `com.my.app`)                               |
| `ios`        | ✅       | New iOS bundle identifier (e.g., `com.my.app`)                               |
| `path`       | ❌       | Optional path where the new project will be created (default: parent folder) |

#### ✅ Example

```bash
dart run smart_asset_generator clone name=new_app android=com.new.android ios=com.new.ios path=/Users/you/FlutterProjects
```

**Performs:**

- Duplicates current project folder to the specified path (or the parent folder if `path` is not provided)
- Updates:
  - `pubspec.yaml` project name
  - Android: `applicationId` in `build.gradle`, `AndroidManifest.xml`, `.iml` files
  - iOS: `CFBundleIdentifier` in `Info.plist`
  - Renames root `.iml` and Android module `.iml` files
  - Replaces package names and project references in all source files
- Ensures the cloned project is ready to open and run independently

---

### ☁️ Build APK and Upload to Loadly

```bash
dart run smart_asset_generator apk [release|debug] apiKey=<YOUR_API_KEY> [buildInstallType=1|2|3] [buildPassword=<pwd>] [desc=<notes>]
```

| Argument             | Required | Description                                              |
|----------------------|----------|----------------------------------------------------------|
| `release|debug`      | ❌       | Build type (default: `release`)                          |
| `apiKey`             | ✅       | Loadly API key (`_api_key`)                              |
| `buildInstallType`   | ❌       | 1: public, 2: password, 3: invitation (default: 1)      |
| `buildPassword`      | ❌       | Password if `buildInstallType=2`                         |
| `desc`               | ❌       | Update description                                       |

#### ✅ Example

```bash
dart run smart_asset_generator apk release apiKey=YOUR_KEY buildInstallType=1 desc="Initial release"
```

On success, the tool prints the install page URL, shortcut URL (if any), and build key returned by Loadly.

---

### 🍎 Build IPA and Upload to Loadly (macOS only)

```bash
dart run smart_asset_generator ipa [apiKey=<YOUR_API_KEY>] [buildInstallType=1|2|3] [buildPassword=<pwd>] [desc=<notes>]
```

| Argument             | Required | Description                                              |
|----------------------|----------|----------------------------------------------------------|
| `apiKey`             | ❌       | Loadly API key (omit if saved via init file)            |
| `buildInstallType`   | ❌       | 1: public, 2: password, 3: invitation (default: 1)      |
| `buildPassword`      | ❌       | Password if `buildInstallType=2`                         |
| `desc`               | ❌       | Update description                                       |

#### ✅ Example

```bash
dart run smart_asset_generator ipa apiKey=YOUR_KEY buildInstallType=1 desc="iOS test build"
```

Note: Requires macOS with iOS signing configured in Xcode.

---

### 🔀 Build Both: APK + IPA (with links)

```bash
dart run smart_asset_generator apps [release|debug] [apiKey=<YOUR_API_KEY>] [buildInstallType=1|2|3] [buildPassword=<pwd>] [desc=<notes>]
```

| Argument             | Required | Description                                              |
|----------------------|----------|----------------------------------------------------------|
| `release|debug`      | ❌       | Build type for Android (default: `release`)              |
| `apiKey`             | ❌       | Loadly API key (omit if saved via init file)            |
| `buildInstallType`   | ❌       | 1: public, 2: password, 3: invitation (default: 1)      |
| `buildPassword`      | ❌       | Password if `buildInstallType=2`                         |
| `desc`               | ❌       | Update description                                       |

#### ✅ Example

```bash
dart run smart_asset_generator apps release apiKey=YOUR_KEY desc="Weekly QA build"
```

The command prints separate APK and IPA install links from Loadly.

---

### 🧰 One-time Init (optional)

Create a project config file to store your Loadly API key and see handy example commands:

```bash
dart run smart_asset_generator init
```

This creates `smart_asset_generator.yaml`. Add your API key under:

```
loadlyApiKey: "YOUR_KEY"
```

You can still pass `apiKey=YOUR_KEY` inline to any command if you prefer.

You can visit this website to create apiKey https://loadly.io/doc/view/api

---

### 🛡️ GitLab PR Checker & Quality Dashboard

Transform your Merge Requests into a professional quality gate. This tool generates a stakeholder-friendly dashboard that reviews code security, architecture, and best practices.

#### 📊 What it does:
- **Executive Scorecard**: A high-level health score for PMs and Clients.
- **Categorized Business Impact**: Issues are grouped by *Security*, *Architecture*, and *Quality*.
- **Direct Developer Feedback**: Expandable technical details with file/line numbers for developers.
- **Automated Emails**: Beautiful, branded email reports sent to your team.

#### 🚀 Quick Setup

```bash
# Basic setup
dart run smart_asset_generator prchecker label="Ashraf Rewamp"

# Update an existing checker
dart run smart_asset_generator prchecker label="Ashraf Rewamp" overwrite=true
```

| Argument     | Required | Description                                                  |
|--------------|----------|--------------------------------------------------------------|
| `label`      | ❌       | Branded project name used in dashboard & emails (e.g. "Ashraf Rewamp") |
| `token`      | ❌       | Personal Access Token fallback (Not recommended; use CI variables instead) |
| `overwrite`  | ❌       | Set to `true` to update the script with the latest UI features |

---

#### 🔒 Secure Email Management
For maximum security and ease of management, email recipients are **controlled centrally** via GitLab. Developers cannot change who receives these reports in the source code.

1.  **Go to GitLab Dashboard**: Navigate to **Settings > CI/CD > Variables**.
2.  **Add Management Emails**:
    - **Key**: `PR_CHECKER_EMAILS`
    - **Value**: `manager@company.com, client@domain.com` (comma-separated).
#### 🔐 Required CI/CD Variables
To enable the full Dashboard and Email features, add these **4 variables** in your GitLab Project **Settings > CI/CD > Variables**:

1.  **`GITLAB_TOKEN`**: A Personal Access Token with `api` scope (Enable **Masked**).
2.  **`PR_CHECKER_EMAILS`**: Comma-separated list of recipients (e.g., `pm@co.com, client@co.com`).
3.  **`SMTP_USER`**: Your sender email (e.g., `reports@yourcompany.com`).
4.  **`SMTP_PASSWORD`**: Your **App Password** (See below how to generate).

---

#### � How to get a Gmail App Password
If you are using Gmail, your regular password will not work. You must generate an "App Password":
1.  Go to your [Google Account Settings](https://myaccount.google.com/).
2.  Navigate to **Security**.
3.  Under "How you sign in to Google," ensure **2-Step Verification** is ON.
4.  Click on **2-Step Verification**, then scroll to the bottom and click **App Passwords**.
5.  Enter a name (e.g., "GitLab PR Checker") and click **Create**.
6.  **Copy the 16-character code** and paste it as your `SMTP_PASSWORD` in GitLab.

---

> **Note**: This setup is "set and forget." Once configured in GitLab, every new Merge Request will automatically generate a professional quality report.

---

## 🗂️ Output Summary

| Command  | Output Location                                  |
|----------| ------------------------------------------------ |
| `asset`  | `lib/generated/{class_name}.dart`                |
| `barrel` | `{directory}/{output_file_name}.dart`            |
| `module` | `{location}/{name}/...` + exports to barrel file |
| `clone`  | `{path}/{new_project_name}/`                     |
| `apk`    | `build/app/outputs/flutter-apk/` (auto-renamed APK) |
| `ipa`    | `build/ios/ipa/` (auto-renamed IPA)              |
| `apps`   | APK: `build/app/outputs/flutter-apk/`, IPA: `build/ios/ipa/`; prints Loadly links |

---

## 📄 License

**MIT License**  
© 2025 [Divyarajsinh Jadeja](https://github.com/DivyarajsinhJadeja)

---

## 🙌 Contributions

Pull requests, issues, and suggestions are welcome!  
If this tool saves you time, please ⭐ star the repo and share it with your team!
