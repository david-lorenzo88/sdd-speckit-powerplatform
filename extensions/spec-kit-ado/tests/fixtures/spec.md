# Feature Specification: Solicitudes de contacto

**Feature Branch**: `001-solicitudes-contacto`
**Created**: 2026-11-18
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar una solicitud de contacto (Priority: P1)

Un comercial rellena el formulario con los datos del cliente potencial y lo envía.

**Why this priority**: Es el valor principal de la funcionalidad.

**Independent Test**: Se puede probar enviando el formulario y comprobando la confirmación.

**Acceptance Scenarios**:

1. **Given** el formulario vacío, **When** el usuario envía sin email, **Then** se muestra un error de validación.
2. **Given** todos los campos válidos, **When** el usuario envía, **Then** la solicitud se guarda y se muestra una confirmación.

---

### User Story 2 - Notificar a preventa (Priority: P2)

Preventa recibe un email con los datos de cada nueva solicitud.

**Why this priority**: Sin aviso, nadie atiende la solicitud.

**Acceptance Scenarios**:

1. **Given** una solicitud guardada, **When** se crea el registro, **Then** preventa recibe un email con todos los datos.

---

## Requirements *(mandatory)*

- **FR-001**: El sistema DEBE validar los campos obligatorios.
