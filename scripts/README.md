# Scripts Directory

This directory contains utility scripts for the Chiro ERP project.

## 📁 Available Scripts

### PowerShell Scripts

#### `create-complete-structure.ps1`
Creates the complete consolidated ERP structure with:
- 8 consolidated services
- 36 domain structures
- Hexagonal architecture layout
- SAP ERP pattern alignment

**Usage:**
```powershell
.\scripts\create-complete-structure.ps1
```

#### `consolidate-microservices.ps1`
Legacy consolidation script for migrating from original 30+ microservices structure.

**Usage:**
```powershell
.\scripts\consolidate-microservices.ps1
```

## 🚀 Quick Start

To set up the complete ERP structure:

```powershell
cd chiro-erp
.\scripts\create-complete-structure.ps1
```

This will create:
- All 8 consolidated services
- 36 domain directories with hexagonal architecture
- Placeholder files for rapid development start

## 📖 Related Documentation

- [Architecture Documentation](../docs/architecture/) - Detailed architecture information
- [Migration Documentation](../docs/migration/) - Migration strategies and plans
- [Templates](../templates/) - Build and structure templates
