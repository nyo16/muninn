use rustler::{Env, ResourceArc, Term};
use std::collections::HashMap;
use tantivy::schema::FieldType;
use tantivy::{TantivyDocument, Term as TantivyTerm};

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
                FieldType::Bytes(_) => {
                    if let Ok(bin) = value.decode::<rustler::Binary>() {
                        tantivy_doc.add_bytes(field, bin.as_slice());
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

/// Deletes all documents containing the given term (field+value pair).
///
/// Tantivy marks matching documents as deleted; the delete becomes visible
/// to readers after the next `commit`. Supports text, u64, i64, and bool
/// fields. f64 fields are not supported because Tantivy does not provide a
/// stable term encoding for floats.
pub fn writer_delete_term(
    index_res: ResourceArc<IndexResource>,
    field_name: String,
    value: Term,
) -> Result<(), String> {
    let index = index_res
        .index
        .lock()
        .map_err(|_| "Failed to acquire index lock".to_string())?;

    let schema = index.schema();
    let field = schema
        .get_field(&field_name)
        .map_err(|_| format!("Field '{}' not found in schema", field_name))?;
    let field_entry = schema.get_field_entry(field);

    let term = match field_entry.field_type() {
        FieldType::Str(_) => {
            let s = value
                .decode::<String>()
                .map_err(|_| "Expected string value for text field".to_string())?;
            TantivyTerm::from_field_text(field, &s)
        }
        FieldType::U64(_) => {
            let n = value
                .decode::<u64>()
                .or_else(|_| value.decode::<i64>().map(|i| i as u64))
                .map_err(|_| "Expected integer value for u64 field".to_string())?;
            TantivyTerm::from_field_u64(field, n)
        }
        FieldType::I64(_) => {
            let n = value
                .decode::<i64>()
                .or_else(|_| value.decode::<u64>().map(|u| u as i64))
                .map_err(|_| "Expected integer value for i64 field".to_string())?;
            TantivyTerm::from_field_i64(field, n)
        }
        FieldType::Bool(_) => {
            let b = value
                .decode::<bool>()
                .map_err(|_| "Expected boolean value for bool field".to_string())?;
            TantivyTerm::from_field_bool(field, b)
        }
        _ => {
            return Err(format!(
                "Field '{}' has unsupported type for delete_term (text, u64, i64, bool only)",
                field_name
            ));
        }
    };

    drop(index);

    let mut writer_lock = index_res
        .writer
        .lock()
        .map_err(|_| "Failed to acquire writer lock".to_string())?;

    if writer_lock.is_none() {
        let index = index_res
            .index
            .lock()
            .map_err(|_| "Failed to acquire index lock".to_string())?;
        let new_writer = index
            .writer(50_000_000)
            .map_err(|e| format!("Failed to create writer: {}", e))?;
        *writer_lock = Some(new_writer);
    }

    let writer = writer_lock.as_mut().unwrap();
    writer.delete_term(term);

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
