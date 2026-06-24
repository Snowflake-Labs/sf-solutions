"""
Parallel query execution utilities for improved dashboard performance.

This module provides ThreadPoolExecutor-based parallel query execution
to significantly reduce dashboard load times when multiple independent
queries need to be executed.
"""

from concurrent.futures import ThreadPoolExecutor, as_completed
import pandas as pd
import logging
import time
from typing import Dict, Any

# Database/schema prefix for fully qualified table names
# Used across all Streamlit pages for consistent table references
DB_SCHEMA = "SF_SOLUTIONS.GNN_SUPPLY_CHAIN_RISK"

# Configure logging
logger = logging.getLogger(__name__)


def run_queries_parallel(
    session,
    queries: Dict[str, str],
    max_workers: int = 4,
    return_empty_on_error: bool = True
) -> Dict[str, pd.DataFrame]:
    """
    Execute multiple independent SQL queries in parallel using ThreadPoolExecutor.
    
    This function significantly improves load times when you have multiple
    independent queries that don't depend on each other's results. Instead of
    waiting for each query to complete sequentially (total time = sum of all
    query times), queries run concurrently (total time = slowest query time).
    
    Args:
        session: Snowflake Snowpark session object
        queries: Dictionary mapping query names to SQL query strings
                 Example: {'vendors': 'SELECT COUNT(*) FROM VENDORS', 
                          'materials': 'SELECT COUNT(*) FROM MATERIALS'}
        max_workers: Maximum number of concurrent query threads (default: 4)
                    Recommended: 4 for Snowflake free tier, 8-10 for enterprise
        return_empty_on_error: If True, return empty DataFrame on query failure
                               If False, propagate the exception
    
    Returns:
        Dictionary mapping query names to pandas DataFrames with results
        
    Example:
        >>> queries = {
        ...     'vendor_count': 'SELECT COUNT(*) as CNT FROM VENDORS',
        ...     'material_count': 'SELECT COUNT(*) as CNT FROM MATERIALS',
        ...     'risk_count': 'SELECT COUNT(*) as CNT FROM RISK_SCORES'
        ... }
        >>> results = run_queries_parallel(session, queries, max_workers=3)
        >>> vendor_count = results['vendor_count']['CNT'].iloc[0]
    
    Performance:
        - Before: 3 queries x 1.5s each = 4.5s total
        - After:  3 queries in parallel = 1.5s total (time of slowest query)
        - Improvement: ~67% faster
    
    Thread Safety:
        Snowflake Snowpark sessions support concurrent cursor execution.
        Each thread gets its own cursor from the session's connection.
    """
    
    if not queries:
        return {}
    
    start_time = time.time()
    results: Dict[str, pd.DataFrame] = {}
    
    def execute_query(name: str, query: str) -> tuple:
        """Execute a single query and return (name, result_df)."""
        query_start = time.time()
        try:
            df = session.sql(query).to_pandas()
            elapsed = time.time() - query_start
            logger.debug(f"Query '{name}' completed in {elapsed:.2f}s: {len(df)} rows")
            return name, df
        except Exception as e:
            elapsed = time.time() - query_start
            logger.error(f"Query '{name}' failed after {elapsed:.2f}s: {e}")
            if return_empty_on_error:
                return name, pd.DataFrame()
            else:
                raise
    
    # Execute queries in parallel
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all queries
        future_to_name = {
            executor.submit(execute_query, name, query): name
            for name, query in queries.items()
        }
        
        # Collect results as they complete
        for future in as_completed(future_to_name):
            name = future_to_name[future]
            try:
                query_name, result_df = future.result()
                results[query_name] = result_df
            except Exception as e:
                logger.error(f"Failed to get result for '{name}': {e}")
                if return_empty_on_error:
                    results[name] = pd.DataFrame()
                else:
                    raise
    
    total_elapsed = time.time() - start_time
    logger.info(f"Parallel query execution completed in {total_elapsed:.2f}s for {len(queries)} queries")
    
    return results


def run_query_safe(session, query: str, default_value: Any = None) -> Any:
    """
    Execute a single query with error handling, returning a default value on failure.
    
    Useful for simple COUNT or scalar queries where you want a fallback value.
    
    Args:
        session: Snowflake Snowpark session
        query: SQL query string
        default_value: Value to return if query fails
        
    Returns:
        Query result DataFrame, or default_value on error
    """
    try:
        return session.sql(query).to_pandas()
    except Exception as e:
        logger.warning(f"Query failed, returning default: {e}")
        return default_value

