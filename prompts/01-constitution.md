/speckit-constitution Crea la constitución de este proyecto de Power Platform:
1. Todo componente vive en la solución no administrada SolicitudesContacto, publisher con prefijo ppn.
2. Dataverse es el sistema de registro; tablas y columnas con prefijo ppn_.
3. Los flujos usan connection references y variables de entorno; ningún valor hardcodeado.
4. La Code App usa React + TypeScript y accede a datos solo con los servicios generados por la CLI pa.
5. Validación de campos obligatorios en la app y en Dataverse.
6. Textos de interfaz en español y formularios accesibles.
7. Todo despliegue es reproducible por línea de comandos.
