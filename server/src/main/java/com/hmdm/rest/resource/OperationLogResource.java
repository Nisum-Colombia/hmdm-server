package com.hmdm.rest.resource;

import com.hmdm.persistence.OperationLogDAO;
import com.hmdm.rest.json.OperationLogEntry;
import com.hmdm.rest.json.PaginatedOperationLogResponse;
import com.hmdm.rest.json.Response;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import io.swagger.annotations.Authorization;

import javax.inject.Inject;
import javax.inject.Singleton;
import javax.ws.rs.DefaultValue;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
// import javax.ws.rs.core.Context; // Uncomment if SecurityContext is used
// import com.hmdm.security.SecurityContext; // Uncomment if SecurityContext is used
import java.util.List;

@Api(tags = {"OperationLog"}, authorizations = {@Authorization("Bearer Token")})
@Singleton
@Path("/private/operationlog")
public class OperationLogResource {

    private OperationLogDAO operationLogDAO;

    /**
     * A constructor required by Swagger.
     */
    public OperationLogResource() {
    }

    @Inject
    public OperationLogResource(OperationLogDAO operationLogDAO) {
        this.operationLogDAO = operationLogDAO;
    }

    @ApiOperation(
            value = "Get operation logs",
            notes = "Retrieves a paginated list of operation log entries, with optional filters.",
            response = PaginatedOperationLogResponse.class
    )
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response getOperationLogs(
            @QueryParam("dateFrom") Long dateFrom,
            @QueryParam("dateTo") Long dateTo,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @QueryParam("limit") @DefaultValue("20") int limit,
            @QueryParam("username") String username,
            @QueryParam("action") String action
            // @Context SecurityContext securityContext // Example if we need to filter by customer
    ) {
        // TODO: Determine if/how to get customerId from securityContext if needed.
        // For example, if the user is not a superadmin, filter by their customerId.
        // User currentUser = securityContext.getCurrentUser().orElse(null);
        // Integer customerIdFilter = (currentUser != null && !currentUser.isSuperAdmin()) ? currentUser.getCustomerId() : null;
        Integer customerIdFilter = null; // For now, no customer filtering from context

        List<OperationLogEntry> logs = operationLogDAO.getLogEntries(
                dateFrom, dateTo, offset, limit, username, action, customerIdFilter
        );
        long totalCount = operationLogDAO.countLogEntries(
                dateFrom, dateTo, username, action, customerIdFilter
        );

        PaginatedOperationLogResponse responsePayload = new PaginatedOperationLogResponse();
        responsePayload.setLogs(logs);
        responsePayload.setTotalCount(totalCount);

        return Response.OK(responsePayload);
    }
}
