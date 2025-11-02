#!/usr/bin/env pwsh

# Script to add Kafka messaging test endpoints to all services

$services = @{
    "commerce"                   = "commerce"
    "customer-relationship"      = "customerrelationship"
    "financial-management"       = "financialmanagement"
    "operations-service"         = "operationsservice"
    "supply-chain-manufacturing" = "supplychainmanufacturing"
}

foreach ($service in $services.Keys) {
    $packageName = $services[$service]
    $serviceFriendlyName = (Get-Culture).TextInfo.ToTitleCase(($service -replace "-", " "))

    Write-Host "Adding Kafka messaging to $service..." -ForegroundColor Cyan

    # Add Kafka messaging configuration to application.properties
    $propsFile = "services/$service/src/main/resources/application.properties"

    $kafkaConfig = @"

# Kafka Reactive Messaging Channels
mp.messaging.outgoing.$service-events-out.connector=smallrye-kafka
mp.messaging.outgoing.$service-events-out.topic=$service-events
mp.messaging.outgoing.$service-events-out.value.serializer=org.apache.kafka.common.serialization.StringSerializer

mp.messaging.incoming.$service-events-in.connector=smallrye-kafka
mp.messaging.incoming.$service-events-in.topic=$service-events
mp.messaging.incoming.$service-events-in.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
mp.messaging.incoming.$service-events-in.group.id=$service-group

mp.messaging.incoming.shared-events.connector=smallrye-kafka
mp.messaging.incoming.shared-events.topic=shared-events
mp.messaging.incoming.shared-events.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
mp.messaging.incoming.shared-events.group.id=$service-shared-group
"@

    # Read current content
    $content = Get-Content $propsFile -Raw

    # Add Kafka config before Security Configuration if not already present
    if (-not ($content -match "mp.messaging.outgoing")) {
        $content = $content -replace "(# Security Configuration)", "$kafkaConfig`n`n`$1"
        $content | Out-File -FilePath $propsFile -Encoding UTF8 -NoNewline
        Write-Host "  ✅ Added Kafka configuration to $service" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠️  Kafka configuration already exists in $service" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Kafka messaging configuration complete!" -ForegroundColor Green
