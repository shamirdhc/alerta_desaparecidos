# Módulo de Gestión de Cuentas de Policías

## Descripción
Este módulo permite a los usuarios con privilegios de administrador gestionar las cuentas de otros policías en el sistema. Incluye funcionalidades para crear, editar, eliminar y visualizar información de cuentas de policía.

## Características Principales

### 🔐 Control de Acceso
- Solo usuarios con `admin: true` pueden acceder al módulo
- Verificación automática de privilegios al cargar la pantalla
- Redirección automática si el usuario no tiene permisos

### 👥 Gestión de Cuentas
- **Crear**: Agregar nuevas cuentas de policía con validación completa
- **Editar**: Modificar información existente de policías
- **Eliminar**: Remover cuentas con confirmación de seguridad
- **Visualizar**: Lista completa con búsqueda y filtros

### 📊 Estadísticas
- Total de policías registrados
- Número de administradores
- Distribución por departamentos
- Métricas en tiempo real

### 🔍 Búsqueda y Filtros
- Búsqueda por nombre, apellido, CIP o departamento
- Filtros en tiempo real
- Resultados instantáneos

## Estructura del Módulo

### Entidades
- **Policia**: Modelo de datos principal con campos:
  - `uid`: Identificador único
  - `nombre`: Nombre del policía
  - `apellido`: Apellido del policía
  - `telefono`: Número de teléfono
  - `departamento`: Departamento asignado
  - `unidad`: Unidad específica
  - `rango`: Rango policial
  - `numeroCip`: Número CIP único
  - `rol`: Rol en el sistema
  - `admin`: Privilegios de administrador
  - `fechaRegistro`: Fecha de registro

### Casos de Uso
- `GetAllPoliciasUseCase`: Obtener todos los policías
- `GetCurrentPoliciaUseCase`: Obtener policía actual
- `IsCurrentUserAdminUseCase`: Verificar privilegios de admin
- `CreatePoliciaUseCase`: Crear nueva cuenta
- `UpdatePoliciaUseCase`: Actualizar cuenta existente
- `DeletePoliciaUseCase`: Eliminar cuenta

### Pantallas y Widgets
- `PoliciaManagementScreen`: Pantalla principal de gestión
- `PoliciaFormDialog`: Formulario para crear/editar
- `PoliciaCard`: Tarjeta individual de policía
- `PoliciaStatsCard`: Tarjetas de estadísticas
- `PoliciaDeleteConfirmationDialog`: Confirmación de eliminación

## Validaciones Implementadas

### Campos Obligatorios
- Nombre y apellido
- Número de teléfono
- Departamento
- Número CIP
- Rango

### Validaciones Específicas
- **Teléfono**: Formato válido y único en el sistema
- **CIP**: Formato numérico y único
- **Nombres**: Solo letras y espacios
- **Departamentos**: Lista predefinida válida

### Verificaciones de Duplicados
- Número de teléfono único
- Número CIP único
- Validación antes de crear/actualizar

## Seguridad

### Control de Acceso
- Verificación de privilegios en cada operación
- Validación del token de autenticación
- Protección contra acceso no autorizado

### Validación de Datos
- Sanitización de entradas
- Validación de formatos
- Prevención de inyección de datos

## Integración con Firebase

### Firestore
- Colección `policias` para almacenar datos
- Índices optimizados para búsquedas
- Transacciones para operaciones críticas

### Autenticación
- Integración con Firebase Auth
- Verificación de usuario actual
- Gestión de sesiones

## Uso del Módulo

### Acceso
1. Iniciar sesión como policía con privilegios de admin
2. Ir al menú de usuario en la pantalla principal
3. Seleccionar "Gestión de Cuentas"

### Crear Nueva Cuenta
1. Presionar el botón "+" en la pantalla de gestión
2. Completar el formulario con información válida
3. Configurar privilegios de administrador si es necesario
4. Guardar la cuenta

### Editar Cuenta Existente
1. Buscar la cuenta en la lista
2. Presionar el ícono de edición
3. Modificar los campos necesarios
4. Guardar los cambios

### Eliminar Cuenta
1. Buscar la cuenta en la lista
2. Presionar el ícono de eliminación
3. Confirmar la acción en el diálogo
4. La cuenta será eliminada permanentemente

## Dependencias

### Paquetes Flutter
- `provider`: Gestión de estado
- `cloud_firestore`: Base de datos
- `firebase_auth`: Autenticación
- `get_it`: Inyección de dependencias

### Arquitectura
- Clean Architecture
- Patrón Repository
- MVVM con Provider

## Configuración

### Inyección de Dependencias
Las dependencias están configuradas en `injection.dart`:
```dart
// Data Sources
locator.registerLazySingleton<PoliciaRemoteDataSource>(
  () => PoliciaRemoteDataSourceImpl(locator<FirebaseFirestore>()),
);

// Repositories
locator.registerLazySingleton<PoliciaRepository>(
  () => PoliciaRepositoryImpl(locator<PoliciaRemoteDataSource>()),
);

// Use Cases
locator.registerLazySingleton(() => GetAllPoliciasUseCase(locator<PoliciaRepository>()));
// ... otros use cases

// ViewModels
locator.registerFactory(() => PoliciaManagementViewModel(
  getAllPoliciasUseCase: locator<GetAllPoliciasUseCase>(),
  // ... otros parámetros
));
```

### Navegación
La navegación se realiza desde `PoliceHomeScreen`:
```dart
void _navigateToPoliciaManagement() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => di.locator<PoliciaManagementViewModel>(),
        child: const PoliciaManagementScreen(),
      ),
    ),
  );
}
```

## Notas Técnicas

### Rendimiento
- Carga paginada de datos (preparado para implementar)
- Búsqueda optimizada con índices
- Caché local para mejorar respuesta

### Mantenibilidad
- Código modular y reutilizable
- Separación clara de responsabilidades
- Documentación completa

### Escalabilidad
- Arquitectura preparada para nuevas funcionalidades
- Fácil extensión de validaciones
- Soporte para múltiples roles

## Próximas Mejoras

### Funcionalidades Pendientes
- [ ] Paginación de resultados
- [ ] Exportación de datos
- [ ] Historial de cambios
- [ ] Notificaciones de cambios
- [ ] Filtros avanzados por rango/unidad

### Optimizaciones
- [ ] Caché de búsquedas frecuentes
- [ ] Compresión de imágenes de perfil
- [ ] Sincronización offline
- [ ] Métricas de uso

## Soporte
Para dudas o problemas con el módulo, revisar:
1. Logs de la aplicación
2. Estado de conexión a Firebase
3. Permisos del usuario actual
4. Validaciones de formularios