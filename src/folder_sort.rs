//! Sparse, shared folder preferences. Browsing defaults never writes state.
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, fs, io::{Read, Write}, os::{fd::AsRawFd, unix::fs::OpenOptionsExt}, path::{Path, PathBuf}};

const MAX_BYTES: u64 = 1024 * 1024;
const MAX_FOLDERS: usize = 4096;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct Sort {
    pub field: String,
    pub ascending: bool,
    pub folders: String,
}

impl Default for Sort {
    fn default() -> Self {
        Self { field: "name".into(), ascending: true, folders: "mixed".into() }
    }
}

impl Sort {
    fn valid(&self) -> bool {
        ["name", "modified", "size", "type"].contains(&self.field.as_str())
            && ["first", "last", "mixed"].contains(&self.folders.as_str())
    }
}

#[derive(Deserialize, Serialize)]
struct Store {
    version: u32,
    folders: BTreeMap<String, Sort>,
}

pub fn state_file() -> PathBuf {
    let base = std::env::var_os("XDG_STATE_HOME").filter(|s| !s.is_empty()).map(PathBuf::from)
        .filter(|p| p.is_absolute()).unwrap_or_else(|| {
            PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
        });
    base.join("seabunny/folder-sorting.json")
}

fn key(path: &Path) -> Option<String> {
    let canonical = fs::canonicalize(path).ok()?;
    if !canonical.is_dir() { return None; }
    canonical.to_str().map(str::to_owned)
}

fn load(file: &Path) -> Result<Store, String> {
    let input = match fs::OpenOptions::new().read(true).custom_flags(libc::O_NOFOLLOW).open(file) {
        Ok(input) => input,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Store { version: 1, folders: BTreeMap::new() }),
        Err(e) => return Err(e.to_string()),
    };
    let mut bytes = Vec::new();
    input.take(MAX_BYTES + 1).read_to_end(&mut bytes).map_err(|e| e.to_string())?;
    if bytes.len() as u64 > MAX_BYTES { return Err("Folder sorting state exceeds its size limit".into()); }
    let store: Store = serde_json::from_slice(&bytes).map_err(|e| e.to_string())?;
    if store.version != 1 || store.folders.len() > MAX_FOLDERS
        || store.folders.iter().any(|(path, sort)| !Path::new(path).is_absolute() || !sort.valid()) {
        return Err("Invalid folder sorting state; existing contents preserved".into());
    }
    Ok(store)
}

pub fn get(file: &Path, path: &Path) -> Sort {
    key(path).and_then(|key| load(file).ok()?.folders.remove(&key)).unwrap_or_default()
}

pub fn save(file: &Path, path: &Path, sort: Sort) -> Result<(), String> {
    if !sort.valid() { return Err("Invalid sorting preference".into()); }
    // Virtual locations (including archive members) have no filesystem folder state.
    let Some(key) = key(path) else { return Ok(()); };
    let parent = file.parent().ok_or("Missing state directory")?;
    fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let lock = fs::OpenOptions::new().write(true).create(true).truncate(false).mode(0o600)
        .custom_flags(libc::O_NOFOLLOW).open(file.with_extension("lock")).map_err(|e| e.to_string())?;
    // Separate tabs and the portal process must merge with the latest on-disk state.
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        return Err("Folder sorting preferences are busy; try again".into());
    }
    let mut store = load(file)?;
    let before = store.folders.clone();
    if sort == Sort::default() { store.folders.remove(&key); }
    else { store.folders.insert(key, sort); }
    if store.folders == before { return Ok(()); }
    if store.folders.len() > MAX_FOLDERS { return Err("Folder sorting preference limit reached".into()); }
    let bytes = serde_json::to_vec(&store).map_err(|e| e.to_string())?;
    if bytes.len() as u64 > MAX_BYTES { return Err("Folder sorting preference size limit reached".into()); }
    let nonce = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
    let temporary = parent.join(format!(".folder-sorting-{}-{nonce}.tmp", std::process::id()));
    let result = (|| -> std::io::Result<()> {
        let mut output = fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(&temporary)?;
        output.write_all(&bytes)?;
        output.sync_all()?;
        fs::rename(&temporary, file)
    })();
    if result.is_err() { let _ = fs::remove_file(&temporary); }
    result.map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sparse_merge_validation_and_atomic_preservation() {
        let nonce = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
        let root = std::env::temp_dir().join(format!("seabunny-sort-{}-{nonce}", std::process::id()));
        fs::create_dir(&root).unwrap();
        let first = root.join("Pictures ö");
        let second = root.join("Other");
        fs::create_dir(&first).unwrap();
        fs::create_dir(&second).unwrap();
        let file = root.join("sorting.json");
        let custom = Sort { field: "modified".into(), ascending: false, folders: "last".into() };
        save(&file, &first, Sort::default()).unwrap();
        assert!(!file.exists());
        save(&file, &first, custom.clone()).unwrap();
        save(&file, &second, custom.clone()).unwrap();
        assert_eq!(load(&file).unwrap().folders.len(), 2);
        save(&file, &first, Sort::default()).unwrap();
        assert_eq!(get(&file, &first), Sort::default());
        assert_eq!(get(&file, &second), custom);
        assert_eq!(load(&file).unwrap().folders.len(), 1);
        let lock = fs::File::open(file.with_extension("lock")).unwrap();
        assert_eq!(unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) }, 0);
        assert!(save(&file, &first, custom.clone()).is_err());
        drop(lock);
        for contents in ["broken", r#"{"version":2,"folders":{}}"#,
            r#"{"version":1,"folders":{"/folder":{"field":"invalid","ascending":true,"folders":"mixed"}}}"#] {
            fs::write(&file, contents).unwrap();
            assert_eq!(get(&file, &first), Sort::default());
            assert!(save(&file, &first, custom.clone()).is_err());
            assert_eq!(fs::read_to_string(&file).unwrap(), contents);
        }
        let link = root.join("link.json");
        std::os::unix::fs::symlink(&file, &link).unwrap();
        assert!(save(&link, &first, custom).is_err());
        for path in [link, file, root.join("sorting.lock"), root.join("link.lock")] { fs::remove_file(path).unwrap(); }
        fs::remove_dir(first).unwrap();
        fs::remove_dir(second).unwrap();
        fs::remove_dir(root).unwrap();
    }
}
