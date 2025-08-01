import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Data Layer
import 'package:alerta_desaparecidos/data/data_sources/desaparecido_remote_data_source.dart';
import 'package:alerta_desaparecidos/data/repositories/desaparecido_repository_impl.dart';
import 'package:alerta_desaparecidos/data/data_sources/policia_remote_data_source.dart';
import 'package:alerta_desaparecidos/data/repositories/policia_repository_impl.dart';

// Domain Layer
import 'package:alerta_desaparecidos/domain/repositories/desaparecido_repository.dart';
import 'package:alerta_desaparecidos/domain/repositories/policia_repository.dart';
import 'package:alerta_desaparecidos/domain/use_cases/obtener_desaparecidos_use_case.dart';
import 'package:alerta_desaparecidos/domain/use_cases/reportar_desaparicion_use_case.dart';
import 'package:alerta_desaparecidos/domain/use_cases/get_missing_cases_usecase.dart';
import 'package:alerta_desaparecidos/domain/use_cases/mark_case_as_found_usecase.dart';
import 'package:alerta_desaparecidos/domain/use_cases/marcar_como_encontrado_use_case.dart';
import 'package:alerta_desaparecidos/domain/use_cases/marcar_como_encontrado_con_verificacion_use_case.dart';
import 'package:alerta_desaparecidos/domain/use_cases/policia_management_use_cases.dart';

// Presentation Layer
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/add_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/citizen/view_models/view_found_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/police_manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/manage_missing_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/policia_management_view_model.dart';
import 'package:alerta_desaparecidos/presentation/police/view_models/tutorial_view_model.dart';

// Creamos una instancia global de GetIt
final locator = GetIt.instance;

// Exportamos getIt para uso en otros archivos
final getIt = GetIt.instance;

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

  locator.registerLazySingleton<PoliciaRemoteDataSource>(
    () => PoliciaRemoteDataSourceImpl(
      firestore: locator<FirebaseFirestore>(),
    ),
  );

  // --- Repositories ---
  locator.registerLazySingleton<DesaparecidoRepository>(
    () => DesaparecidoRepositoryImpl(locator<DesaparecidoRemoteDataSource>()),
  );

  locator.registerLazySingleton<PoliciaRepository>(
    () => PoliciaRepositoryImpl(
      remoteDataSource: locator<PoliciaRemoteDataSource>(),
    ),
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

  // Nuevo caso de uso con verificación de jurisdicción
  locator.registerLazySingleton(
    () => MarcarComoEncontradoConVerificacionUseCase(
      locator<DesaparecidoRepository>(),
      locator<PoliciaRepository>(),
    ),
  );

  // Policia Use Cases
  locator.registerLazySingleton(
    () => GetAllPoliciasUseCase(locator<PoliciaRepository>()),
  );

  locator.registerLazySingleton(
    () => GetCurrentPoliciaUseCase(locator<PoliciaRepository>()),
  );

  locator.registerLazySingleton(
    () => IsCurrentUserAdminUseCase(locator<PoliciaRepository>()),
  );

  locator.registerLazySingleton(
    () => CreatePoliciaUseCase(locator<PoliciaRepository>()),
  );

  locator.registerLazySingleton(
    () => UpdatePoliciaUseCase(locator<PoliciaRepository>()),
  );

  locator.registerLazySingleton(
    () => DeletePoliciaUseCase(locator<PoliciaRepository>()),
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

  locator.registerFactory(
    () => ManageMissingViewModel(locator<ObtenerDesaparecidosUseCase>()),
  );

  locator.registerFactory(
    () => PoliciaManagementViewModel(
      getAllPoliciasUseCase: locator<GetAllPoliciasUseCase>(),
      getCurrentPoliciaUseCase: locator<GetCurrentPoliciaUseCase>(),
      isCurrentUserAdminUseCase: locator<IsCurrentUserAdminUseCase>(),
      createPoliciaUseCase: locator<CreatePoliciaUseCase>(),
      updatePoliciaUseCase: locator<UpdatePoliciaUseCase>(),
      deletePoliciaUseCase: locator<DeletePoliciaUseCase>(),
    ),
  );

  // Tutorial ViewModel
  locator.registerFactory(
    () => TutorialViewModel(),
  );
}
