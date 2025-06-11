package com.hmdm.persistence;

import com.hmdm.rest.json.OperationLogEntry;
import java.util.List;

public interface OperationLogDAO {

    /**
     * Retrieves a paginated list of operation log entries based on the provided filters.
     * SQL: SELECT * FROM operation_logs
     *      WHERE (?dateFrom IS NULL OR timestamp >= ?dateFrom)
     *      AND (?dateTo IS NULL OR timestamp <= ?dateTo)
     *      AND (?usernameFilter IS NULL OR username = ?usernameFilter)
     *      AND (?actionFilter IS NULL OR action = ?actionFilter)
     *      AND (?customerIdFilter IS NULL OR customer_id = ?customerIdFilter)
     *      ORDER BY timestamp DESC LIMIT ?limit OFFSET ?offset;
     * (Note: Actual SQL might use dynamic query building for optional filters)
     *
     * @param dateFrom Optional start timestamp for filtering.
     * @param dateTo Optional end timestamp for filtering.
     * @param offset Number of records to skip for pagination.
     * @param limit Maximum number of records to return.
     * @param usernameFilter Optional filter by username.
     * @param actionFilter Optional filter by action.
     * @param customerIdFilter Optional filter by customer ID.
     * @return A list of OperationLogEntry objects.
     */
    List<OperationLogEntry> getLogEntries(Long dateFrom, Long dateTo,
                                          Integer offset, Integer limit,
                                          String usernameFilter, String actionFilter,
                                          Integer customerIdFilter);

    /**
     * Counts the total number of operation log entries based on the provided filters.
     * SQL: SELECT COUNT(*) FROM operation_logs
     *      WHERE (?dateFrom IS NULL OR timestamp >= ?dateFrom)
     *      AND (?dateTo IS NULL OR timestamp <= ?dateTo)
     *      AND (?usernameFilter IS NULL OR username = ?usernameFilter)
     *      AND (?actionFilter IS NULL OR action = ?actionFilter)
     *      AND (?customerIdFilter IS NULL OR customer_id = ?customerIdFilter);
     * (Note: Actual SQL might use dynamic query building for optional filters)
     *
     * @param dateFrom Optional start timestamp for filtering.
     * @param dateTo Optional end timestamp for filtering.
     * @param usernameFilter Optional filter by username.
     * @param actionFilter Optional filter by action.
     * @param customerIdFilter Optional filter by customer ID.
     * @return The total count of matching log entries.
     */
    long countLogEntries(Long dateFrom, Long dateTo,
                         String usernameFilter, String actionFilter,
                         Integer customerIdFilter);
}
