use serde_json::{json, Value};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, atomic::{AtomicBool, Ordering}};
use std::time::{Duration, Instant};

pub const PREFIX: &str = "seabunny-archive:";

pub fn supported(path: &Path) -> bool {
    let name = path.to_string_lossy().to_lowercase();
    [".zip", ".zipx", ".7z", ".rar", ".tar", ".tar.gz", ".tar.xz", ".tar.bz2", ".tar.zst", ".tar.lz4", ".tar.lzma", ".tgz", ".txz", ".tbz2", ".cab", ".arj", ".lha", ".lzh", ".cpio"]
        .iter().any(|suffix| name.ends_with(suffix))
}

pub fn root(path: &Path) -> String {
    let bytes = path.to_string_lossy().as_bytes().iter().map(|byte| format!("{byte:02x}")).collect::<String>();
    format!("{PREFIX}{bytes}")
}

pub fn parse(value: &str) -> Option<(PathBuf, String)> {
    let value = value.strip_prefix(PREFIX)?;
    let (encoded, member) = value.split_once('/').unwrap_or((value, ""));
    if encoded.len() % 2 != 0 || !encoded.bytes().all(|byte| byte.is_ascii_hexdigit()) { return None; }
    let bytes = (0..encoded.len()).step_by(2).map(|index| u8::from_str_radix(&encoded[index..index + 2], 16)).collect::<Result<Vec<_>, _>>().ok()?;
    let path = PathBuf::from(String::from_utf8(bytes).ok()?);
    if !path.is_absolute() || path.to_string_lossy().contains('\0') || member.contains(['\\', '\0'])
        || member.split('/').any(|part| part == ".." || part == "." || part.is_empty() && !member.is_empty()) { return None; }
    Some((path, member.to_string()))
}

pub fn available(value: &str) -> bool {
    parse(value).map(|(path, _)| path.is_file()).unwrap_or_else(|| Path::new(value).is_dir())
}

pub fn run(request: &Value, cancelled: impl Fn() -> bool) -> Result<Value, String> {
    if cancelled() { return Err("Archive operation cancelled".into()); }
    let mut child = Command::new("python3").args(["-I", "-c", include_str!("archive_backend.py")])
        .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped()).spawn().map_err(|error| error.to_string())?;
    let input = child.stdin.take().unwrap().write_all(request.to_string().as_bytes());
    if let Err(error) = input { let _ = child.kill(); let _ = child.wait(); return Err(error.to_string()); }
    let overflow = Arc::new(AtomicBool::new(false));
    let out_overflow = overflow.clone();
    let mut stdout = child.stdout.take().unwrap();
    let output = std::thread::spawn(move || {
        let mut bytes = Vec::new();
        let _ = stdout.by_ref().take(16 * 1024 * 1024 + 1).read_to_end(&mut bytes);
        if bytes.len() > 16 * 1024 * 1024 { out_overflow.store(true, Ordering::Relaxed); }
        let _ = std::io::copy(&mut stdout, &mut std::io::sink());
        bytes
    });
    let mut stderr = child.stderr.take().unwrap();
    let errors = std::thread::spawn(move || {
        let mut bytes = Vec::new();
        let _ = stderr.by_ref().take(4096).read_to_end(&mut bytes);
        let _ = std::io::copy(&mut stderr, &mut std::io::sink());
        bytes
    });
    let start = Instant::now();
    let status = loop {
        if cancelled() || overflow.load(Ordering::Relaxed) || start.elapsed() > Duration::from_secs(600) {
            unsafe { libc::kill(child.id() as libc::pid_t, libc::SIGTERM); }
            for _attempt in 0..20 {
                if matches!(child.try_wait(), Ok(Some(_))) { break; }
                std::thread::sleep(Duration::from_millis(10));
            }
            let _ = child.kill();
            let _ = child.wait();
            let _ = output.join();
            let _ = errors.join();
            return Err("Archive operation cancelled, too large, or timed out".into());
        }
        match child.try_wait() {
            Ok(Some(status)) => break status,
            Ok(None) => std::thread::sleep(Duration::from_millis(20)),
            Err(error) => { let _ = child.kill(); let _ = child.wait(); return Err(error.to_string()); }
        }
    };
    let bytes = output.join().map_err(|_| "Archive reader failed")?;
    let error = errors.join().unwrap_or_default();
    if !status.success() { return Err(String::from_utf8_lossy(&error).trim().to_string()); }
    if overflow.load(Ordering::Relaxed) { return Err("Archive index is too large".into()); }
    serde_json::from_slice(&bytes).map_err(|error| error.to_string())
}

pub fn list(value: &str, cancelled: impl Fn() -> bool) -> Result<Value, String> {
    let (archive, directory) = parse(value).ok_or("Invalid archive location")?;
    run(&json!({"action": "list", "archive": archive, "directory": directory}), cancelled)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn virtual_paths_roundtrip_without_separator_or_traversal_ambiguity() {
        let path = Path::new("/tmp/Space !/日本語 #.zip");
        let location = root(path);
        assert_eq!(parse(&format!("{location}/inner/файл.txt")), Some((path.to_path_buf(), "inner/файл.txt".into())));
        for member in ["../escape", "a/../b", "/absolute", "a\\b", "a//b"] { assert!(parse(&format!("{location}/{member}")).is_none()); }
        assert!(parse("seabunny-archive:zz").is_none());
        assert!(parse("seabunny-archive:2e2e").is_none());
    }

    #[test]
    fn cancellation_reaps_only_the_owned_archive_helper() {
        use std::sync::atomic::AtomicUsize;
        let calls = AtomicUsize::new(0);
        let start = Instant::now();
        let result = run(&json!({"action": "list", "archive": "/nonexistent-seabunny-archive-fixture"}),
            || calls.fetch_add(1, Ordering::Relaxed) > 0);
        assert!(result.unwrap_err().contains("cancelled"));
        assert!(start.elapsed() < Duration::from_secs(3));
    }
}
