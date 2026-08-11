# Security Policy & Vulnerability Disclosure

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Threat Model & Security Boundary

PaintGuard is designed for incident response and remediation of the Paint Virus malware family.

### Security Architecture Principles
1. **Loopback Binding**: The REST host (`PaintGuardEngine.ps1`) binds exclusively to `127.0.0.1`. Remote TCP connections are refused.
2. **Bearer Token Authentication**: A cryptographically random 256-bit token is generated at startup and required on all `/api/` HTTP endpoints.
3. **Quarantine Vault Protection**: Quarantined threat binaries are stored as `{GUID}.bin` at `C:\ProgramData\PaintGuard\Quarantine\` with `{GUID}.json` metadata.
4. **Baseline Vault ACL Hardening**: The Baseline Vault at `C:\ProgramData\PaintGuard\Vault\` denies all permissions to `Everyone` and restricts access strictly to `SYSTEM` and `Administrators`.

## Reporting a Vulnerability

If you discover a security vulnerability in PaintGuard, please report it via private email or security issue report:
- **Email**: `security@paintguard-project.org`
- Do not disclose vulnerabilities in public issue trackers before a security patch is released.
- Include reproduction steps, PowerShell script execution context, and OS version details.
