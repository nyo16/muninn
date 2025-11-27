use rustler::{Env, ResourceArc};
use tantivy::schema::{NumericOptions, Schema, SchemaBuilder, TextFieldIndexing, TextOptions};

/// Resource wrapper for Tantivy Schema
pub struct SchemaResource {
    pub schema: Schema,
}

/// Field definition from Elixir - Using tuple (name, type, stored, indexed)
pub type FieldDef = (String, String, bool, bool);

/// Schema definition from Elixir - Using list of field definitions
pub type SchemaDef = Vec<FieldDef>;

/// Creates a Tantivy schema from the Elixir schema definition
pub fn build_schema(schema_def: SchemaDef) -> Result<Schema, String> {
    let mut schema_builder = SchemaBuilder::new();

    for (name, field_type, stored, indexed) in schema_def {
        match field_type.as_str() {
            "text" => {
                let mut text_options = TextOptions::default();

                if stored {
                    text_options = text_options.set_stored();
                }

                if indexed {
                    let indexing = TextFieldIndexing::default()
                        .set_tokenizer("default")
                        .set_index_option(
                            tantivy::schema::IndexRecordOption::WithFreqsAndPositions,
                        );
                    text_options = text_options.set_indexing_options(indexing);
                }

                schema_builder.add_text_field(&name, text_options);
            }
            "u64" | "i64" | "f64" => {
                let mut numeric_options = NumericOptions::default();

                if stored {
                    numeric_options = numeric_options.set_stored();
                }

                if indexed {
                    numeric_options = numeric_options.set_indexed();
                }

                match field_type.as_str() {
                    "u64" => schema_builder.add_u64_field(&name, numeric_options),
                    "i64" => schema_builder.add_i64_field(&name, numeric_options),
                    "f64" => schema_builder.add_f64_field(&name, numeric_options),
                    _ => unreachable!(),
                };
            }
            "bool" => {
                let mut bool_options = NumericOptions::default();

                if stored {
                    bool_options = bool_options.set_stored();
                }

                if indexed {
                    bool_options = bool_options.set_indexed();
                }

                schema_builder.add_bool_field(&name, bool_options);
            }
            _ => {
                return Err(format!("Unsupported field type: {}", field_type));
            }
        }
    }

    let schema = schema_builder.build();
    Ok(schema)
}

/// Builds a schema resource from definition
pub fn schema_build(schema_def: SchemaDef) -> Result<ResourceArc<SchemaResource>, rustler::Error> {
    let schema = build_schema(schema_def).map_err(|e| rustler::Error::Term(Box::new(e)))?;
    Ok(ResourceArc::new(SchemaResource { schema }))
}

pub fn load(env: Env) -> bool {
    rustler::resource!(SchemaResource, env);
    true
}
