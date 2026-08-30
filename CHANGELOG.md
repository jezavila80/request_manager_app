# Changelog

Todos los cambios relevantes de Request Manager App serán documentados en este archivo.

El proyecto utiliza versionamiento:

`MAJOR.MINOR.PATCH+BUILD`

## [0.1.6] - 2026-08-30

### Added

- Capacidad de prevención de duplicados evidentes de publicaciones con `PublicationDuplicateChecker`.
- Modelo `DuplicateCheckResult` y enum `DuplicateCheckStatus` para clasificar las validaciones en `none`, `possibleDuplicate` y `duplicateCode`.
- Lógica de negocio para validación en dos niveles:
  - Nivel 1 (Bloqueo Duro): Coincidencia exacta de código (`code`) case-insensitive de publicaciones activas.
  - Nivel 2 (Advertencia): Coincidencia por atributos combinados (`name` + `type` + `size` + `version`) sobre publicaciones activas.
- Reglas de compatibilidad deterministas para atributos:
  - `name`: trim + case-insensitive.
  - `type`: trim + case-insensitive si ambos están definidos.
  - `size` y `version` (`TriStateValue`):
    - `sinDefinir` es compatible con cualquier valor (información faltante).
    - `noAplica` es compatible únicamente con `noAplica`.
    - `conValor` es compatible con otro `conValor` si el valor coincide case-insensitive.
- Nuevas consultas de persistencia exactas en `PublicationLocalDataSource` y `PublicationRepository`:
  - `findActiveByExactCode(String code)`
  - `findActiveByName(String name)`

### Testing

- Pruebas unitarias de las nuevas consultas de persistencia exactas en `publication_local_data_source_test.dart` y `publication_repository_impl_test.dart`.
- Suite completa de pruebas específicas para `PublicationDuplicateChecker` en `publication_duplicate_checker_test.dart` que valida:
  - Códigos duplicados exactos y case-insensitive (bloqueo duro).
  - Códigos similares pero diferentes.
  - Mismo nombre y atributos normalizados con casing y espacios.
  - Mismo nombre pero tamaño o versión diferente.
  - Compatibilidad de estados `NOT_APPLICABLE` y `UNDEFINED` (no idénticos pero compatibles).
  - Drafts idénticos y Draft compatible con registro más completo.
  - Contradicción explícita de tipos.
  - Exclusión de publicaciones inactivas.
  - Múltiples coincidencias simultáneas en base de datos.
- Total de 119 pruebas unitarias y de integración pasando al 100%.

## [0.1.5] - 2026-08-26

### Added

- Capacidad para realizar búsquedas locales de publicaciones por código en SQLite.
- Firma `searchByCode(String query, {int limit = 20})` en la interfaz `PublicationRepository` y su correspondiente implementación `PublicationRepositoryImpl`.
- Implementación de `searchByCode` en la fuente de datos `PublicationLocalDataSource`.
- Algoritmo de priorización por relevancia en SQLite para códigos:
  1. Coincidencia exacta de código.
  2. Coincidencias de códigos que comienzan con el término de búsqueda.
  3. Coincidencias de códigos que contienen el término de búsqueda.
  *Orden secundario lexicográfico (`code COLLATE NOCASE ASC`) y de forma final por ID (`id ASC`).*
- Filtro automático de publicaciones activas (`is_active = 1`).
- Soporte para incluir publicaciones en estado `DRAFT` (con código asignado) y `COMPLETE` en los resultados.
- Normalización del query (trimming y retorno inmediato de `[]` para búsquedas vacías).
- Validación de límites (`limit > 0`, lanzando `ArgumentError` en caso contrario).
- Escape de caracteres comodín SQL (`%`, `_`) y el carácter de escape (`\`) utilizando `ESCAPE '\'`.

### Testing

- Pruebas unitarias de búsqueda por código en `publication_local_data_source_test.dart` y `publication_repository_impl_test.dart` cubriendo:
  - Búsqueda vacía/con espacios.
  - Validación de límites.
  - Exclusión de publicaciones inactivas.
  - Inclusión de borradores con código y completas, exclusión de borradores sin código.
  - Case-insensitivity.
  - Trimming del término de búsqueda.
  - Límite por defecto (20) y límites personalizados.
  - Priorización y ordenamiento de resultados (exacta -> empieza con -> contiene).
  - Escapes de caracteres especiales (`%`, `_`, `\`).
  - Wrapping de excepciones de persistencia inesperadas.
- Las 94 pruebas totales del proyecto en verde.

## [0.1.4] - 2026-08-24

### Added

- Capacidad para realizar búsquedas locales de publicaciones por nombre en SQLite.
- Firma `searchByName(String query, {int limit = 20})` en la interfaz `PublicationRepository` y su correspondiente implementación `PublicationRepositoryImpl`.
- Implementación de `searchByName` en la fuente de datos `PublicationLocalDataSource`.
- Algoritmo de priorización por relevancia en SQLite:
  1. Coincidencia exacta de nombre.
  2. Coincidencias que comienzan con el término de búsqueda.
  3. Coincidencias que contienen el término de búsqueda.
  *Orden secundario por orden alfabético case-insensitive y finalmente por ID.*
- Filtro automático de publicaciones activas (`is_active = 1`).
- Soporte para incluir publicaciones en estado `DRAFT` y `COMPLETE` en los resultados de búsqueda.
- Normalización automática del query (trimming y retorno inmediato de `[]` para búsquedas vacías).
- Validación robusta de límites (`limit > 0`, lanzando `ArgumentError` en caso contrario).
- Escape seguro de comodines SQL (`%`, `_`) y el carácter de escape (`\`) mediante la cláusula `ESCAPE '\'`.
- Abstracción de excepciones SQLite durante las consultas a `PublicationPersistenceException`.

### Testing

- Pruebas unitarias de búsqueda en `publication_local_data_source_test.dart` y `publication_repository_impl_test.dart` cubriendo:
  - Búsqueda vacía/con espacios.
  - Validación de límites correctos e incorrectos.
  - Exclusión de publicaciones inactivas.
  - Inclusión de publicaciones en borrador y completas.
  - Case-insensitivity.
  - Trimming del término de búsqueda.
  - Límite por defecto (20) y límites personalizados.
  - Priorización y ordenamiento de resultados (exacta -> empieza con -> contiene).
  - Escapes de caracteres especiales (`%`, `_`, `\`).
  - Wrapping de excepciones de persistencia inesperadas.
- Las 79 pruebas totales del proyecto en verde.

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
