# 1 · Prerrequisitos (Windows)

Tiempo estimado: 30–45 minutos la primera vez.

Hay dos caminos:

- **Rápido (recomendado):** el script `Install-Prerequisites.ps1` instala solo lo que falta. Después completas a mano los pasos 8 y 9.
- **Manual:** sigues los pasos 1 a 9 de esta página.

En los dos casos, al final ejecuta la **comprobación** del paso 10.

## Qué necesitas antes de empezar

| Necesitas | Para qué |
|---|---|
| Windows 10/11 con **winget** (App Installer de Microsoft Store) | Instalar las herramientas |
| Cuenta de **GitHub con licencia de GitHub Copilot** | Agente en VS Code y Copilot CLI |
| Cuenta de **Microsoft 365 / Entra ID** con acceso a un entorno de Power Platform | Dataverse, Code Apps, Power Automate y Outlook |
| Permiso para instalar software en tu equipo | — |
| Opcional: proyecto de **Azure DevOps** (proceso Agile) | Seguimiento en Azure Boards ([docs/04](04-azure-boards.md)) |

---

## Camino rápido: script de instalación

Clona este repositorio y ejecuta el script desde **Windows PowerShell**. Con `-WhatIf` primero ves qué va a instalar:

```powershell
cd C:\
mkdir demos -Force; cd demos
git clone https://github.com/david-lorenzo88/sdd-speckit-powerplatform.git
cd sdd-speckit-powerplatform

powershell -ExecutionPolicy Bypass -File .\scripts\Install-Prerequisites.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\scripts\Install-Prerequisites.ps1
```

> Si todavía no tienes Git, descarga el repositorio como ZIP desde GitHub (botón **Code → Download ZIP**) y descomprímelo en `C:\demos\sdd-speckit-powerplatform`.

Cuando termine, **cierra la terminal y abre una nueva de PowerShell 7** (`pwsh`), para que se cargue el PATH. Luego sigue con los pasos 8, 9 y 10.

---

## Camino manual

### Paso 1 · Herramientas base

```powershell
winget install --id Microsoft.PowerShell -e          # PowerShell 7 (Copilot CLI lo necesita)
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e             # Node.js 22 o superior
winget install --id Python.Python.3.12 -e            # Python 3.11 o superior
winget install --id astral-sh.uv -e                  # uv, gestor de paquetes que usa SpecKit
winget install --id Microsoft.DotNet.SDK.10 -e       # .NET 10 SDK (PAC CLI y plugin de Canvas)
winget install --id Microsoft.AzureCLI -e
winget install --id Microsoft.VisualStudioCode -e
```

**Cierra la terminal y abre una nueva de PowerShell 7** (`pwsh`) antes de seguir.

### Paso 2 · PAC CLI (Power Platform CLI)

```powershell
dotnet tool install --global Microsoft.PowerApps.CLI.Tool
# si ya lo tenías: dotnet tool update --global Microsoft.PowerApps.CLI.Tool
pac
```

La cabecera de `pac` muestra la versión. El plugin de Copilot Studio necesita la **2.9.3 o superior**.

### Paso 3 · Power Apps CLI (`pa`, para Code Apps)

```powershell
npm install --global @microsoft/power-apps-cli
pa --version
```

### Paso 4 · SpecKit (Specify CLI)

```powershell
uv tool install specify-cli
uv tool update-shell          # añade la carpeta de herramientas de uv al PATH
```

**Cierra la terminal y abre una nueva** y comprueba:

```powershell
specify version
```

Para fijar una versión concreta usa `uv tool install specify-cli==<versión>`. Para actualizar, `uv tool install --force specify-cli`.

### Paso 5 · GitHub Copilot CLI

```powershell
winget install --id GitHub.Copilot -e
copilot --version
```

La primera vez que ejecutes `copilot`, inicia sesión con `/login` y sal con `/exit`.

### Paso 6 · Extensiones de VS Code

```powershell
code --install-extension GitHub.copilot-chat
code --install-extension microsoft-IsvExpTools.powerplatform-vscode
code --install-extension ms-CopilotStudio.vscode-copilotstudio
```

Abre VS Code e inicia sesión en GitHub desde el icono de Copilot (abajo a la derecha).

### Paso 7 · Plugins de Power Platform para el agente (power-platform-skills)

Son los plugins de Microsoft con los que el agente construye Code Apps, flujos, tablas de Dataverse, etc. El instalador los deja disponibles en GitHub Copilot CLI y VS Code los detecta.

```powershell
iwr https://raw.githubusercontent.com/microsoft/power-platform-skills/main/scripts/install.js -OutFile install.js
node install.js --include-dataverse
del install.js
```

`--include-dataverse` añade el plugin de Dataverse, que la demo necesita.

---

## Pasos manuales en los dos caminos

### Paso 8 · Plugin de Copilot Studio (opcional para la demo)

No hace falta para la demo de Code App y flujo, pero sí para trabajar con agentes de Copilot Studio. Abre `copilot` en una terminal y escribe:

```
/plugin marketplace add microsoft/copilot-studio-plugin
/plugin install mcs-assistant@copilot-studio-plugin
```

### Paso 9 · Inicios de sesión

```powershell
az login                                                      # Azure CLI (y Azure DevOps, si lo usas)
pac auth create --environment https://<org>.crm4.dynamics.com # tu entorno de desarrollo
pa auth login                                                 # Power Apps CLI (abre el navegador)
```

La URL y el ID del entorno se obtienen en [docs/02](02-entorno-power-platform.md).

---

## Paso 10 · Comprobación

```powershell
cd C:\demos\sdd-speckit-powerplatform
pwsh -File .\scripts\Test-Prerequisites.ps1
```

Debe mostrar todas las filas en **OK** y terminar con "Todo listo". En las filas que salgan como **FALTA** o **ACTUALIZAR**, la columna "Solucion" indica el comando que hay que ejecutar.

Comprueba también en VS Code que los plugins están cargados:

1. Abre Copilot Chat (`Ctrl+Alt+I`) en modo **Agent**.
2. Escribe `/`.
3. Deben aparecer skills de **code-apps**, **dataverse** y **power-automate**.

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `xxx no se reconoce como nombre de cmdlet` justo después de instalar | Cierra y abre la terminal. El PATH se carga al abrirla. |
| `specify` no se reconoce aunque se instaló | Ejecuta `uv tool update-shell` y abre una terminal nueva (también VS Code). Para la sesión actual basta con `$env:Path += ";$(uv tool dir --bin)"`. |
| `copilot` no arranca o se queja de la versión de PowerShell | Usa PowerShell 7 (`pwsh`), no Windows PowerShell 5.1. |
| `winget` no existe | Instala **App Installer** desde Microsoft Store. |
| El script no se ejecuta por la política de ejecución | Lánzalo con `powershell -ExecutionPolicy Bypass -File ...` |
| `npm install -g` falla por permisos | Abre la terminal como usuario normal (no hace falta administrador). Comprueba que `node --version` es 22 o superior. |
| No aparecen las skills de Power Platform en Copilot Chat | Reinicia VS Code. Si siguen sin aparecer, repite el paso 7. |
