use rustler::{Env, ResourceArc, Term};
use std::collections::HashMap;
use tantivy::schema::FieldType;
use tantivy::TantivyDocument;

use crate::index::IndexResource;

/// Adds a document to the index
pub fn writer_add_document(
    index_res: ResourceArc<IndexResource>,
    document: Term,
) -> Result<(), String> {
    // Decode the document map from Elixir
    let doc_map: HashMap<String, Term> = document
        .decode()
        .map_err(|_| "Failed to decode document: expected a map".to_string())?;

    let index = index_res
        .index
        .lock()
        .map_err(|_| "Failed to acquire index lock".to_string())?;

    let schema = index.schema();
    let mut tantivy_doc = TantivyDocument::default();

    // Convert Elixir map to Tantivy document
    for (field_name, value) in doc_map {
        if let Ok(field) = schema.get_field(&field_name) {
            let field_entry = schema.get_field_entry(field);

            match field_entry.field_type() {
                FieldType::Str(_) => {
                    if let Ok(string_val) = value.decode::<String>() {
                        tantivy_doc.add_text(field, &string_val);
                    }
                }
                FieldType::U64(_) => {
                    // Try u64 first, then i64 (if positive)
                    if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_u64(field, int_val);
                    } else if let Ok(int_val) = value.decode::<i64>() {
                        if int_val >= 0 {
                            tantivy_doc.add_u64(field, int_val as u64);
                        }
                    }
                }
                FieldType::I64(_) => {
                    if let Ok(int_val) = value.decode::<i64>() {
                        tantivy_doc.add_i64(field, int_val);
                    } else if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_i64(field, int_val as i64);
                    }
                }
                FieldType::F64(_) => {
                    // Try f64, then fall back to integers
                    if let Ok(float_val) = value.decode::<f64>() {
                        tantivy_doc.add_f64(field, float_val);
                    } else if let Ok(int_val) = value.decode::<i64>() {
                        tantivy_doc.add_f64(field, int_val as f64);
                    } else if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_f64(field, int_val as f64);
                    }
                }
                FieldType::Bool(_) => {
                    if let Ok(bool_val) = value.decode::<bool>() {
                        tantivy_doc.add_bool(field, bool_val);
                    }
                }
                _ => {
                    // Unsupported field type, skip
                }
            }
        }
    }

    // Get or create the persistent writer
    let mut writer_lock = index_res
        .writer
        .lock()
        .map_err(|_| "Failed to acquire writer lock".to_string())?;

    // Initialize writer if it doesn't exist
    if writer_lock.is_none() {
        let new_writer = index
            .writer(50_000_000)
            .map_err(|e| format!("Failed to create writer: {}", e))?;
        *writer_lock = Some(new_writer);
    }

    let writer = writer_lock.as_mut().unwrap();

    writer
        .add_document(tantivy_doc)
        .map_err(|e| format!("Failed to add document: {}", e))?;

    Ok(())
}

/// Commits all pending changes to the index
pub fn writer_commit(index_res: ResourceArc<IndexResource>) -> Result<(), String> {
    let mut writer_lock = index_res
        .writer
        .lock()
        .map_err(|_| "Failed to acquire writer lock".to_string())?;

    if let Some(writer) = writer_lock.as_mut() {
        writer
            .commit()
            .map_err(|e| format!("Failed to commit: {}", e))?;
    }

    Ok(())
}

/// Rolls back all uncommitted changes
pub fn writer_rollback(index_res: ResourceArc<IndexResource>) -> Result<(), String> {
    let mut writer_lock = index_res
        .writer
        .lock()
        .map_err(|_| "Failed to acquire writer lock".to_string())?;

    if let Some(writer) = writer_lock.as_mut() {
        writer
            .rollback()
            .map_err(|e| format!("Failed to rollback: {}", e))?;
    }

    Ok(())
}

pub fn load(_env: Env) -> bool {
    true
}
