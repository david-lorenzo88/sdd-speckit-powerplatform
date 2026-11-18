# 3 · Demo paso a paso: de la spec al despliegue

Tiempo estimado: 60–90 minutos.

Vas a construir, con Spec Driven Development y SpecKit, un proyecto de Power Platform completo:

```
Usuario ──▶ Code App (React + TS) ──▶ Dataverse (ppn_solicitudcontacto) ──▶ Power Automate ──▶ Email a preventa
            └─────────────── todo dentro de la solución SolicitudesContacto (publisher ppn) ───────────────┘
```

**Antes de empezar**, comprueba dos cosas:

- `.\scripts\Test-Prerequisites.ps1` termina en "Todo listo" ([docs/01](01-prerequisitos.md)).
- Tienes a mano la URL y el ID de tu entorno ([docs/02](02-entorno-power-platform.md)).

**Cómo se trabaja en cada paso**

1. Copia el prompt del archivo indicado en `prompts/` y pégalo en **Copilot Chat** (modo **Agent**).
2. Lee lo que ha generado antes de avanzar. Ese checkpoint humano es la parte más importante de SDD.
3. Haz commit. Si quieres, crea también un tag como punto de guardado.

Los comandos de SpecKit son skills que **lanzas tú** escribiéndolos en el chat. El agente no los ejecuta por su cuenta.

> **Consejo:** elige un modelo potente en el selector del chat. Cuando Copilot pida permiso para ejecutar comandos en el terminal, puedes permitirlo para toda la sesión.

---

## Paso 1 · Crear el proyecto e inicializar SpecKit

Usa una carpeta **distinta** a la de este repositorio de taller:

```powershell
cd C:\demos
mkdir solicitudes-contacto; cd solicitudes-contacto
git init
specify init . --integration copilot --script ps
specify extension add git          # ramas por feature; si dice que ya está instalada, sigue
git add -A; git commit -m "chore: specify init"
code .
```

**Comprueba que:**

- existen las carpetas `.specify\` y `.github\skills\`;
- al escribir `/speckit` en Copilot Chat aparecen `speckit-constitution`, `speckit-specify`, `speckit-plan`, etc.

<details><summary>Opcional: conectar con Azure Boards desde el principio</summary>

```powershell
specify extension add --dev C:\demos\sdd-speckit-powerplatform\extensions\spec-kit-ado
```

Después ejecuta `/speckit-ado-setup` en Copilot Chat. Ver [docs/04](04-azure-boards.md).
</details>

---

## Paso 2 · Constitución

**Prompt:** [`prompts/01-constitution.md`](../prompts/01-constitution.md)

**Revisa** `.specify\memory\constitution.md`:

- No quedan marcadores de plantilla del tipo `[PRINCIPLE_1_NAME]`.
- Aparecen los 7 principios que pediste, y ninguno que no pediste.
- Las reglas se pueden verificar: prefijo `ppn`, connection references, variables de entorno.

```powershell
git add -A; git commit -m "docs: constitución"
```

---

## Paso 3 · Especificar

**Prompt:** [`prompts/02-specify.md`](../prompts/02-specify.md)

Se crea `specs\001-<nombre>\spec.md`. Con la extensión git, además, se crea una rama.

**Revisa** `spec.md`:

- Hay historias de usuario con prioridad (P1, P2) y escenarios de aceptación (*Given / When / Then*).
- Hay requisitos numerados (`FR-001`…) y criterios de éxito medibles.
- **No hay tecnología.** Si aparece "Dataverse", "React" o "Power Automate", pídele que la quite: la tecnología va en el plan.
- Si hay marcas `[NEEDS CLARIFICATION]`, se resuelven en el paso 4.

Revisa también `checklists\requirements.md`.

---

## Paso 4 · Clarificar

**Prompt:** [`prompts/03-clarify.md`](../prompts/03-clarify.md). Incluye las respuestas preparadas.

**Revisa** que:

- `spec.md` ya no tiene marcas `NEEDS CLARIFICATION`;
- hay una sección de aclaraciones con tus respuestas.

```powershell
git add -A; git commit -m "docs: spec 001"
```

---

## Paso 5 · Plan técnico

**Prompt:** [`prompts/04-plan.md`](../prompts/04-plan.md)

Fíjate en que el plan nombra los plugins y los comandos reales de la CLI `pa`. Así las tareas se generan con esos comandos y no con alternativas inventadas.

**Revisa:**

- `plan.md`: incluye la comprobación de la constitución, sin incumplimientos sin justificar.
- `data-model.md`: aparece la tabla `ppn_solicitudcontacto` con sus 6 columnas.
- `research.md` y `quickstart.md`: existen y tienen sentido.

Opcional: lanza el checklist de [`prompts/03-clarify.md`](../prompts/03-clarify.md).

---

## Paso 6 · Tareas y análisis

**Prompt:** [`prompts/05-tasks-analyze.md`](../prompts/05-tasks-analyze.md)

**Revisa** `tasks.md`. Lo habitual son estas fases:

- Setup (solución);
- Foundational (tabla y variable de entorno);
- US1, registrar solicitud (Code App);
- US2, notificar a preventa (flujo);
- Polish.

Las tareas marcadas con `[P]` se pueden ejecutar en paralelo.

`/speckit-analyze` no modifica nada: es un informe. Si encuentra problemas **CRITICAL**, corrígelos en la spec o en el plan, y vuelve a lanzar `/speckit-tasks` y `/speckit-analyze`. No los corrijas editando `tasks.md` a mano.

```powershell
git add -A; git commit -m "docs: plan y tareas 001"
```

> Con la extensión de Azure Boards instalada, SpecKit te ofrece aquí crear los work items.

---

## Paso 7 · Implementar Dataverse (solución, tabla y variable de entorno)

**Prompt:** [`prompts/06-implement-dataverse.md`](../prompts/06-implement-dataverse.md)

**Comprueba** en [make.powerapps.com](https://make.powerapps.com), dentro de tu entorno, en **Soluciones → SolicitudesContacto**:

- La solución tiene publisher con prefijo `ppn`.
- La tabla **Solicitud de contacto** (`ppn_solicitudcontacto`) tiene las columnas nombre, email, empresa, teléfono, interés y mensaje.
- Son obligatorias todas salvo el teléfono.
- La columna principal es el nombre.
- Existe la variable de entorno `ppn_DestinatarioPreventa`. Pon tu email como valor.

```powershell
git add -A; git commit -m "feat: dataverse 001"
```

---

## Paso 8 · Implementar la Code App

**Prompt:** [`prompts/07-implement-code-app.md`](../prompts/07-implement-code-app.md)

Lo que hará el agente, para que sepas qué esperar:

```powershell
npx degit github:microsoft/PowerAppsCodeApps/templates/vite app
cd app; npm install
pa app init --environment-id <EnvId> --display-name "Solicitudes de contacto"
pa app add data-source --connector dataverse --table ppn_solicitudcontacto --org-url <EnvUrl> --non-interactive
pa app run                                  # prueba local
npm run build
pa app push --solution-id <id-de-la-solución>
```

**Comprueba que:**

- `npm run build` termina sin errores;
- la app aparece dentro de la solución `SolicitudesContacto`, no en la solución predeterminada;
- al abrirla y enviar una solicitud, aparece la confirmación y la fila se ve en la tabla de Dataverse;
- al enviar el formulario vacío o con un email mal escrito, se muestran errores de validación.

```powershell
git add -A; git commit -m "feat: code app 001"
```

---

## Paso 9 · Implementar el flujo

**Prompt:** [`prompts/08-implement-flow.md`](../prompts/08-implement-flow.md)

**Comprueba** en la solución `SolicitudesContacto` que hay un flujo de nube **activado** con:

- trigger de **Dataverse** "Cuando se agrega, modifica o elimina una fila", tipo de cambio **Agregado**, tabla Solicitudes de contacto;
- acción de **Office 365 Outlook** "Enviar un correo electrónico (V2)", con el destinatario tomado de la variable de entorno, no escrito a mano;
- **connection references** dentro de la solución.

Si el flujo quedó fuera de la solución, añádelo con **Agregar existente → Automatización → Flujo de nube**.

```powershell
git add -A; git commit -m "feat: flujo 001"
```

---

## Paso 10 · Converger y probar de principio a fin

**Prompt:** [`prompts/09-converge.md`](../prompts/09-converge.md)

**Prueba completa:**

1. Abre la app y envía una solicitud con datos reales.
2. Comprueba que la fila aparece en Dataverse.
3. Comprueba que recibes el email. Si no llega, revisa el historial de ejecución del flujo en [make.powerautomate.com](https://make.powerautomate.com).
4. Comprueba que `tasks.md` tiene todas las tareas marcadas `[x]`.

**Versiona y exporta:**

```powershell
git add -A; git commit -m "feat: 001 solicitudes de contacto"
mkdir out -Force
pac solution export --name SolicitudesContacto --path out\SolicitudesContacto.zip
```

🎉 Has completado el ciclo SDD: constitución → spec → aclaraciones → plan → tareas → implementación → convergencia.

---

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| No aparecen los comandos `/speckit-*` | Revisa que `specify init` se ejecutó con `--integration copilot` y reinicia VS Code. |
| El agente no usa las skills de Power Platform | Repite el paso 7 de [docs/01](01-prerequisitos.md) y menciona en el prompt el plugin que debe usar. |
| `pa app push` falla con "Code app operations are disabled" | Habilita Code Apps en el entorno ([docs/02](02-entorno-power-platform.md), paso 2). |
| La app queda fuera de la solución | Vuelve a publicarla con `pa app push --solution-id <id>`. |
| El flujo no envía el email | Revisa la connection reference de Outlook y el valor de `ppn_DestinatarioPreventa`. |
| `/speckit-analyze` informa de problemas CRITICAL | Corrige la spec o el plan y repite `/speckit-tasks` y `/speckit-analyze`. |

## Quiero repetirlo

- **Git:** borra la carpeta `solicitudes-contacto` y empieza en el paso 1.
- **Power Platform:** borra la solución `SolicitudesContacto` y la tabla del entorno, o usa otro entorno.
