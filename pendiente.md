# Pendientes

## Fix: /api/diagnostico/conexion falla en MonsterASP con SQL Server

**Error:** `VIEW SERVER PERFORMANCE STATE permission was denied on object 'server', database 'master'.`

---

### Cómo está ahora

Archivo: `Repositorios/RepositorioLecturaSqlServer.cs` — método `ObtenerDiagnosticoConexionAsync()` línea 592.

```sql
SELECT
    DB_NAME() AS nombre_base_datos,
    SCHEMA_NAME() AS esquema_actual,
    @@VERSION AS version_servidor,
    @@SERVERNAME AS nombre_servidor,
    sqlserver_start_time AS hora_inicio_servidor,   -- <-- PROBLEMA
    SUSER_SNAME() AS usuario_actual,
    @@SPID AS id_proceso_conexion,
    SERVERPROPERTY('InstanceName') AS nombre_instancia,
    SERVERPROPERTY('Edition') AS edicion_sqlserver,
    SERVERPROPERTY('ProductVersion') AS version_producto
FROM sys.dm_os_sys_info   -- <-- PROBLEMA: requiere VIEW SERVER PERFORMANCE STATE
```

`sys.dm_os_sys_info` es una vista del sistema de SQL Server que solo pueden consultar usuarios con permisos de administrador (`VIEW SERVER PERFORMANCE STATE`). En MonsterASP free, el usuario `db51269` no tiene ese permiso.

---

### Cómo quedaría

Reemplazar la query en la misma línea 592 por:

```sql
SELECT
    DB_NAME() AS nombre_base_datos,
    SCHEMA_NAME() AS esquema_actual,
    @@VERSION AS version_servidor,
    @@SERVERNAME AS nombre_servidor,
    GETDATE() AS hora_inicio_servidor,   -- reemplaza sqlserver_start_time
    SUSER_SNAME() AS usuario_actual,
    @@SPID AS id_proceso_conexion,
    SERVERPROPERTY('InstanceName') AS nombre_instancia,
    SERVERPROPERTY('Edition') AS edicion_sqlserver,
    SERVERPROPERTY('ProductVersion') AS version_producto
```

Sin `FROM` — en SQL Server las funciones y variables globales no requieren tabla origen.

---

### Implicaciones

- **`hora_inicio_servidor`** ya no mostrará cuándo arrancó el servidor SQL Server sino la hora actual de la consulta. Es un dato menos preciso pero suficiente para confirmar que la conexión funciona.
- **Sin impacto en otras funciones** — este método solo lo usa `/api/diagnostico/conexion`. El resto del CRUD no se ve afectado.
- **Compatible con todos los entornos** — la query corregida funciona tanto en SQL Server local, LocalDB, SQL Server Express como en MonsterASP y cualquier hosting compartido.
- **Requiere republicar** — después del fix hay que volver a ejecutar `dotnet publish` y `msdeploy`.
