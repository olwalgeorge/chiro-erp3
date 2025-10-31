# Chiro ERP Documentation

This directory contains comprehensive documentation for the Chiro ERP system, organized into logical sections for easy navigation.

## 📁 Directory Structure

### `/architecture`
Contains architectural documentation and design decisions:
- **ARCHITECTURE-SUMMARY.md** - Complete enterprise architecture overview
- **BOUNDED-CONTEXTS.md** - Domain-driven design bounded contexts
- **CONTEXT-MAPPING.md** - Context mapping between domains
- **README-consolidated.md** - Consolidated architecture overview

### `/migration`
Contains migration and consolidation documentation:
- **microservice-consolidation-plan.md** - Plan for consolidating 30+ microservices to 8
- **consolidation-comparison.md** - Before/after comparison analysis
- **CONSOLIDATED-IMPLEMENTATION-STRATEGY.md** - Implementation strategy and roadmap
- **service-migration-mapping.md** - Mapping of original services to new consolidated structure

## 🏗️ Architecture Overview

The Chiro ERP system follows a **consolidated microservices architecture** with:
- **8 Consolidated Services** (down from 30+ microservices)
- **36 Domain Structures** following Hexagonal Architecture
- **SAP ERP Patterns** (FI, MM, CO modules)
- **Enterprise-Grade Security & Resilience**

## 🚀 Key Benefits

- **75% reduction in operational complexity**
- **Unified monitoring and troubleshooting**
- **Single customer view across all touchpoints**
- **World-class ERP capabilities**

## 📖 Getting Started

1. Start with [ARCHITECTURE-SUMMARY.md](architecture/ARCHITECTURE-SUMMARY.md) for system overview
2. Review [microservice-consolidation-plan.md](migration/microservice-consolidation-plan.md) for consolidation approach
3. Check [CONSOLIDATED-IMPLEMENTATION-STRATEGY.md](migration/CONSOLIDATED-IMPLEMENTATION-STRATEGY.md) for implementation guidance

## 🔗 Related Resources

- [Main README](../README.md) - Project overview and getting started
- [Scripts](../scripts/) - PowerShell scripts for project setup
- [Templates](../templates/) - Build templates and structure templates
