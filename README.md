
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
  smart_asset_generator:
    path: ../smart_asset_generator  # adjust path as needed
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

### ✅ Scaffold GitLab PR Checker

```bash
dart run smart_asset_generator prchecker [dir=.gitlab] [file=pr_checker.py] [label="My GetX App"] [token=YOUR_TOKEN] [emails=dev1@example.com,dev2@example.com] [overwrite=true]
```
Example:
```bash
dart run smart_asset_generator prchecker dir=.gitlab file=pr_checker.py label="Universal GetX" token="glpat-xxxxxxxxxxxxxxxx" emails=admin@example.com overwrite=true
```

| Argument     | Required | Description                                                  |
|--------------|----------|--------------------------------------------------------------|
| `dir`        | ❌       | Target directory (default: `.gitlab`)                         |
| `file`       | ❌       | Output filename (default: `pr_checker.py`)                    |
| `label`      | ❌       | Display name used in the generated comments (default: `GetX Project`) |
| `token`      | ❌       | Personal Access Token baked into the script as fallback for `GITLAB_TOKEN` |
| `emails`     | ❌       | Comma-separated list of emails to receive report notifications |
| `overwrite`  | ❌       | Set to `true` to replace an existing file                     |

#### 📧 Email Notifications Setup

To enable email reports, the script requires SMTP configuration. You should set these as CI/CD variables in GitLab:

- `SMTP_SERVER`: Your SMTP server address (default: `smtp.gmail.com`).
- `SMTP_PORT`: SMTP port (default: `587`).
- `SMTP_USER`: Your SMTP username/email.
- `SMTP_PASSWORD`: Your SMTP password or App Password (recommended).
- `SMTP_SENDER`: Optional sender name or email.

#### ✅ Example

```bash
dart run smart_asset_generator prchecker overwrite=true
```

**Creates / updates:**
```
.gitlab/pr_checker.py
.gitlab-ci.yml (adds `mr-check` stage and `pr_checks` job if missing)
```

Once generated, make the script executable and ensure GitLab CI/CD variables `CI_PROJECT_ID`, `CI_MERGE_REQUEST_IID`, and `GITLAB_TOKEN` are configured for the pipeline.

> ⚠️ If you provide `token=...`, the value is written in plain text inside `.gitlab/pr_checker.py`. Prefer using environment variables in CI where possible.

#### 🔐 Required CI Variables

- `CI_PROJECT_ID`: Automatically provided by GitLab CI/CD when the job runs in a merge request pipeline. For local testing, copy it from your project’s **Settings → General → General project settings** (Project ID field).
- `CI_MERGE_REQUEST_IID`: Available in merge request pipelines as the internal ID (IID). You can find it in the merge request URL (the number after `/merge_requests/`), or via GitLab API: `GET /projects/:id/merge_requests`.
- `GITLAB_TOKEN`: Personal Access Token or CI job token with API scope used to call GitLab endpoints. Create one under **User Settings → Access Tokens**, enable `api`, then store it as a masked CI/CD variable (e.g., `Settings → CI/CD → Variables`).

##### Add `GITLAB_TOKEN` via GitLab UI

1. Navigate to your project’s **Settings → CI/CD → Variables** section.
2. Click **Add variable** to open the dialog (see screenshot).
3. Set **Key** to `GITLAB_TOKEN`.
4. Paste the personal access token into **Value**.
5. Keep **Type** as `Variable`, scope as `All (default)`.
6. Enable **Protect variable** if you only want it available on protected branches/tags.
7. Enable **Mask variable** so the value never appears in logs.
8. Click **Add variable** to save.

> Screenshot reference: GitLab “Add variable” dialog highlighting `Key`, `Value`, and the `Protect`/`Mask` flags.

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
