//! Explicit recursive merge plans, using the same monitored transfer engine and
//! undo journal as ordinary operations. Existing directories are never replaced.
use crate::{core::UndoAction, fsops, trash, util};
use std::{collections::HashMap, fs, path::{Path, PathBuf}, os::unix::fs::PermissionsExt};

pub fn exists(path: &Path) -> bool { fs::symlink_metadata(path).is_ok() }
pub fn directory(path: &Path) -> bool { fs::symlink_metadata(path).is_ok_and(|m| m.is_dir()) }

pub fn scan(paths: &[PathBuf], destination: &Path) -> Result<Vec<serde_json::Value>, String> {
    fn visit(src: &Path, dst: &Path, root: &Path, out: &mut Vec<serde_json::Value>) -> Result<(), String> {
        if directory(src) && directory(dst) {
            if fsops::is_inside(dst, src) || fsops::is_inside(src, dst) { return Err("Cannot merge overlapping folders.".into()); }
            let mut entries = fs::read_dir(src).map_err(|e| e.to_string())?.collect::<Result<Vec<_>,_>>().map_err(|e| e.to_string())?;
            entries.sort_by_key(|entry| entry.file_name());
            for entry in entries { visit(&entry.path(), &dst.join(entry.file_name()), root, out)?; }
        } else if exists(dst) {
            let size = |path: &Path| fs::symlink_metadata(path).map(|m| if m.is_dir() { "Folder".into() } else { util::format_size(m.len()) }).unwrap_or_default();
            out.push(serde_json::json!({"name":src.strip_prefix(root).unwrap_or(src).to_string_lossy(),
                "src_path":src.to_string_lossy(),"dest_path":dst.to_string_lossy(),
                "src_size":size(src),"dest_size":size(dst),"is_dir":directory(dst),"src_is_dir":directory(src)}));
        }
        Ok(())
    }
    let mut out = Vec::new();
    for source in paths {
        let name = source.file_name().ok_or("Invalid source name")?;
        visit(source, &destination.join(name), source.parent().unwrap_or(source), &mut out)?;
    }
    Ok(out)
}

fn collision(src: &Path, dst: &Path, choices: &HashMap<String,String>, actions: &mut Vec<UndoAction>) -> Result<Option<PathBuf>, String> {
    if !exists(src) { return Err("The incoming file is no longer available. The existing file was kept.".into()); }
    match choices.get(&src.to_string_lossy().to_string()).map(String::as_str) {
        Some("keep_existing") => Ok(None),
        Some("keep_both") => Ok(Some(fsops::unique_name(dst.parent().unwrap(), &dst.file_name().unwrap().to_string_lossy()))),
        Some("replace") => {
            let old = trash::trash(dst).map_err(|e| format!("Could not preserve {}: {e}", dst.display()))?;
            actions.push(UndoAction::Trash(vec![old]));
            Ok(Some(dst.into()))
        }
        _ => Err(format!("A new conflict appeared at {}. Paste again to choose what to keep.", dst.display())),
    }
}

pub(crate) fn transfer(src: &Path, dst: &Path, cut: bool, choices: &HashMap<String,String>, actions: &mut Vec<UndoAction>, mon: &dyn fsops::Monitor) -> Result<(), String> {
    if mon.cancelled() { return Err("Cancelled".into()); }
    if fsops::is_inside(dst, src) || (directory(src) && directory(dst) && fsops::is_inside(src, dst)) {
        return Err("Cannot merge a folder with itself, a parent or a subfolder.".into());
    }
    if directory(src) && directory(dst) { return contents(src, dst, cut, choices, actions, mon); }
    let target = if exists(dst) { match collision(src, dst, choices, actions)? { Some(path) => path, None => return Ok(()) } } else { dst.into() };
    // Record each directory entry of cross-device moves. A partial deletion of
    // the source must not leave already-moved children outside the undo journal.
    if cut && directory(src) {
        if fsops::rename_noreplace(src, &target).is_ok() {
            actions.push(UndoAction::Move(vec![(src.into(),target)])); return Ok(());
        }
        let mode = fs::metadata(src).map_err(|e|e.to_string())?.permissions().mode();
        fs::create_dir(&target).map_err(|e|e.to_string())?;
        actions.push(UndoAction::MadeDirectory(target.clone(), mode));
        let result = contents(src, &target, true, choices, actions, mon);
        let permissions = fs::set_permissions(&target, fs::Permissions::from_mode(mode)).map_err(|e|e.to_string());
        return result.and(permissions);
    }
    if cut { fsops::move_path(src, &target, mon) } else { fsops::copy_tree(src, &target, mon) }
        .map_err(|e| format!("{}: {e}", src.display()))?;
    let pair = vec![(src.into(),target)];
    actions.push(if cut { UndoAction::Move(pair) } else { UndoAction::Copy(pair) });
    Ok(())
}

fn contents(src: &Path, dst: &Path, cut: bool, choices: &HashMap<String,String>, actions: &mut Vec<UndoAction>, mon: &dyn fsops::Monitor) -> Result<(), String> {
    let mode = fs::metadata(src).map_err(|e|e.to_string())?.permissions().mode();
    let entries = fs::read_dir(src).map_err(|e|e.to_string())?.collect::<Result<Vec<_>,_>>().map_err(|e|e.to_string())?;
    let mut errors = Vec::new();
    for entry in entries {
        if mon.cancelled() { errors.push("Cancelled".into()); break; }
        if let Err(error) = transfer(&entry.path(), &dst.join(entry.file_name()), cut, choices, actions, mon) { errors.push(error); }
    }
    if cut && errors.is_empty() && fs::read_dir(src).is_ok_and(|mut entries| entries.next().is_none()) {
        fs::remove_dir(src).map_err(|e|e.to_string())?;
        actions.push(UndoAction::RemovedDirectory(src.into(), mode));
    }
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}
