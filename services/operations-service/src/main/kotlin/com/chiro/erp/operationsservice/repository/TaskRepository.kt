package com.chiro.erp.operationsservice.repository

import com.chiro.erp.operationsservice.entity.Task
import com.chiro.erp.operationsservice.entity.TaskStatus
import com.chiro.erp.operationsservice.entity.TaskPriority
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class TaskRepository : PanacheRepository<Task> {

    fun findByStatus(status: TaskStatus): Uni<List<Task>> =
        find("status", status).list()

    fun findByPriority(priority: TaskPriority): Uni<List<Task>> =
        find("priority", priority).list()

    fun findByAssigneeId(assigneeId: String): Uni<List<Task>> =
        find("assigneeId", assigneeId).list()

    fun findByWorkflowId(workflowId: Long): Uni<List<Task>> =
        find("workflowId", workflowId).list()

    fun findActiveTasks(): Uni<List<Task>> =
        find("status IN (?1, ?2, ?3)", TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.REVIEW).list()

    fun findOverdueTasks(): Uni<List<Task>> =
        find("status IN (?1, ?2, ?3) AND dueDate < NOW()", 
            TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.REVIEW).list()

    fun findByAssigneeAndStatus(assigneeId: String, status: TaskStatus): Uni<List<Task>> =
        find("assigneeId = ?1 AND status = ?2", assigneeId, status).list()

    fun searchByTitle(title: String): Uni<List<Task>> =
        find("LOWER(title) LIKE LOWER(?1)", "%$title%").list()
}
