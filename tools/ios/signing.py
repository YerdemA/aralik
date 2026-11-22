"""iOS signing files on Windows, without a Mac's Keychain.

The App Store build runs on GitHub Actions (.github/workflows/ios-release.yml)
and signs with a distribution certificate and an App Store provisioning
profile kept as repository secrets. This makes them with openssl (the one
in Git for Windows is enough):

    python tools/ios/signing.py csr               # key + request to upload
    python tools/ios/signing.py p12 distribution.cer
    python tools/ios/signing.py profile Kabaca_App_Store.mobileprovision

Everything goes to app-store/signing/ (not in git). The private key there is
the certificate: back it up next to the Android upload key.
"""

import base64
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "app-store" / "signing"
KEY = OUT / "dist.key"


def openssl(*args: str) -> None:
    # Git's mingw64 build: its usr/bin one rewrites "/CN=..." as a path.
    exe = shutil.which("openssl") or r"C:\Program Files\Git\mingw64\bin\openssl.exe"
    if not Path(exe).exists() and not shutil.which(exe):
        sys.exit("openssl bulunamadı (Git for Windows ile gelir).")
    subprocess.run([exe, *args], check=True)


def write_b64(source: Path, target: Path) -> None:
    target.write_text(base64.b64encode(source.read_bytes()).decode(), "ascii")
    print(f"  {target}  (GitHub secret değeri)")


def csr() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if KEY.exists():
        sys.exit(f"{KEY} zaten var; yenisi eski sertifikayı işe yaramaz kılar.")
    openssl("genrsa", "-out", str(KEY), "2048")
    openssl(
        "req", "-new", "-key", str(KEY), "-out", str(OUT / "dist.csr"),
        "-subj", "/CN=Kabaca Distribution/C=TR",
    )
    print(f"  {OUT / 'dist.csr'}  → Certificates → + → Apple Distribution")


def p12(cer: str) -> None:
    if not KEY.exists():
        sys.exit("Önce: python tools/ios/signing.py csr")
    pem = OUT / "dist.pem"
    openssl("x509", "-inform", "DER", "-in", cer, "-out", str(pem))
    password = secrets.token_urlsafe(18)
    target = OUT / "dist.p12"
    # SHA1-3DES: macOS's `security import` rejects OpenSSL 3's default.
    openssl(
        "pkcs12", "-export", "-inkey", str(KEY), "-in", str(pem),
        "-out", str(target), "-passout", f"pass:{password}",
        "-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES",
        "-macalg", "sha1", "-name", "Kabaca Distribution",
    )
    (OUT / "dist.p12.password").write_text(password, "ascii")
    print(f"  {OUT / 'dist.p12.password'}  → IOS_DIST_CERT_PASSWORD")
    write_b64(target, OUT / "IOS_DIST_CERT_P12.txt")


def profile(path: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_b64(Path(path), OUT / "IOS_PROFILE.txt")


def main() -> None:
    match sys.argv[1:]:
        case ["csr"]:
            csr()
        case ["p12", cer]:
            p12(cer)
        case ["profile", path]:
            profile(path)
        case _:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()
