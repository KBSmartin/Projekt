//! Standalone start program for Verlorene Lande.
//!
//! WebAssembly does not load from `file://`, so the game needs a web server.
//! This program is that server: it serves the embedded Trunk build (see
//! `build.rs`) on 127.0.0.1 and opens the default browser. Closing the console
//! window ends it. Without embedded files it serves a folder instead
//! (`--dir <path>`, default `web` next to the program).
//!
//! Options: `--port <n>` (default: a free port), `--no-browser`, `--dir <path>`.

use std::borrow::Cow;
use std::env;
use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Component, Path, PathBuf};
use std::process::Command;
use std::thread;

mod embedded {
    include!(concat!(env!("OUT_DIR"), "/files.rs"));
}

enum Source {
    Embedded,
    Dir(PathBuf),
}

struct Options {
    port: u16,
    browser: bool,
    dir: Option<PathBuf>,
}

fn parse_args() -> Result<Options, String> {
    let mut opts = Options { port: 0, browser: true, dir: None };
    let mut args = env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--port" => {
                let v = args.next().ok_or("--port braucht eine Zahl")?;
                opts.port = v.parse().map_err(|_| format!("ungültiger Port: {v}"))?;
            }
            "--no-browser" => opts.browser = false,
            "--dir" => opts.dir = Some(args.next().ok_or("--dir braucht einen Ordner")?.into()),
            "-h" | "--help" => {
                println!("verlorene-lande [--port <n>] [--no-browser] [--dir <ordner>]");
                std::process::exit(0);
            }
            other => return Err(format!("unbekannte Option: {other}")),
        }
    }
    Ok(opts)
}

fn content_type(path: &str) -> &'static str {
    match path.rsplit('.').next().unwrap_or("") {
        "html" => "text/html; charset=utf-8",
        "js" => "text/javascript; charset=utf-8",
        "wasm" => "application/wasm",
        "css" => "text/css; charset=utf-8",
        "json" => "application/json",
        "png" => "image/png",
        "svg" => "image/svg+xml",
        "ico" => "image/x-icon",
        "woff2" => "font/woff2",
        _ => "application/octet-stream",
    }
}

fn lookup(source: &Source, path: &str) -> Option<Cow<'static, [u8]>> {
    match source {
        Source::Embedded => embedded::FILES
            .iter()
            .find(|(p, _)| *p == path)
            .map(|(_, bytes)| Cow::Borrowed(*bytes)),
        Source::Dir(dir) => {
            let rel = Path::new(path);
            // Only plain names below the folder, no "..".
            if !rel.components().all(|c| matches!(c, Component::Normal(_))) {
                return None;
            }
            std::fs::read(dir.join(rel)).ok().map(Cow::Owned)
        }
    }
}

fn handle(mut stream: TcpStream, source: &Source) -> std::io::Result<()> {
    let mut reader = BufReader::new(stream.try_clone()?);
    let mut request = String::new();
    reader.read_line(&mut request)?;
    // Skip the headers.
    let mut line = String::new();
    while reader.read_line(&mut line)? > 2 {
        line.clear();
    }
    let mut parts = request.split_whitespace();
    let method = parts.next().unwrap_or("");
    let target = parts.next().unwrap_or("/");
    let path = target.split(['?', '#']).next().unwrap_or("/").trim_start_matches('/');
    let path = if path.is_empty() { "index.html" } else { path };

    let found = if method == "GET" || method == "HEAD" { lookup(source, path) } else { None };
    match found {
        Some(body) => {
            write!(
                stream,
                "HTTP/1.1 200 OK\r\nContent-Type: {}\r\nContent-Length: {}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
                content_type(path),
                body.len()
            )?;
            if method == "GET" {
                stream.write_all(&body)?;
            }
        }
        None => {
            let msg = b"Nicht gefunden";
            write!(
                stream,
                "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                msg.len()
            )?;
            stream.write_all(msg)?;
        }
    }
    stream.flush()
}

fn open_browser(url: &str) {
    let result = if cfg!(target_os = "windows") {
        Command::new("cmd").args(["/C", "start", "", url]).spawn()
    } else if cfg!(target_os = "macos") {
        Command::new("open").arg(url).spawn()
    } else {
        Command::new("xdg-open").arg(url).spawn()
    };
    if result.is_err() {
        println!("Browser ließ sich nicht öffnen. Bitte die Adresse oben selbst aufrufen.");
    }
}

fn fail(msg: &str) -> ! {
    eprintln!("Fehler: {msg}");
    if cfg!(target_os = "windows") {
        // Keep a double-clicked console window open long enough to read.
        eprintln!("Enter drücken zum Beenden.");
        let _ = std::io::stdin().read_line(&mut String::new());
    }
    std::process::exit(1);
}

fn main() {
    let opts = parse_args().unwrap_or_else(|e| fail(&e));
    let source = match opts.dir {
        Some(dir) => Source::Dir(dir),
        None if !embedded::FILES.is_empty() => Source::Embedded,
        None => {
            let exe = env::current_exe().unwrap_or_default();
            Source::Dir(exe.parent().unwrap_or(Path::new(".")).join("web"))
        }
    };
    if let Source::Dir(dir) = &source
        && !dir.join("index.html").is_file()
    {
        fail(&format!("keine index.html in {}", dir.display()));
    }

    let listener = TcpListener::bind(("127.0.0.1", opts.port))
        .unwrap_or_else(|e| fail(&format!("Port {} nicht verfügbar: {e}", opts.port)));
    let port = listener.local_addr().map(|a| a.port()).unwrap_or(opts.port);
    let url = format!("http://127.0.0.1:{port}/");

    let variant = if embedded::VARIANT.is_empty() { String::new() } else { format!(" ({})", embedded::VARIANT) };
    println!("Verlorene Lande{variant} läuft auf {url}");
    println!("Dieses Fenster offen lassen. Schließen beendet das Spiel.");
    if opts.browser {
        open_browser(&url);
    }

    let source: &'static Source = Box::leak(Box::new(source));
    for stream in listener.incoming().flatten() {
        thread::spawn(move || {
            let _ = handle(stream, source);
        });
    }
}
