# Changelog

Todos los cambios relevantes de Request Manager App serán documentados en este archivo.

El proyecto utiliza versionamiento:

`MAJOR.MINOR.PATCH+BUILD`

## [0.1.1] - 2026-08-22

### Added

- Persistencia local inicial con SQLite.
- Base de datos `request_manager.db`.
- Versionamiento inicial de base de datos.
- `MigrationV1`.
- Tabla `publications`.
- Constraints de integridad para publicaciones.
- Soporte para tamaño y versión con estados `undefined`, `value` y `not_applicable`.
- Índice único case-insensitive para códigos de publicaciones.
- Pruebas SQLite aisladas.
- Validación de persistencia y reapertura de la base de datos.

### Testing

- 26 pruebas del esquema SQLite.
- 40 pruebas totales del proyecto pasando correctamente.

## [0.1.0]

### Added

- Modelo de dominio `Publication`.
- Estado calculado `DRAFT / COMPLETE`.
- Código opcional para publicaciones Draft.
- Nombre obligatorio.
- Tipo flexible.
- Descripción operativa para Draft.
- Manejo de tamaño como definido, sin definir o no aplicable.
- Manejo de versión como definida, sin definir o no aplicable.
- `isActive`.
- Fechas de creación y actualización.
- Evolución del mismo registro desde Draft hacia Complete.
- Pruebas unitarias del dominio.

## [0.0.1]

### Added

- Proyecto Flutter inicial `request_manager_app`.
- Configuración inicial Android.
- Estructura feature-first ligera.
- Design System centralizado.
- Estilo visual "Moderno y Limpio — Propuesta 1".
- Theme, colores, tipografía y espaciados centralizados.
- Componentes visuales reutilizables.
- Design System Preview.
- Documentación inicial y roadmap.
