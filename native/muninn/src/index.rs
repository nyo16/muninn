use rustler::{Env, ResourceArc};
use std::fs;
use std::path::Path;
use std::sync::{Arc, Mutex};
use tantivy::{Index, IndexWriter, TantivyDocument};

use crate::schema::{build_schema, SchemaDef};

/// Resource wrapper for Tantivy Index
/// We use Arc<Mutex<>> to ensure thread safety and RefUnwindSafe
/// The writer is lazily created and kept alive for the lifetime of the index
pub struct IndexResource {
    pub index: Arc<Mutex<Index>>,
    pub writer: Arc<Mutex<Option<IndexWriter<TantivyDocument>>>>,
}

/// Creates a new index at the specified path with the given schema
pub fn create_index(path: String, schema_def: SchemaDef) -> Result<ResourceArc<IndexResource>, String> {
    // Build the schema first
    let schema = build_schema(schema_def)?;

    // Create the directory if it doesn't exist
    let index_path = Path::new(&path);
    fs::create_dir_all(index_path)
        .map_err(|e| format!("Failed to create index directory: {}", e))?;

    // Create index
    let index = Index::create_in_dir(index_path, schema)
        .map_err(|e| format!("Failed to create index: {}", e))?;

    Ok(ResourceArc::new(IndexResource {
        index: Arc::new(Mutex::new(index)),
        writer: Arc::new(Mutex::new(None)),
    }))
}

/// Opens an existing index at the specified path
pub fn open_index(path: String) -> Result<ResourceArc<IndexResource>, String> {
    let index_path = Path::new(&path);

    let index = Index::open_in_dir(index_path)
        .map_err(|e| format!("Failed to open index: {}", e))?;

    Ok(ResourceArc::new(IndexResource {
        index: Arc::new(Mutex::new(index)),
        writer: Arc::new(Mutex::new(None)),
    }))
}

pub fn load(env: Env) -> bool {
    rustler::resource!(IndexResource, env);
    true
}
