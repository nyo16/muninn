use rustler::ResourceArc;
use tantivy::aggregation::agg_req::Aggregations;
use tantivy::aggregation::{AggContextParams, AggregationCollector};
use tantivy::query::{AllQuery, QueryParser};

use crate::searcher::SearcherResource;

/// Executes aggregations over documents matching a query.
/// Takes a JSON string for the aggregation request, returns a JSON string for results.
pub fn searcher_aggregate(
    searcher_res: ResourceArc<SearcherResource>,
    query_string: String,
    default_fields: Vec<String>,
    aggs_json: String,
) -> Result<String, String> {
    let searcher = &searcher_res.searcher;
    let schema = searcher.index().schema();

    // Parse the query - special case "*" as AllQuery
    let query: Box<dyn tantivy::query::Query> = if query_string == "*" {
        Box::new(AllQuery)
    } else {
        let mut fields = Vec::new();
        for field_name in &default_fields {
            let field = schema
                .get_field(field_name)
                .map_err(|_| format!("Field '{}' not found in schema", field_name))?;
            fields.push(field);
        }

        if fields.is_empty() {
            return Err("At least one default field must be provided".to_string());
        }

        let query_parser = QueryParser::for_index(searcher.index(), fields);
        query_parser
            .parse_query(&query_string)
            .map_err(|e| format!("Failed to parse query '{}': {}", query_string, e))?
    };

    // Parse the aggregation request from JSON
    let agg_req: Aggregations = serde_json::from_str(&aggs_json)
        .map_err(|e| format!("Failed to parse aggregation request: {}", e))?;

    // Create collector and execute
    let context = AggContextParams::default();
    let collector = AggregationCollector::from_aggs(agg_req, context);

    let agg_result = searcher
        .search(&*query, &collector)
        .map_err(|e| format!("Aggregation failed: {}", e))?;

    // Serialize result to JSON
    serde_json::to_string(&agg_result)
        .map_err(|e| format!("Failed to serialize aggregation result: {}", e))
}
