# Spec Driven Development con SpecKit en Power Platform

Material del taller **"Spec Driven Development con SpecKit en proyectos de Power Platform"** de David Lorenzo López (AI Architect @ Prodware · Microsoft MVP).

Con este repositorio puedes hacer tú mismo la demo completa de la sesión. Partes de una idea, escribes una especificación con [SpecKit](https://github.com/github/spec-kit) y GitHub Copilot implementa un proyecto real de Power Platform:

```
Usuario ──▶ Code App (React + TS) ──▶ Dataverse ──▶ Power Automate ──▶ Email a preventa
            └──────── todo dentro de la solución SolicitudesContacto (publisher ppn) ────────┘
```

## Empieza aquí

Sigue los documentos en orden:

| # | Documento | Qué haces | Tiempo |
|---|---|---|---|
| 1 | [Prerrequisitos](docs/01-prerequisitos.md) | Instalas y compruebas todas las herramientas (Windows) | 30–45 min |
| 2 | [Entorno de Power Platform](docs/02-entorno-power-platform.md) | Preparas el entorno de desarrollo y habilitas Code Apps | 10–15 min |
| 3 | [Demo paso a paso](docs/03-demo-paso-a-paso.md) | Haces el ciclo SDD completo con los prompts de `prompts/` | 60–90 min |
| 4 | [Azure Boards (opcional)](docs/04-azure-boards.md) | Sigues el avance en Azure DevOps con la extensión `ado` | 15 min |
| 5 | [Validación con Copilot (opcional)](docs/05-validacion-con-copilot.md) | Ensayas la demo con Copilot como validador, que genera un informe | — |

Inicio rápido de los prerrequisitos:

```powershell
cd C:\demos
git clone https://github.com/david-lorenzo88/sdd-speckit-powerplatform.git
cd sdd-speckit-powerplatform
powershell -ExecutionPolicy Bypass -File .\scripts\Install-Prerequisites.ps1
# abre una terminal nueva de PowerShell 7 y comprueba:
pwsh -File .\scripts\Test-Prerequisites.ps1
```

## Contenido

```
├─ docs/
│  ├─ SDD_SpecKit_PowerPlatform.pptx   presentación de la sesión
│  ├─ 01-prerequisitos.md              instalación paso a paso
│  ├─ 02-entorno-power-platform.md     entorno, Code Apps, URL e ID
│  ├─ 03-demo-paso-a-paso.md           la demo, paso a paso
│  ├─ 04-azure-boards.md               seguimiento en Azure Boards
│  └─ 05-validacion-con-copilot.md     ensayo con informe de validación
├─ prompts/                            prompts de cada paso, listos para copiar
├─ scripts/
│  ├─ Install-Prerequisites.ps1        instala lo que falte (admite -WhatIf)
│  └─ Test-Prerequisites.ps1           comprueba versiones y sesiones
└─ extensions/
   └─ spec-kit-ado/                    extensión de SpecKit para Azure Boards
```

## El ciclo SDD con SpecKit

| Paso | Comando | Genera |
|---|---|---|
| Principios | `/speckit-constitution` | `.specify/memory/constitution.md` |
| Qué y por qué | `/speckit-specify` | `specs/NNN-…/spec.md` |
| Resolver dudas | `/speckit-clarify` | aclaraciones en `spec.md` |
| Cómo | `/speckit-plan` | `plan.md`, `research.md`, `data-model.md`, `quickstart.md` |
| Calidad de requisitos | `/speckit-checklist` | `checklists/…` |
| Desglose | `/speckit-tasks` | `tasks.md` |
| Coherencia | `/speckit-analyze` | informe (solo lectura) |
| Ejecutar | `/speckit-implement` | código y artefactos |
| Cerrar huecos | `/speckit-converge` | tareas nuevas hasta "Converged" |

En GitHub Copilot y en Claude Code los comandos se invocan con guion (`/speckit-specify`). En la documentación de SpecKit los verás también con punto (`/speckit.specify`).

## Requisitos

- Windows 10/11 con winget.
- Cuenta de GitHub con **GitHub Copilot**.
- Entorno de **desarrollo** de Power Platform con Dataverse y Code Apps habilitadas.
- Buzón de Exchange Online para recibir el email de prueba.
- Opcional: proyecto de Azure DevOps con proceso Agile.

## Aviso

Material de formación. SpecKit, los plugins de Power Platform y la CLI de Code Apps evolucionan rápido: si un comando ha cambiado, la documentación oficial manda. Las incidencias y las mejoras son bienvenidas como issues o pull requests.

## Licencia

[MIT](LICENSE)
