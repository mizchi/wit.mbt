"""Build the pinned upstream WIT oracle in _build (Python 3 and Cargo)."""
import io
import json
from pathlib import Path
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent / "_build/spec-reference"
REVISION = "a104ec67f6b640ff21b41e67d1145a1d4411df06"
SOURCE = ROOT / ("wasm-tools-" + REVISION)
PROBE = ROOT / "probe"

if not (SOURCE / "Cargo.toml").exists():
    archive = urllib.request.urlopen("https://codeload.github.com/bytecodealliance/wasm-tools/tar.gz/" + REVISION, timeout=30).read()
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            path = ROOT / member.name
            path.resolve().relative_to(ROOT.resolve())
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(tar.extractfile(member).read())

(PROBE / "src").mkdir(parents=True, exist_ok=True)
crate = SOURCE / "crates/wit-parser"
(PROBE / "Cargo.toml").write_text('[package]\nname="wit-spec-probe"\nversion="0.1.0"\nedition="2024"\n[dependencies]\nwit-parser={path=' + json.dumps(str(crate)) + ',features=["serde"]}\nserde_json="1"\n')
(PROBE / "src/main.rs").write_text('''fn main() {
    let path = std::env::args().nth(1).expect("WIT path required");
    let mut resolve = wit_parser::Resolve::default();
    resolve.all_features = true;
    match resolve.push_path(path) {
        Ok(_) => println!("{}", serde_json::to_string(&resolve).unwrap()),
        Err(error) => { eprintln!("{error:#}"); std::process::exit(1); }
    }
}
''')
subprocess.run(["cargo", "build", "--quiet", "--manifest-path", str(PROBE / "Cargo.toml")], check=True)
print(PROBE / "target/debug/wit-spec-probe")
