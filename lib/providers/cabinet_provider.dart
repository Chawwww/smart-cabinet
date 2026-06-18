import 'dart:async';

import 'package:flutter/material.dart';

import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';

class CabinetProvider extends ChangeNotifier {
  final FirestoreService _firestoreService =
      FirestoreService();

  List<CabinetModel> _cabinets = [];
  List<BoxModel> _boxes = [];

  bool _isLoading = false;

  String? _error;

  StreamSubscription? _cabinetSubscription;
  StreamSubscription? _boxSubscription;

  // ==========================
  // Getters
  // ==========================

  List<CabinetModel> get cabinets => _cabinets;

  List<BoxModel> get boxes => _boxes;

  bool get isLoading => _isLoading;

  String? get error => _error;

  int get totalCabinets => _cabinets.length;

  int get totalBoxes => _boxes.length;

  // ==========================
  // Load Cabinets
  // ==========================

  void loadCabinets() {
    _setLoading(true);

    _cabinetSubscription?.cancel();

    _cabinetSubscription =
        _firestoreService.getCabinets().listen(
      (cabinets) {
        _cabinets = cabinets;

        _error = null;

        _setLoading(false);
      },
      onError: (error) {
        _error = error.toString();

        _setLoading(false);
      },
    );
  }

  // ==========================
  // Load Boxes
  // ==========================

  void loadBoxes() {
    _boxSubscription?.cancel();

    _boxSubscription =
        _firestoreService.getBoxes().listen(
      (boxes) {
        _boxes = boxes;

        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();

        notifyListeners();
      },
    );
  }

  // ==========================
  // Cabinet CRUD
  // ==========================

  Future<void> addCabinet(
    CabinetModel cabinet,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.addCabinet(
        cabinet,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  Future<void> updateCabinet(
    CabinetModel cabinet,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.updateCabinet(
        cabinet,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  Future<void> deleteCabinet(
    String cabinetId,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.deleteCabinet(
        cabinetId,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  // ==========================
  // Box CRUD
  // ==========================

  Future<void> addBox(
    BoxModel box,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.addBox(
        box,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  Future<void> updateBox(
    BoxModel box,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.updateBox(
        box,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  Future<void> deleteBox(
    String boxId,
  ) async {
    try {
      _setLoading(true);

      await _firestoreService.deleteBox(
        boxId,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  // ==========================
  // Find Cabinet
  // ==========================

  CabinetModel? getCabinetById(
    String id,
  ) {
    try {
      return _cabinets.firstWhere(
        (cabinet) => cabinet.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Find Box
  // ==========================

  BoxModel? getBoxById(
    String id,
  ) {
    try {
      return _boxes.firstWhere(
        (box) => box.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // Cabinet Boxes
  // ==========================

  List<BoxModel> getBoxesForCabinet(
    String cabinetId,
  ) {
    return _boxes
        .where(
          (box) =>
              box.cabinetId == cabinetId,
        )
        .toList();
  }

  // ==========================
  // Search Cabinets
  // ==========================

  List<CabinetModel> searchCabinets(
    String keyword,
  ) {
    if (keyword.isEmpty) {
      return _cabinets;
    }

    final query =
        keyword.toLowerCase();

    return _cabinets.where(
      (cabinet) {
        return cabinet.name
                .toLowerCase()
                .contains(query) ||
            cabinet.location
                    ?.toLowerCase()
                    .contains(query) ==
                true;
      },
    ).toList();
  }

  // ==========================
  // Search Boxes
  // ==========================

  List<BoxModel> searchBoxes(
    String keyword,
  ) {
    if (keyword.isEmpty) {
      return _boxes;
    }

    final query =
        keyword.toLowerCase();

    return _boxes.where(
      (box) {
        return box.name
                .toLowerCase()
                .contains(query) ||
            box.description
                    ?.toLowerCase()
                    .contains(query) ==
                true;
      },
    ).toList();
  }

  // ==========================
  // Clear Error
  // ==========================

  void clearError() {
    _error = null;

    notifyListeners();
  }

  // ==========================
  // Loading Helper
  // ==========================

  void _setLoading(
    bool value,
  ) {
    _isLoading = value;

    notifyListeners();
  }

  // ==========================
  // Dispose
  // ==========================

  @override
  void dispose() {
    _cabinetSubscription?.cancel();
    _boxSubscription?.cancel();

    super.dispose();
  }
}