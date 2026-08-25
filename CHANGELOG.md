# Changelog

Todos los cambios relevantes de Request Manager App serán documentados en este archivo.

El proyecto utiliza versionamiento:

`MAJOR.MINOR.PATCH+BUILD`

## [0.1.3] - 2026-08-24

### Added

- Capacidad para consultar publicaciones registradas localmente en SQLite.
- Firma `getAll()` y `getById(int id)` en la interfaz `PublicationRepository` y su implementación `PublicationRepositoryImpl`.
- Implementación de `getAll()` y `getById(int id)` en la fuente de datos `PublicationLocalDataSource`.
- Orden alfabético preestablecido (`name ASC` case-insensitive, con orden secundario `id ASC`) para el listado de publicaciones en `getAll()`.
- Validación de parámetro ID en consultas `getById()` (ID debe ser mayor a 0, lanzando `ArgumentError`).
- Manejo de consultas no encontradas devolviendo `null` para `getById()` y lista vacía `[]` para `getAll()`.
- Abstracción de excepciones SQLite nativas (`DatabaseException` / `Database closed`) a excepciones de dominio del tipo `PublicationPersistenceException`.

### Testing

- Pruebas unitarias de consultas en `publication_local_data_source_test.dart` (validación de base vacía, consultas por ID existente/inexistente, validación de ID <= 0, validación de orden alfabético case-insensitive, persistencia de estados TriState, isActive y fechas).
- Pruebas del repositorio en `publication_repository_impl_test.dart` (coherencia de retornos, envoltura de excepciones de persistencia inesperadas).
- Pruebas de integración de extremo a extremo:
  - Registro de publicación (`create`) y posterior lectura (`getById` y `getAll`) validando coincidencia total de atributos.
  - Persistencia real entre reinicios: Creación de publicación -> Cierre de conexión DB -> Reapertura de conexión DB -> Validación de lectura exitosa.
- Cobertura total del proyecto incrementada exitosamente a 66 pruebas unitarias e integración en verde.

## [0.1.2] - 2026-08-24

### Added

- Capacidad para registrar publicaciones de manera local en SQLite.
- `PublicationRepository` en la capa de dominio.
- `PublicationRepositoryImpl` en la capa de datos.
- `PublicationLocalDataSource` para operaciones de inserción en base de datos SQLite.
- `PublicationMapper` para mapeo bidireccional entre entidad de dominio y mapas de base de datos.
- Excepciones personalizadas de persistencia: `PublicationException`, `PublicationPersistenceException`, `DuplicatePublicationCodeException`, y `PublicationAlreadyPersistedException`.
- Validación para impedir la creación de una publicación que ya contiene un ID definido.
- Manejo especializado de errores por código duplicado (case-insensitive) y fallos generales de persistencia en SQLite.

### Testing

- Pruebas del mapeador (`publication_mapper_test.dart`) cubriendo Drafts, Complete y roundtrips.
- Pruebas de la persistencia directa (`publication_local_data_source_test.dart`) usando SQLite en memoria aislado.
- Pruebas del repositorio (`publication_repository_impl_test.dart`) validando lógica de inserción exitosa, excepciones de duplicados y rechazo de IDs no nulos.
- Total de 52 pruebas unitarias y de integración pasando al 100%.

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
