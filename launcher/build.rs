//! Embeds the files of a Trunk build into the launcher.
//!
//! `VL_WEB_DIR` names the build output (for example `target/web/release`),
//! `VL_VARIANT` a label shown in the console. Without `VL_WEB_DIR` nothing is
//! embedded and the launcher serves a folder at run time instead.

use std::env;
use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};

fn collect(dir: &Path, base: &Path, out: &mut Vec<(String, PathBuf)>) {
    let mut entries: Vec<_> = fs::read_dir(dir)
        .unwrap_or_else(|e| panic!("cannot read {}: {e}", dir.display()))
        .map(|e| e.expect("directory entry").path())
        .collect();
    entries.sort();
    for path in entries {
        if path.is_dir() {
            collect(&path, base, out);
        } else {
            let rel = path.strip_prefix(base).expect("inside base");
            let url = rel.to_string_lossy().replace('\\', "/");
            println!("cargo:rerun-if-changed={}", path.display());
            out.push((url, path));
        }
    }
}

fn main() {
    println!("cargo:rerun-if-env-changed=VL_WEB_DIR");
    println!("cargo:rerun-if-env-changed=VL_VARIANT");
    let mut files = Vec::new();
    if let Ok(dir) = env::var("VL_WEB_DIR") {
        let dir = fs::canonicalize(&dir).unwrap_or_else(|e| panic!("VL_WEB_DIR {dir}: {e}"));
        println!("cargo:rerun-if-changed={}", dir.display());
        collect(&dir, &dir, &mut files);
        assert!(
            files.iter().any(|(u, _)| u == "index.html"),
            "VL_WEB_DIR has no index.html"
        );
    }
    let variant = env::var("VL_VARIANT").unwrap_or_default();
    let mut code = String::from("pub static FILES: &[(&str, &[u8])] = &[\n");
    for (url, path) in &files {
        let _ = writeln!(code, "    ({url:?}, include_bytes!({:?})),", path.to_string_lossy());
    }
    code.push_str("];\n");
    let _ = writeln!(code, "pub const VARIANT: &str = {variant:?};");
    let out = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR")).join("files.rs");
    fs::write(out, code).expect("write files.rs");
}
