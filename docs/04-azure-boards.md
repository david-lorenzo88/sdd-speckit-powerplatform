# 4 · Seguimiento en Azure Boards (opcional)

La extensión de SpecKit [`spec-kit-ado`](../extensions/spec-kit-ado/README.md) refleja el avance de cada feature en Azure Boards, con el proceso **Agile**. La sincronización va en un solo sentido: el repositorio manda y el tablero lo refleja.

| SpecKit | Azure Boards |
|---|---|
| Carpeta `specs/NNN-…` | Feature |
| Historia de usuario de `spec.md` (US1…) | User Story, con prioridad y criterios de aceptación |
| Fases Setup / Foundational / Polish | User Story con la etiqueta `technical` |
| Tarea de `tasks.md` (T001…) | Task |

## Paso 1 · Instalar la extensión en tu proyecto

Desde la carpeta del proyecto de la demo (no la del taller):

```powershell
cd C:\demos\solicitudes-contacto
specify extension add --dev C:\demos\sdd-speckit-powerplatform\extensions\spec-kit-ado
specify extension list
```

Se instalan los comandos `/speckit-ado-setup` y `/speckit-ado-sync`. También se registran dos hooks:

- **después de `/speckit-tasks`:** ofrece crear los work items;
- **después de `/speckit-implement`:** sincroniza los estados automáticamente.

## Paso 2 · Configurar

1. Inicia sesión con `az login`, usando una cuenta con acceso a tu organización de Azure DevOps.
2. En Copilot Chat ejecuta `/speckit-ado-setup`. Te pedirá:
   - la organización;
   - el proyecto;
   - el área y la iteración (opcionales);
   - la URL del repositorio (opcional).

   Después comprueba la conexión y el proceso del proyecto.
3. Haz commit de `.specify/extensions/ado/ado-config.yml`. Ese archivo nunca guarda tokens.

## Paso 3 · Usar

| Cuándo | Qué hacer |
|---|---|
| Después de `/speckit-tasks` | Acepta la oferta del hook, o ejecuta `/speckit-ado-sync`. Se crean la Feature, las User Stories y las Tasks. |
| Después de cada `/speckit-implement` | Automático: las tareas marcadas `[x]` pasan a Closed y las historias completas a Resolved. |
| Para ver qué haría | `/speckit-ado-sync dry run` |

Haz commit de `specs/NNN-…/ado.json`, que guarda los IDs de los work items.

Para que el tablero se actualice en cada push, aunque nadie ejecute la sincronización, hay un pipeline opcional en `extensions/spec-kit-ado/pipelines/`.

Los detalles (reglas de estado, autenticación, pipeline y limitaciones) están en el [README de la extensión](../extensions/spec-kit-ado/README.md).
