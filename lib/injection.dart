import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Data Layer
import 'package:alerta_desaparecidos/data/data_sources/desaparecido_remote_data_source.dart';
import 'package:alerta_desaparecidos/data/repositories/desaparecido_repository_impl.dart';

// Domain Layer
import 'package:alerta_desaparecidos/domain/repositories/desaparecido_repository.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
// --- AÑADE LA IMPORTACIÓN DEL NUEVO USE CASE ---
import 'package:alerta_desaparecidos/domain/use_cases/reportar_desaparicion_use_case.dart';
// Importa otros Use Cases que necesites registrar aquí

// Presentation Layer
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
// --- AÑADE LA IMPORTACIÓN DEL VIEWMODEL FALTANTE ---
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
// Agregar esta línea:
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';
// Importa otros ViewModels que necesites registrar aquí (ej. el de policía si lo refactorizas)

// Creamos una instancia global de GetIt
final locator = GetIt.instance;

void init() {
  // --- External ---
  // Registramos las instancias de Firebase que necesitan los DataSources
  locator.registerLazySingleton(() => FirebaseFirestore.instance);
  locator.registerLazySingleton(() => FirebaseStorage.instance);

  // --- Data Sources ---
  // Registramos el DataSource remoto, necesita Firestore y Storage
  locator.registerLazySingleton<DesaparecidoRemoteDataSource>(
    // --- CORRECCIÓN: Usar el nombre de la clase concreta existente ---
    () => DesaparecidoRemoteDataSource(
      // <-- Corregido: Usa la clase existente
      locator<FirebaseFirestore>(),
      locator<FirebaseStorage>(),
    ),
  );

  // --- Repositories ---
  // Registramos el Repositorio, necesita el DataSource
  locator.registerLazySingleton<DesaparecidoRepository>(
    () => DesaparecidoRepositoryImpl(locator<DesaparecidoRemoteDataSource>()),
  );

  // --- Use Cases ---
  // Registramos los Use Cases, necesitan los Repositorios
  locator.registerLazySingleton(
    () => ObtenerDesaparecidosUseCase(locator<DesaparecidoRepository>()),
  );
  // --- REGISTRA EL NUEVO USE CASE ---
  locator.registerLazySingleton(
    () => ReportarDesaparicionUseCase(locator<DesaparecidoRepository>()),
  );
  // Registra otros Use Cases aquí...

  // --- ViewModels ---
  // Registramos los ViewModels, necesitan los Use Cases
  // Usamos registerFactory porque generalmente queremos una nueva instancia cada vez
  locator.registerFactory(
    () => ViewMissingViewModel(locator<ObtenerDesaparecidosUseCase>()),
  );
  // --- REGISTRA EL VIEWMODEL FALTANTE ---
  locator.registerFactory(
    () => AddMissingViewModel(locator<ReportarDesaparicionUseCase>()),
  );
  // Registra otros ViewModels aquí...
  // Agregar el nuevo ViewModel
  // Agregar esta línea en la sección de ViewModels
  locator.registerLazySingleton<ViewFoundViewModel>(
    () => ViewFoundViewModel(locator<ObtenerDesaparecidosUseCase>()),
  );
}
