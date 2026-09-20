# Security Policy

## 1. Security Architecture & Threat Model

Account Vault is designed from the ground up as a **zero-cloud, offline-first** credential manager. Security and user privacy are fundamental to every architectural decision:

- **Zero Network Footprint**: The application does not declare network permissions, make outbound HTTP/HTTPS requests, or embed any analytics, telemetry, or tracking SDKs.
- **Modern Cryptographic Standards**:
  - **Key Derivation (KDF)**: Memory-hardened **Argon2id** ($m = 65536 \text{ KiB}, t = 3, p = 1$) is used to derive a 256-bit encryption key from the user's master password, resisting GPU/ASIC brute-force attacks.
  - **Authenticated Encryption**: **AES-256-GCM** with unique, random 96-bit initialization vectors (IV) for every encryption operation. Additional Authenticated Data (AAD) binds the file format version, parameters, and salt to the payload to prevent tampering or replay.
  - **Format Specification**: Complete cryptographic format details and parameter requirements are documented and versioned in [docs/format-v1.md](docs/format-v1.md).
- **Atomic Persistence & Integrity Protection**:
  - Updates write to a temporary file, perform flush and fsync, verify decryptability before replacing the active database (`.avlt`), and automatically preserve a backup snapshot (`.previous.avlt`).
  - Corrupted or truncated writes will never overwrite a valid existing vault.
- **Session & Memory Safety**:
  - The derived master key is retained only in volatile process memory during the authenticated session and is not persisted to disk.

---

## 2. Supported Versions

Security patches and bug fixes are prioritized for the latest release series:

| Version Series | Supported |
| :--- | :--- |
| `1.x` | :white_check_mark: |
| `< 1.0.0` | :x: |

---

## 3. Reporting a Vulnerability

We take the security of Account Vault extremely seriously. If you identify a security vulnerability (e.g., cryptographic flaw, memory leakage, bypass of master key protections, or persistence flaw), **please do not open a public issue.**

Instead, please report vulnerabilities responsibly:

1. **GitHub Private Vulnerability Reporting**: Submit a private advisory report directly via GitHub Security Advisories (`Security` tab -> `Report a vulnerability`).
2. **Direct Security Contact**: If Private Vulnerability Reporting is unavailable, send an email to the project maintainer with the subject `[SECURITY] Account Vault Vulnerability Report`.

### Please Include:
- Detailed steps to reproduce the issue (PoC script, test case, or sample payload if applicable).
- The operating system, desktop compositor (e.g., niri, GNOME, Sway), and Account Vault version.
- An assessment of the potential impact (e.g., local privilege escalation, ciphertext recovery, plaintext disclosure).

### Response SLA
- **Initial Acknowledgement**: Within 48 hours.
- **Triage & Reproduction**: Within 5 business days.
- **Patch & Public Disclosure**: A coordinated release date will be mutually agreed upon, providing users sufficient time to update before technical vulnerability details are publicly disclosed.
