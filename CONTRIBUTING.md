# Contributing to Account Vault

Thank you for your interest in contributing to **Account Vault**! We welcome contributions, bug reports, and feature proposals from the open-source community.

---

## 1. Development Environment Setup

Account Vault is built with [Flutter](https://flutter.dev) targeting Linux desktop (with Wayland & niri compositor deep integration) and Android.

### System Prerequisites (Linux)
Ensure the following packages and compilers are installed on your Linux system:

- **Arch Linux / Manjaro**:
  ```bash
  sudo pacman -S base-devel clang cmake ninja pkgconf gtk3
  ```
- **Ubuntu / Debian**:
  ```bash
  sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
  ```
- **Fedora**:
  ```bash
  sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel
  ```

### Flutter & Dart SDK
- Install [Flutter SDK (stable channel, 3.x+)](https://docs.flutter.dev/get-started/install/linux).
- Ensure `flutter` and `dart` are available in your system `$PATH`:
  ```bash
  flutter doctor
  ```

### Getting the Code
```bash
git clone https://github.com/<your-username>/account-vault.git
cd account-vault/app
flutter pub get
```

---

## 2. Running & Testing

### Running Locally
```bash
cd app
flutter run -d linux
```

### Static Analysis & Formatting
Before committing, ensure your code complies with the project's analysis options:
```bash
cd app
dart format --output=none --set-exit-if-changed .
flutter analyze
```

### Running Test Suite
All automated tests must pass before submitting a pull request:
```bash
cd app
flutter test
```

---

## 3. Pull Request Guidelines

1. **Fork and Branch**: Create a focused topic branch from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```
2. **Atomic Commits**: Keep commits granular and self-contained.
3. **Commit Message Format**: Follow [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat(...)`: New feature or capability.
   - `fix(...)`: Bug fix.
   - `docs(...)`: Documentation updates.
   - `refactor(...)`: Code refactoring without behavior change.
   - `test(...)`: Adding or updating test cases.
   - `chore(...)`: Tooling, dependency, or packaging updates.
4. **Test Coverage**: Any new feature or bug fix should include unit or widget tests in `app/test/`.
5. **No Breaking Cryptographic Changes**: Changes that affect the file format (`.avlt`) must strictly follow and update [docs/format-v1.md](docs/format-v1.md) with migration guarantees.

---

## 4. Reporting Issues

- **Bug Reports**: Please open an issue using the Bug Report template, detailing your Linux distribution, compositor (e.g. niri, Sway, GNOME), and reproduction steps.
- **Feature Requests**: Discuss your idea first using the Feature Request template to align with the project goals (offline, lightweight, zero-cloud).
- **Security Vulnerabilities**: Do not report security flaws via public issues; please follow [SECURITY.md](SECURITY.md).
