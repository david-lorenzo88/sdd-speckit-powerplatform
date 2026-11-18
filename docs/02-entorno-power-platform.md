# 2 · Entorno de Power Platform

Tiempo estimado: 10–15 minutos.

## Paso 1 · Un entorno de desarrollo con Dataverse

Usa un entorno de **desarrollo** con Dataverse. **No** uses producción ni el entorno predeterminado.

- **Si tu organización ya te da uno:** anota su nombre y salta al paso 2.
- **Si no tienes:** puedes crear un entorno de tipo **Developer** desde el [Power Platform admin center](https://admin.powerplatform.microsoft.com). Ve a **Manage → Environments → New**, elige el tipo **Developer** y activa Dataverse.

Para la demo necesitas el rol **System Customizer** (o System Administrator) en ese entorno.

## Paso 2 · Habilitar Code Apps en el entorno

Las Code Apps vienen deshabilitadas por defecto. Las habilita un administrador del entorno:

1. Abre el [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Ve a **Manage → Environments** y selecciona tu entorno.
3. Ve a **Settings**, despliega **Product** y entra en **Features**.
4. Busca **Power Apps code apps** y activa **Enable code apps**.
5. Pulsa **Save**.

Si no eres administrador del entorno, pide a quien lo sea que lo active. Ten en cuenta que los usuarios que ejecutan una Code App necesitan licencia **Power Apps Premium**.

## Paso 3 · Anota la URL y el ID del entorno

Los vas a usar en la demo:

```powershell
pac auth create --environment https://<org>.crm4.dynamics.com   # si no lo hiciste en docs/01
pac org who
```

- **URL del entorno:** aparece en `pac org who` como *Org URL*, por ejemplo `https://contoso-dev.crm4.dynamics.com`. Anótala sin la `/` final.
- **ID del entorno:** aparece en `pac org who` como *Environment ID*. También está en el admin center, en los detalles del entorno.

Rellena esta tabla, porque la usarás en todos los pasos de la demo:

| Dato | Valor |
|---|---|
| URL del entorno (`EnvUrl`) | |
| ID del entorno (`EnvId`) | |
| Buzón que recibirá el email de prueba | |

## Paso 4 · Buzón para el email

El flujo de la demo envía un correo con **Office 365 Outlook**. Tu cuenta necesita un buzón de Exchange Online. Para la prueba, usa tu propio email como destinatario.

## Paso 5 (opcional) · Azure DevOps

Si quieres seguir el avance en Azure Boards, necesitas:

- un proyecto de Azure DevOps con proceso **Agile**;
- permiso para crear y editar work items en él.

Ver [docs/04](04-azure-boards.md).
