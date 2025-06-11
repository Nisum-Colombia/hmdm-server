package com.hmdm.rest.json;

import java.util.List;
// import com.hmdm.rest.json.OperationLogEntry; // This will be resolved by the compiler if in the same package

public class PaginatedOperationLogResponse {
    private List<OperationLogEntry> logs;
    private long totalCount;

    // Getters and Setters
    public List<OperationLogEntry> getLogs() {
        return logs;
    }

    public void setLogs(List<OperationLogEntry> logs) {
        this.logs = logs;
    }

    public long getTotalCount() {
        return totalCount;
    }

    public void setTotalCount(long totalCount) {
        this.totalCount = totalCount;
    }
}
