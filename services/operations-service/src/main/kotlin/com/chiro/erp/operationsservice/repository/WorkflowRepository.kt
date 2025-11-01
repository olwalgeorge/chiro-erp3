package com.chiro.erp.operationsservice.repository

import com.chiro.erp.operationsservice.entity.Workflow
import com.chiro.erp.operationsservice.entity.WorkflowStatus
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class WorkflowRepository : PanacheRepository<Workflow> {
    fun findByWorkflowName(workflowName: String): Uni<Workflow?> = find("workflowName", workflowName).firstResult()

    fun findByStatus(status: WorkflowStatus): Uni<List<Workflow>> = find("status", status).list()

    fun findByOwnerId(ownerId: String): Uni<List<Workflow>> = find("ownerId", ownerId).list()

    fun findByPriority(priority: Int): Uni<List<Workflow>> = find("priority", priority).list()

    fun findActiveWorkflows(): Uni<List<Workflow>> =
        find("status IN (?1, ?2)", WorkflowStatus.PENDING, WorkflowStatus.IN_PROGRESS).list()

    fun findOverdueWorkflows(): Uni<List<Workflow>> =
        find(
            "status IN (?1, ?2) AND dueDate < NOW()",
            WorkflowStatus.PENDING,
            WorkflowStatus.IN_PROGRESS,
        ).list()

    fun searchByDescription(description: String): Uni<List<Workflow>> =
        find("LOWER(description) LIKE LOWER(?1)", "%$description%").list()
}
