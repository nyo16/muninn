use rustler::{Env, ResourceArc};
use std::panic::RefUnwindSafe;
use tantivy::IndexReader;

use crate::index::IndexResource;

/// Resource wrapper for Tantivy IndexReader
pub struct ReaderResource {
    pub reader: IndexReader,
}

unsafe impl Send for ReaderResource {}
unsafe impl Sync for ReaderResource {}
impl RefUnwindSafe for ReaderResource {}

/// Creates a new IndexReader for the given index
pub fn reader_new(index_res: ResourceArc<IndexResource>) -> Result<ResourceArc<ReaderResource>, String> {
    let index = index_res
        .index
        .lock()
        .map_err(|_| "Failed to acquire index lock".to_string())?;

    let reader = index
        .reader()
        .map_err(|e| format!("Failed to create reader: {}", e))?;

    Ok(ResourceArc::new(ReaderResource { reader }))
}

pub fn load(env: Env) -> bool {
    rustler::resource!(ReaderResource, env);
    true
}
