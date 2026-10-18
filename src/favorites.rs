use serde::{Deserialize, Serialize};
use std::{fs, io::{self, Write}, path::{Path, PathBuf}};

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct Favorite {
    pub path: String,
    pub label: String,
}

pub fn load(file: &Path) -> Result<Vec<Favorite>, String> {
    match fs::read(file) {
        Ok(bytes) => {
            let items: Vec<Favorite> = serde_json::from_slice(&bytes).map_err(|err| err.to_string())?;
            if items.iter().any(|item| !Path::new(&item.path).is_absolute() || item.label.trim().is_empty()) {
                return Err("Invalid favorites file; existing contents were preserved".into());
            }
            Ok(items)
        }
        Err(err) if err.kind() == io::ErrorKind::NotFound => Ok(Vec::new()),
        Err(err) => Err(err.to_string()),
    }
}

pub fn update(file: &Path, path: &str, label: Option<&str>) -> Result<(), String> {
    let mut items = load(file)?;
    let existing = items.iter().position(|item| item.path == path);
    match label {
        Some(label) => {
            let label = label.trim();
            if label.is_empty() || label.chars().any(char::is_control) {
                return Err("Enter a non-empty, single-line favorite name".into());
            }
            if let Some(index) = existing {
                items[index].label = label.into();
            } else {
                let canonical = fs::canonicalize(path).map_err(|err| format!("Cannot pin folder: {err}"))?;
                if !canonical.is_dir() { return Err("Only folders can be pinned".into()); }
                let canonical = canonical.to_str().ok_or("Folder path is not valid Unicode")?;
                if items.iter().any(|item| item.path == canonical) { return Ok(()); }
                items.push(Favorite { path: canonical.into(), label: label.into() });
            }
        }
        None => items.retain(|item| item.path != path),
    }
    publish(file, &items).map_err(|err| format!("Could not save favorites: {err}"))
}

fn publish(file: &Path, items: &[Favorite]) -> io::Result<()> {
    use std::os::unix::fs::OpenOptionsExt;
    let parent = file.parent().ok_or_else(|| io::Error::other("Missing favorites directory"))?;
    fs::create_dir_all(parent)?;
    let nonce = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
    let temporary: PathBuf = parent.join(format!(".favorites-{}-{nonce}.tmp", std::process::id()));
    let mut output = fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(&temporary)?;
    let result = (|| {
        output.write_all(&serde_json::to_vec_pretty(items)?)?;
        output.sync_all()?;
        fs::rename(&temporary, file)
    })();
    if result.is_err() { let _ = fs::remove_file(&temporary); }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn persistent_labels_duplicates_missing_paths_and_removal() {
        let root = std::env::temp_dir().join(format!("seabunny-favorites-{}-{}", std::process::id(), std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        fs::create_dir(&root).unwrap();
        let folder = root.join("Photos ö #");
        fs::create_dir(&folder).unwrap();
        let file = root.join("favorites.json");
        let path = folder.to_str().unwrap();
        update(&file, path, Some("Pictures")).unwrap();
        update(&file, &format!("{path}/."), Some("Duplicate")).unwrap();
        assert_eq!(load(&file).unwrap().len(), 1);
        update(&file, path, Some("Personal photos")).unwrap();
        assert_eq!(load(&file).unwrap()[0].label, "Personal photos");
        assert!(update(&file, path, Some("\n")).is_err());
        fs::remove_dir(&folder).unwrap();
        update(&file, path, Some("Offline photos")).unwrap();
        assert_eq!(load(&file).unwrap()[0].label, "Offline photos");
        update(&file, path, None).unwrap();
        assert!(load(&file).unwrap().is_empty());
        assert!(update(&file, path, Some("Missing")).is_err());
        fs::write(&file, "broken").unwrap();
        assert!(update(&file, path, None).is_err());
        assert_eq!(fs::read_to_string(&file).unwrap(), "broken");
        fs::remove_file(file).unwrap();
        fs::remove_dir(root).unwrap();
    }
}
