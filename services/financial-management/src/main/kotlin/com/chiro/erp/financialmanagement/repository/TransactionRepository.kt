package com.chiro.erp.financialmanagement.repository

import com.chiro.erp.financialmanagement.entity.Transaction
import com.chiro.erp.financialmanagement.entity.TransactionStatus
import com.chiro.erp.financialmanagement.entity.TransactionType
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class TransactionRepository : PanacheRepository<Transaction> {
    fun findByTransactionNumber(transactionNumber: String): Uni<Transaction?> =
        find("transactionNumber", transactionNumber).firstResult()

    fun findByAccountId(accountId: String): Uni<List<Transaction>> = find("accountId", accountId).list()

    fun findByStatus(status: TransactionStatus): Uni<List<Transaction>> = find("status", status).list()

    fun findByType(type: TransactionType): Uni<List<Transaction>> = find("type", type).list()

    fun findByAccountIdAndType(
        accountId: String,
        type: TransactionType,
    ): Uni<List<Transaction>> = find("accountId = ?1 AND type = ?2", accountId, type).list()

    fun searchByDescription(description: String): Uni<List<Transaction>> =
        find("LOWER(description) LIKE LOWER(?1)", "%$description%").list()
}
