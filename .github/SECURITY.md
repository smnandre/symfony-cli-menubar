# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Symfony CLI Menu Bar, please report it responsibly:

### How to Report

1. **Do NOT create a public GitHub issue** for security vulnerabilities
2. **Email**: smn.andre@gmail.com with subject "Security: Symfony CLI Menu Bar"
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Response Time**: Within 48 hours
- **Investigation**: We'll investigate and confirm the issue
- **Fix Timeline**: Critical issues within 7 days, others within 30 days
- **Disclosure**: After fix is released, we'll credit you (unless you prefer anonymity)

### Security Best Practices

**For Users:**
- Download releases only from [GitHub Releases](https://github.com/smnandre/symfony-cli-menubar/releases)
- Verify DMG signature (if signed)
- Keep app updated to latest version
- Grant only necessary permissions

**For Contributors:**
- Never commit secrets, API keys, or certificates
- Validate and sanitize all user inputs
- Escape shell commands properly
- Review security implications of external commands

## Known Security Considerations

1. **Terminal Access**: App requests permission to control Terminal for viewing logs
2. **File System Access**: Reads Symfony project directories and PHP installations
3. **Process Execution**: Runs `symfony` CLI commands via shell
4. **No Network Requests**: App does not make external network calls

## Security Updates

Security updates will be:
- Released as patch versions (e.g., 1.0.1)
- Documented in [CHANGELOG.md](CHANGELOG.md)
- Announced in release notes
- Tagged with `security` label

## Thank You

We appreciate responsible disclosure and the security research community's efforts to keep open source software safe.
