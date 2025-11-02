package com.chiro.erp.supplychainmanufacturing

import io.quarkus.runtime.Quarkus
import io.quarkus.runtime.QuarkusApplication
import io.quarkus.runtime.annotations.QuarkusMain

@QuarkusMain
class SupplyChainManufacturingApplication : QuarkusApplication {
    override fun run(vararg args: String?): Int {
        Quarkus.waitForExit()
        return 0
    }
}

fun main(args: Array<String>) {
    Quarkus.run(SupplyChainManufacturingApplication::class.java, *args)
}
