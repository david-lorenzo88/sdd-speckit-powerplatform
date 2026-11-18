# 5 · Validación de la demo con GitHub Copilot (ensayo)

Esta guía es para **ensayar la demo antes de presentarla**: Copilot actúa como validador y deja un informe con evidencias y tiempos de cada paso. Si solo quieres hacer la demo, usa [03-demo-paso-a-paso.md](03-demo-paso-a-paso.md).

Proyecto de la demo: **Solicitudes de contacto**. Una Code App guarda un formulario en una tabla de Dataverse. Al crearse la fila, un flujo de Power Automate envía un email a preventa. Todo vive en la solución `SolicitudesContacto` con publisher `ppn`.

El ensayo se hace con **GitHub Copilot Chat en VS Code (modo agente)**, igual que la demo en directo. Copilot valida cada paso y deja un informe en `VALIDACION.md`.

---

## Cómo se usa en GitHub Copilot

Con `--integration copilot`, SpecKit instala sus comandos como skills en `.github\skills\speckit-*\`. Se invocan con guion (`/speckit-specify`) y **los lanzas tú** escribiéndolos en el chat. El reparto es este:

| Quién | Qué hace |
|---|---|
| Tú | Ejecutas los pasos 0 y 1 en PowerShell. Luego escribes en Copilot Chat (modo agente) cada comando `/speckit-*` de este guion. |
| Copilot (modo agente) | Después de cada paso, cuando escribes `verifica paso N #file:.demo/GUION-DEMO.md`, ejecuta las comprobaciones de ese paso en el terminal y lo registra en `.demo\VALIDACION.md`. |

**Estructura de carpetas.** El guion y el informe van en `.demo\`, dentro del workspace para que Copilot los lea sin problemas. Esa carpeta queda excluida de Git:

```
C:\demos\solicitudes-contacto\   ← repositorio y workspace de VS Code
├─ .demo\                        ← en .gitignore
│  ├─ GUION-DEMO.md              ← este archivo
│  └─ VALIDACION.md              ← lo crea Copilot
├─ .github\skills\speckit-*\     ← comandos de SpecKit
└─ .specify\  specs\  …
```

**Consejos para la sesión de Copilot**
- **Modo y modelo:** usa el modo **Agent** y elige en el selector un modelo potente. Usa el mismo modelo que en la demo de mañana, así los tiempos del ensayo te sirven.
- **Ejecución de comandos:** Copilot pide permiso antes de ejecutar comandos en el terminal. Para el ensayo, acepta con la opción de permitir en la sesión, o tendrás que confirmar cada comando.
- **Un chat por paso:** si el chat se hace largo, abre uno nuevo. El estado de SpecKit está en los archivos y el `#file:` de cada `verifica` vuelve a cargar estas instrucciones.

---

## Parámetros (rellénalos antes de empezar)

| Parámetro | Valor |
|---|---|
| `EnvUrl` (URL del entorno de desarrollo, sin `/` final) | `https://<org>.crm4.dynamics.com` |
| `EnvId` (ID del entorno) | `<guid>` |
| `Destinatario` (buzón de preventa para la prueba) | `<email>` |
| Solución / publisher | `SolicitudesContacto` / `ppn` |
| Tabla | `ppn_solicitudcontacto` |
| Variable de entorno | `ppn_DestinatarioPreventa` |

---

## Instrucciones para GitHub Copilot (rol de validador)

> Esta sección es para Copilot en modo agente. Léela entera en cada `verifica paso N` y aplica solo la sección de ese paso.

1. **Tu papel es validar, no lanzar los comandos de SpecKit.** El usuario escribe los `/speckit-*`. Cuando se ejecute una skill de SpecKit, síguela con normalidad; esa parte es la demo.
2. **Al recibir `verifica paso N`:**
   - Ejecuta en el terminal de PowerShell las comprobaciones de la sección "Verificación" del paso N, con los parámetros de la tabla anterior. No inventes resultados: si un comando falla, registra el error tal cual.
   - Añade una entrada a `.demo\VALIDACION.md` (créalo si no existe) con este formato:
     ```
     ## Paso N · <nombre> · <hora local HH:mm>
     Resultado: OK | AVISO | FALLO
     Evidencias: <salidas resumidas de las comprobaciones>
     Desviaciones respecto a las slides: <comandos con otro nombre, archivos distintos, prompts interactivos, fases con otro nombre…>
     Tiempo desde el paso anterior: <min>
     ```
   - Si el resultado es OK, haz `git add -A; git commit -m "demo: paso N"` (si hay cambios) y luego `git tag paso-N`.
   - Si el resultado es FALLO, propón la corrección mínima y **no la apliques sin mi confirmación**.
3. **Tokens de Dataverse.** Obtenlos con `az account get-access-token --resource <EnvUrl>`. No escribas tokens ni secretos en ningún archivo.
4. **No borres nada en Dataverse** salvo la fila de prueba del paso 10.
5. **Al recibir `verifica todo`:** añade al final de `VALIDACION.md` un resumen con:
   - una tabla de pasos con resultado y tiempo;
   - el tiempo total;
   - la lista de cambios que hay que hacer en las slides y en este guion.

### Utilidades de PowerShell para las verificaciones

```powershell
$EnvUrl = '<EnvUrl>'
$token  = az account get-access-token --resource $EnvUrl --query accessToken -o tsv
$h      = @{ Authorization = "Bearer $token"; Accept = 'application/json'; 'OData-Version' = '4.0'; 'OData-MaxVersion' = '4.0' }
function DV($q) { Invoke-RestMethod -Uri "$EnvUrl/api/data/v9.2/$q" -Headers $h }
```

---

## Paso 0 · Requisitos (PowerShell, antes de abrir VS Code)

```powershell
git --version
node --version            # el plugin de Code Apps necesita 22 o superior
python --version
uv --version
specify version
pac                        # la cabecera muestra la versión
az --version
Get-Command pa             # CLI de Code Apps (@microsoft/power-apps-cli)
code --version
code --list-extensions | Select-String 'copilot|powerplatform'
```

Si falta la CLI `pa`, instálala con:

```powershell
npm install --global @microsoft/power-apps-cli
```

Comprueba también que:

- los plugins de power-platform-skills están instalados en GitHub Copilot CLI (docs/01, paso 7), y VS Code los detecta. Compruébalo escribiendo `/` en Copilot Chat: deben aparecer las skills de code-apps, dataverse y power-automate;
- el entorno de desarrollo tiene habilitadas las Code Apps.

---

## Paso 1 · Preparar el repositorio (PowerShell)

```powershell
cd C:\demos
mkdir solicitudes-contacto; cd solicitudes-contacto
git init
specify init . --integration copilot --script ps
specify extension add git          # si responde que ya está instalada, sigue

mkdir .demo
Copy-Item C:\demos\sdd-speckit-powerplatform\docs\05-validacion-con-copilot.md .demo\GUION-DEMO.md
Add-Content .gitignore "`n.demo/`nout/"
git add -A; git commit -m "chore: specify init"

pac auth create --environment <EnvUrl>
az login
code .
```

En VS Code, abre Copilot Chat en modo **Agent** y escribe:

```
#file:.demo/GUION-DEMO.md Vas a actuar como validador según la sección "Instrucciones para GitHub Copilot". Crea .demo\VALIDACION.md y ejecuta "verifica paso 0" y "verifica paso 1".
```

**Verificación paso 0.** Ejecutar los comandos del paso 0 y registrar las versiones. Hay que marcar AVISO si:

- Node.js es menor que 22;
- no existe `pa`;
- falta la extensión de GitHub Copilot o la de Power Platform Tools.

Pedir al usuario que confirme que ve las skills de code-apps, dataverse y power-automate al escribir `/` en el chat.

**Verificación paso 1.** Comprobar que:

- existen `.specify\memory\constitution.md` y `.github\skills\speckit-specify\SKILL.md`;
- `.gitignore` incluye `.demo/` y `out/`;
- `git log --oneline` tiene al menos un commit;
- `pac auth list` muestra el perfil activo con `EnvUrl`;
- `az account show` responde.

Registrar la lista de skills `speckit-*` que hay instaladas.

---

## Paso 2 · Constitución

```
/speckit-constitution Crea la constitución de este proyecto de Power Platform:
1. Todo componente vive en la solución no administrada SolicitudesContacto, publisher con prefijo ppn.
2. Dataverse es el sistema de registro; tablas y columnas con prefijo ppn_.
3. Los flujos usan connection references y variables de entorno; ningún valor hardcodeado.
4. La Code App usa React + TypeScript y accede a datos solo con los servicios generados por la CLI.
5. Validación de campos obligatorios en la app y en Dataverse.
6. Textos de interfaz en español y formularios accesibles.
7. Todo despliegue es reproducible por línea de comandos.
```

Luego escribe `verifica paso 2 #file:.demo/GUION-DEMO.md`.

**Verificación.** En `.specify\memory\constitution.md`:

- no queda ningún marcador de plantilla. Comprobarlo con `Select-String '\[[A-Z_]{3,}\]'`, que debe devolver 0 resultados;
- aparecen `ppn`, `SolicitudesContacto`, `connection reference` y `variable`.

Contar los principios. Si hay más de 7, marcar AVISO y listar los que no se pidieron.

---

## Paso 3 · Especificar

```
/speckit-specify El equipo comercial necesita registrar solicitudes de contacto de clientes potenciales.
El usuario rellena un formulario con nombre, email, empresa, teléfono (opcional), tipo de interés (Power Platform, Copilot Studio, Dynamics 365 u Otro) y un mensaje.
Al enviar, la solicitud se guarda y el equipo de preventa recibe un email con todos los datos.
El usuario ve una confirmación y puede registrar otra solicitud.
Los campos obligatorios y el formato del email se validan antes de enviar.
```

Luego escribe `verifica paso 3 #file:.demo/GUION-DEMO.md`.

**Verificación.**

- Existe `specs\001-*\spec.md`. Registrar el nombre real de la carpeta y de la rama actual (`git branch --show-current`).
- `spec.md` contiene `FR-001`.
- Contar las marcas `NEEDS CLARIFICATION`.
- Contar las menciones a tecnología con `Select-String 'React|Dataverse|Power Automate|TypeScript|Outlook'`. Si hay alguna, es AVISO: la spec no debería hablar de tecnología.
- Existe `checklists\requirements.md`.

---

## Paso 4 · Clarificar

```
/speckit-clarify
```

Respuestas preparadas (si pregunta otra cosa, responde en el momento y anótalo):

| Pregunta probable | Respuesta |
|---|---|
| ¿Quién recibe el email? | El buzón de preventa, configurable por entorno. |
| ¿Qué pasa si falla el envío? | La solicitud se guarda igual; el flujo reintenta. |
| ¿Se permiten duplicados? | Sí, en esta versión. |
| ¿Quién usa la app? | Usuarios internos con licencia de Power Apps. |

Este comando es opcional:

```
/speckit-checklist validación de datos y accesibilidad del formulario
```

Luego escribe `verifica paso 4 #file:.demo/GUION-DEMO.md`.

**Verificación.**

- `spec.md` ya no tiene marcas `NEEDS CLARIFICATION`.
- Existe una sección de aclaraciones (por ejemplo `## Clarifications`).
- Registrar las preguntas que hizo realmente el agente, para actualizar la slide 31.
- Si se ejecutó el checklist, registrar el archivo creado en `checklists\`.

---

## Paso 5 · Plan técnico

```
/speckit-plan
- Code App con React + TypeScript desde la plantilla Vite de microsoft/PowerAppsCodeApps, gestionada con la CLI pa.
- Tabla de Dataverse ppn_solicitudcontacto con las columnas ppn_nombre (principal), ppn_email, ppn_empresa, ppn_telefono (opcional), ppn_interes (elección) y ppn_mensaje.
- La app crea filas con el servicio generado por "pa app add data-source --connector dataverse --table ppn_solicitudcontacto --org-url <EnvUrl> --non-interactive".
- La app se publica con "pa app push --solution-id <id de SolicitudesContacto>" para que quede dentro de la solución.
- Flujo automatizado dentro de la solución: trigger de Dataverse "Cuando se agrega, modifica o elimina una fila" (Agregado) y acción de Office 365 Outlook "Enviar un correo electrónico (V2)".
- Destinatario en la variable de entorno ppn_DestinatarioPreventa.
- Usa las skills de los plugins code-apps, dataverse y power-automate de power-platform-skills.
- Sin backend adicional.
```

Luego escribe `verifica paso 5 #file:.demo/GUION-DEMO.md`.

**Verificación.**

- Existen `plan.md`, `research.md`, `data-model.md` y `quickstart.md`. Registrar si existe `contracts\`.
- `data-model.md` contiene `ppn_solicitudcontacto` y las columnas `ppn_nombre`, `ppn_email`, `ppn_empresa`, `ppn_telefono`, `ppn_interes` y `ppn_mensaje`. Si los nombres son distintos, registrarlos; las slides se ajustan a lo que genere.
- `plan.md` tiene la sección de comprobación de la constitución y no deja incumplimientos sin justificar.

---

## Paso 6 · Tareas y análisis

```
/speckit-tasks
```
```
/speckit-analyze
```

Luego escribe `verifica paso 6 #file:.demo/GUION-DEMO.md`.

**Verificación.**

- Existe `tasks.md`.
- Contar las tareas (`- [ ] T`) y las marcadas con `[P]`.
- Registrar los nombres reales de las fases. En la slide 33 aparecen como Setup, Fundacional, US1, US2 y Pulido.
- Del informe de analyze, registrar los hallazgos CRITICAL y HIGH. Si hay alguno CRITICAL, es FALLO: se corrige en la spec o en el plan y se vuelven a lanzar `/speckit-tasks` y `/speckit-analyze`.

---

## Paso 7 · Implementar Dataverse

```
/speckit-implement Ejecuta solo las tareas de las fases de Setup y Fundacional: solución, tabla y variable de entorno. Para nada más al terminarlas.
```

Luego escribe `verifica paso 7 #file:.demo/GUION-DEMO.md`.

**Verificación (Web API).**

```powershell
$sol = (DV "solutions?`$filter=uniquename eq 'SolicitudesContacto'&`$select=solutionid,uniquename,version").value
$ent = DV "EntityDefinitions(LogicalName='ppn_solicitudcontacto')?`$select=LogicalName,EntitySetName,PrimaryNameAttribute&`$expand=Attributes(`$select=LogicalName,AttributeType,RequiredLevel)"
$ent.Attributes | Where-Object LogicalName -like 'ppn_*' | Select-Object LogicalName, AttributeType, @{n='Required';e={$_.RequiredLevel.Value}}
DV "environmentvariabledefinitions?`$filter=schemaname eq 'ppn_DestinatarioPreventa'&`$select=schemaname,type,defaultvalue"
DV "solutioncomponents?`$filter=_solutionid_value eq $($sol.solutionid)&`$select=componenttype,objectid" | % value | Group-Object componenttype | Select Name, Count
```

Comprobar que:

- la solución existe;
- la tabla tiene las 6 columnas, la columna principal es `ppn_nombre` y son obligatorias todas salvo el teléfono;
- la variable de entorno existe;
- la solución contiene al menos la tabla (componenttype 1) y la variable de entorno (componenttype 380).

Registrar el `EntitySetName` real, porque lo necesita el paso 10. Registrar también qué skill o comando usó el agente para crear la tabla.

---

## Paso 8 · Implementar la Code App

```
/speckit-implement Ejecuta solo las tareas de la historia US1 (registrar solicitud): Code App con formulario validado que crea filas en ppn_solicitudcontacto, prueba local con "pa app run" y despliegue con "pa app push --solution-id" en la solución SolicitudesContacto.
```

> El origen de datos de Dataverse se añade sin preguntas con `pa app add data-source --connector dataverse --table ppn_solicitudcontacto --org-url <EnvUrl> --non-interactive`. Si el agente usa el modo interactivo y se queda esperando, complétalo tú y anótalo.

Luego escribe `verifica paso 8 #file:.demo/GUION-DEMO.md`.

**Verificación.**

- Existe la carpeta de la app con su archivo de configuración (`power.config.json` o el que genere la CLI). Registrar el nombre real.
- `npm run build` termina sin errores.
- En `src` hay un servicio o modelo generado que referencia `ppn_solicitudcontacto`.
- El formulario valida los campos obligatorios y el formato del email.
- Registrar la salida de `pa app push` (URL o ID de la app) y comprobar que se usó `--solution-id`: la app debe estar en la solución `SolicitudesContacto` (consultar `solutioncomponents` de la solución, como en el paso 7).
- Comprobación manual: abrir la app, enviar una solicitud y confirmar que la fila aparece:

```powershell
DV "<EntitySetName>?`$top=3&`$orderby=createdon desc&`$select=ppn_nombre,ppn_email,createdon"
```

---

## Paso 9 · Implementar el flujo

```
/speckit-implement Ejecuta solo las tareas de la historia US2 (notificar a preventa): flujo automatizado dentro de la solución, con connection references, destinatario desde ppn_DestinatarioPreventa.
```

Luego escribe `verifica paso 9 #file:.demo/GUION-DEMO.md`.

**Verificación (Web API).**

```powershell
$wf = (DV "workflows?`$filter=category eq 5&`$select=workflowid,name,statecode,clientdata").value | Where-Object { $_.clientdata -match 'ppn_solicitudcontacto' }
$wf | Select-Object name, statecode
$wf.clientdata -match 'connectionReferenceLogicalName'     # debe ser True
$wf.clientdata -match 'ppn_DestinatarioPreventa'            # debe ser True
$wf.clientdata -match [regex]::Escape('<Destinatario>')     # debe ser False: nada hardcodeado
DV "solutioncomponents?`$filter=_solutionid_value eq $($sol.solutionid) and objectid eq $($wf.workflowid)&`$select=componenttype"
```

Comprobar que:

- hay exactamente un flujo;
- está activado (`statecode` = 1);
- está dentro de la solución;
- usa connection references y la variable de entorno;
- el email del destinatario no aparece literal.

Si el flujo no está en la solución, es FALLO. Plan B: añadirlo con "Agregar existente" y anotarlo. Registrar también qué skill usó el agente, porque la documentación del plugin no confirma este trigger.

---

## Paso 10 · Converger y probar de extremo a extremo

```
/speckit-converge
```

Repite `/speckit-implement` y `/speckit-converge` hasta que informe Converged. Luego escribe `verifica paso 10 #file:.demo/GUION-DEMO.md`.

**Verificación.**

1. **Convergencia.** Registrar cuántas vueltas hicieron falta y las tareas nuevas que añadió converge. Comprobar que `tasks.md` no tiene tareas `- [ ]` pendientes.
2. **Prueba del flujo por API.** Crear una fila de prueba con el `EntitySetName` del paso 7 y el primer valor de la columna de elección:
   ```powershell
   $opt = (DV "EntityDefinitions(LogicalName='ppn_solicitudcontacto')/Attributes(LogicalName='ppn_interes')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet(`$select=Options)").OptionSet.Options[0].Value
   $body = @{ ppn_nombre='Prueba guion'; ppn_email='prueba@contoso.com'; ppn_empresa='Contoso'; ppn_interes=$opt; ppn_mensaje='Prueba E2E del guion' } | ConvertTo-Json
   $r = Invoke-WebRequest -Method Post -Uri "$EnvUrl/api/data/v9.2/<EntitySetName>" -Headers ($h + @{ 'Content-Type'='application/json' }) -Body $body
   $r.Headers['OData-EntityId']
   ```
3. **Ejecución del flujo.** Esperar 2 minutos y pedirme que confirme el email en el buzón de `Destinatario`. Si existe la tabla de ejecuciones de flujos, consultar también la última ejecución:
   ```powershell
   DV "flowruns?`$top=1&`$orderby=starttime desc&`$select=name,status,starttime"
   ```
   Si la consulta falla, marcar AVISO y comprobarlo en make.powerautomate.com.
4. **Limpieza.** Borrar solo la fila de prueba, usando la URL de `OData-EntityId`.
5. **Exportación.**
   ```powershell
   pac solution export --name SolicitudesContacto --path out\SolicitudesContacto.zip
   ```
   Comprobar que el ZIP existe. Hacer `git add -A; git commit -m "feat: 001 solicitudes de contacto"` y `git tag paso-10`.

Por último escribe `verifica todo #file:.demo/GUION-DEMO.md`.

---

## Para la demo en directo

- **Puntos de guardado.** Los tags `paso-N` permiten saltar a un punto ya validado en Git (`git checkout paso-N`). Dataverse no vuelve atrás: si ensayas varias veces, usa un entorno limpio o borra la solución y la tabla entre ensayos.
- **Tiempos.** Toma los tiempos reales de `VALIDACION.md` para decidir qué pasos se hacen en directo y cuáles se enseñan ya hechos. Los pasos 8 y 9 son los más lentos.
- **Repositorio limpio para mañana.** No reutilices el del ensayo. Crea otro desde el paso 1 o haz `git checkout paso-1`, y elimina la solución del entorno o usa otro entorno.
- **Plan B por paso.** Si un paso falla en directo, haz `git checkout paso-N` del ensayo para enseñar el resultado ya validado y sigue desde ahí.
