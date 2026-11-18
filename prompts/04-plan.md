/speckit-plan
- Code App con React + TypeScript desde la plantilla Vite de microsoft/PowerAppsCodeApps, gestionada con la CLI pa.
- Tabla de Dataverse ppn_solicitudcontacto con las columnas ppn_nombre (principal), ppn_email, ppn_empresa, ppn_telefono (opcional), ppn_interes (elección) y ppn_mensaje.
- La app crea filas con el servicio generado por "pa app add data-source --connector dataverse --table ppn_solicitudcontacto --org-url <EnvUrl> --non-interactive".
- La app se publica con "pa app push --solution-id <id de SolicitudesContacto>" para que quede dentro de la solución.
- Flujo automatizado dentro de la solución: trigger de Dataverse "Cuando se agrega, modifica o elimina una fila" (Agregado) y acción de Office 365 Outlook "Enviar un correo electrónico (V2)".
- Destinatario en la variable de entorno ppn_DestinatarioPreventa.
- Usa las skills de los plugins code-apps, dataverse y power-automate de power-platform-skills.
- Sin backend adicional.
