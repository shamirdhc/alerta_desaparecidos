import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Data Layer
import 'package:alerta_desaparecidos/data/data_sources/desaparecido_remote_data_source.dart';
import 'package:alerta_desaparecidos/data/repositories/desaparecido_repository_impl.dart';

// Domain Layer
import 'package:alerta_desaparecidos/domain/repositories/desaparecido_repository.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/domain/use_cases/reportar_desaparicion_use_case.dart';
import 'package:alerta_desaparecidos/domain/use_cases/get_missing_cases_usecase.dart';
import 'package:alerta_desaparecidos/domain/use_cases/mark_case_as_found_usecase.dart';
import 'package:alerta_desaparecidos/domain/use_cases/marcar_como_encontrado_use_case.dart';

// Presentation Layer
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/police_manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';

// Creamos una instancia global de GetIt
final locator = GetIt.instance;

void init() {
  // --- External ---
  locator.registerLazySingleton(() => FirebaseFirestore.instance);
  locator.registerLazySingleton(() => FirebaseStorage.instance);

  // --- Data Sources ---
  locator.registerLazySingleton<DesaparecidoRemoteDataSource>(
    () => DesaparecidoRemoteDataSource(
      locator<FirebaseFirestore>(),
      locator<FirebaseStorage>(),
    ),
  );

  // --- Repositories ---
  locator.registerLazySingleton<DesaparecidoRepository>(
    () => DesaparecidoRepositoryImpl(locator<DesaparecidoRemoteDataSource>()),
  );

  // --- Use Cases ---
  locator.registerLazySingleton(
    () => ObtenerDesaparecidosUseCase(locator<DesaparecidoRepository>()),
  );
  
  locator.registerLazySingleton(
    () => ReportarDesaparicionUseCase(locator<DesaparecidoRepository>()),
  );
  
  locator.registerLazySingleton(
    () => GetMissingCasesUseCase(locator<DesaparecidoRepository>()),
  );
  
  locator.registerLazySingleton(
    () => MarkCaseAsFoundUseCase(locator<DesaparecidoRepository>()),
  );
  
  locator.registerLazySingleton(
    () => MarcarComoEncontradoUseCase(locator<DesaparecidoRepository>()),
  );

  // --- ViewModels ---
  locator.registerFactory(
    () => ViewMissingViewModel(locator<ObtenerDesaparecidosUseCase>()),
  );
  
  locator.registerFactory(
    () => AddMissingViewModel(locator<ReportarDesaparicionUseCase>()),
  );
  
  locator.registerFactory(
    () => ViewFoundViewModel(locator<ObtenerDesaparecidosUseCase>()),
  );
  
  locator.registerFactory(
    () => PoliceManageMissingViewModel(
      getMissingCasesUseCase: locator<GetMissingCasesUseCase>(),
      markCaseAsFoundUseCase: locator<MarkCaseAsFoundUseCase>(),
    ),
  );

  // Agregar ManageMissingViewModel que faltaba
  locator.registerFactory(
    () => ManageMissingViewModel(locator<ObtenerDesaparecidosUseCase>()),
  );
}
