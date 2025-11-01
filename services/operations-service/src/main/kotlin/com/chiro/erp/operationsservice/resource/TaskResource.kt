package com.chiro.erp.operationsservice.resource

import com.chiro.erp.operationsservice.entity.Task
import com.chiro.erp.operationsservice.entity.TaskStatus
import com.chiro.erp.operationsservice.entity.TaskPriority
import com.chiro.erp.operationsservice.repository.TaskRepository
import io.quarkus.hibernate.reactive.panache.common.WithTransaction
import io.smallrye.mutiny.Uni
import jakarta.inject.Inject
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.time.LocalDateTime

@Path("/api/tasks")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class TaskResource {

    @Inject
    lateinit var taskRepository: TaskRepository

    @GET
    fun getAllTasks(): Uni<List<Task>> = taskRepository.listAll()

    @GET
    @Path("/{id}")
    fun getTask(@PathParam("id") id: Long): Uni<Response> {
        return taskRepository.findById(id)
            .onItem().transform { task ->
                if (task != null) {
                    Response.ok(task).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/status/{status}")
    fun getTasksByStatus(@PathParam("status") status: TaskStatus): Uni<List<Task>> =
        taskRepository.findByStatus(status)

    @GET
    @Path("/priority/{priority}")
    fun getTasksByPriority(@PathParam("priority") priority: TaskPriority): Uni<List<Task>> =
        taskRepository.findByPriority(priority)

    @GET
    @Path("/assignee/{assigneeId}")
    fun getTasksByAssignee(@PathParam("assigneeId") assigneeId: String): Uni<List<Task>> =
        taskRepository.findByAssigneeId(assigneeId)

    @GET
    @Path("/workflow/{workflowId}")
    fun getTasksByWorkflow(@PathParam("workflowId") workflowId: Long): Uni<List<Task>> =
        taskRepository.findByWorkflowId(workflowId)

    @GET
    @Path("/active")
    fun getActiveTasks(): Uni<List<Task>> = taskRepository.findActiveTasks()

    @GET
    @Path("/overdue")
    fun getOverdueTasks(): Uni<List<Task>> = taskRepository.findOverdueTasks()

    @POST
    @WithTransaction
    fun createTask(task: Task): Uni<Response> {
        task.createdAt = LocalDateTime.now()
        task.updatedAt = LocalDateTime.now()
        return taskRepository.persist(task)
            .onItem().transform { Response.status(Response.Status.CREATED).entity(it).build() }
    }

    @PUT
    @Path("/{id}")
    @WithTransaction
    fun updateTask(@PathParam("id") id: Long, task: Task): Uni<Response> {
        return taskRepository.findById(id)
            .onItem().transformToUni { existingTask ->
                if (existingTask != null) {
                    existingTask.title = task.title
                    existingTask.description = task.description
                    existingTask.status = task.status
                    existingTask.priority = task.priority
                    existingTask.assigneeId = task.assigneeId
                    existingTask.estimatedHours = task.estimatedHours
                    existingTask.actualHours = task.actualHours
                    existingTask.dueDate = task.dueDate
                    existingTask.updatedAt = LocalDateTime.now()
                    
                    // Update start/end dates based on status
                    if (task.status == TaskStatus.IN_PROGRESS && existingTask.startDate == null) {
                        existingTask.startDate = LocalDateTime.now()
                    }
                    if (task.status == TaskStatus.DONE && existingTask.endDate == null) {
                        existingTask.endDate = LocalDateTime.now()
                    }
                    
                    taskRepository.persist(existingTask)
                        .onItem().transform { Response.ok(it).build() }
                } else {
                    Uni.createFrom().item(Response.status(Response.Status.NOT_FOUND).build())
                }
            }
    }

    @DELETE
    @Path("/{id}")
    @WithTransaction
    fun deleteTask(@PathParam("id") id: Long): Uni<Response> {
        return taskRepository.deleteById(id)
            .onItem().transform { deleted ->
                if (deleted) {
                    Response.noContent().build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/search")
    fun searchTasks(@QueryParam("title") title: String?): Uni<List<Task>> {
        return if (!title.isNullOrBlank()) {
            taskRepository.searchByTitle(title)
        } else {
            taskRepository.listAll()
        }
    }
}
