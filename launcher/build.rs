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

/// Turns `zeichen.ico` into a compiled resource file (`.res`) and hands it to
/// the MSVC linker, so the exe shows the game emblem. No tools needed: the
/// format is written here (an empty first entry, one RT_ICON per image, one
/// RT_GROUP_ICON that lists them).
fn icon_resource() {
    let target = env::var("TARGET").unwrap_or_default();
    if !target.contains("windows-msvc") {
        return;
    }
    println!("cargo:rerun-if-changed=zeichen.ico");
    let ico = fs::read("zeichen.ico").expect("launcher/zeichen.ico");
    let u16_at = |i: usize| u16::from_le_bytes([ico[i], ico[i + 1]]);
    let u32_at = |i: usize| u32::from_le_bytes([ico[i], ico[i + 1], ico[i + 2], ico[i + 3]]);
    let count = usize::from(u16_at(4));
    let mut res = Vec::new();
    let entry = |res: &mut Vec<u8>, kind: u16, id: u16, flags: u16, data: &[u8]| {
        for v in [data.len() as u32, 32] {
            res.extend_from_slice(&v.to_le_bytes());
        }
        for v in [0xffff, kind, 0xffff, id] {
            res.extend_from_slice(&u16::to_le_bytes(v));
        }
        res.extend_from_slice(&0u32.to_le_bytes());
        res.extend_from_slice(&flags.to_le_bytes());
        res.extend_from_slice(&0u16.to_le_bytes());
        res.extend_from_slice(&[0; 8]);
        res.extend_from_slice(data);
        while !res.len().is_multiple_of(4) {
            res.push(0);
        }
    };
    res.extend_from_slice(&[0, 0, 0, 0, 32, 0, 0, 0, 0xff, 0xff, 0, 0, 0xff, 0xff, 0, 0]);
    res.extend_from_slice(&[0; 16]);
    let mut group = vec![0, 0, 1, 0];
    group.extend_from_slice(&(count as u16).to_le_bytes());
    for i in 0..count {
        let e = 6 + 16 * i;
        let (size, offset) = (u32_at(e + 8) as usize, u32_at(e + 12) as usize);
        entry(
            &mut res,
            3,
            i as u16 + 1,
            0x1010,
            &ico[offset..offset + size],
        );
        group.extend_from_slice(&ico[e..e + 12]);
        group.extend_from_slice(&(i as u16 + 1).to_le_bytes());
    }
    entry(&mut res, 14, 1, 0x1030, &group);
    let out = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR")).join("zeichen.res");
    fs::write(&out, res).expect("write zeichen.res");
    println!("cargo:rustc-link-arg-bins={}", out.display());
}

fn main() {
    icon_resource();
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
        let _ = writeln!(
            code,
            "    ({url:?}, include_bytes!({:?})),",
            path.to_string_lossy()
        );
    }
    code.push_str("];\n");
    let _ = writeln!(code, "pub const VARIANT: &str = {variant:?};");
    let out = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR")).join("files.rs");
    fs::write(out, code).expect("write files.rs");
}
