import '../entities/policia.dart';
import '../repositories/policia_repository.dart';

class GetAllPoliciasUseCase {
  final PoliciaRepository _repository;

  GetAllPoliciasUseCase(this._repository);

  Future<List<Policia>> call() async {
    return await _repository.getAllPolicias();
  }
}

class GetCurrentPoliciaUseCase {
  final PoliciaRepository _repository;

  GetCurrentPoliciaUseCase(this._repository);

  Future<Policia?> call() async {
    return await _repository.getCurrentPolicia();
  }
}

class IsCurrentUserAdminUseCase {
  final PoliciaRepository _repository;

  IsCurrentUserAdminUseCase(this._repository);

  Future<bool> call() async {
    return await _repository.isCurrentUserAdmin();
  }
}

class CreatePoliciaUseCase {
  final PoliciaRepository _repository;

  CreatePoliciaUseCase(this._repository);

  Future<void> call(Policia policia) async {
    // Validaciones
    if (policia.nombre.trim().isEmpty) {
      throw Exception('El nombre es requerido');
    }
    if (policia.apellido.trim().isEmpty) {
      throw Exception('El apellido es requerido');
    }
    if (policia.telefono.trim().isEmpty) {
      throw Exception('El teléfono es requerido');
    }
    if (policia.numeroCip.trim().isEmpty) {
      throw Exception('El número CIP es requerido');
    }

    // Verificar duplicados
    final phoneExists = await _repository.phoneNumberExists(policia.telefono);
    if (phoneExists) {
      throw Exception('Ya existe un policía con este número de teléfono');
    }

    final cipExists = await _repository.cipNumberExists(policia.numeroCip);
    if (cipExists) {
      throw Exception('Ya existe un policía con este número CIP');
    }

    await _repository.createPolicia(policia);
  }
}

class UpdatePoliciaUseCase {
  final PoliciaRepository _repository;

  UpdatePoliciaUseCase(this._repository);

  Future<void> call(Policia policia) async {
    // Validaciones
    if (policia.nombre.trim().isEmpty) {
      throw Exception('El nombre es requerido');
    }
    if (policia.apellido.trim().isEmpty) {
      throw Exception('El apellido es requerido');
    }
    if (policia.telefono.trim().isEmpty) {
      throw Exception('El teléfono es requerido');
    }
    if (policia.numeroCip.trim().isEmpty) {
      throw Exception('El número CIP es requerido');
    }

    // Verificar duplicados (excluyendo el policía actual)
    final phoneExists = await _repository.phoneNumberExists(
      policia.telefono,
      excludeUid: policia.uid,
    );
    if (phoneExists) {
      throw Exception('Ya existe un policía con este número de teléfono');
    }

    final cipExists = await _repository.cipNumberExists(
      policia.numeroCip,
      excludeUid: policia.uid,
    );
    if (cipExists) {
      throw Exception('Ya existe un policía con este número CIP');
    }

    await _repository.updatePolicia(policia);
  }
}

class DeletePoliciaUseCase {
  final PoliciaRepository _repository;

  DeletePoliciaUseCase(this._repository);

  Future<void> call(String uid) async {
    await _repository.deletePolicia(uid);
  }
}