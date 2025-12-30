import 'package:flutter/material.dart';

class SearchProvider with ChangeNotifier {
  List<String> _searchValues = [];

  List<String> get searchValues => _searchValues;

  void updateSearchValues(String value) {
    List<dynamic> newValues = value.split(',').map((e) => e.trim()).toList();
    addSearchValues(newValues);
    notifyListeners();
  }

  void addSearchValues(List<dynamic> values) {
    for (var value in values) {
      _searchValues.add(value);
    }
  }

  void removeSearchValue(String value) {
    searchValues.remove(value);
    notifyListeners();
  }

  void addMultipleSearchValues(List<String> values) {
    searchValues.addAll(values);
    notifyListeners();
  }

   void sortIngredients() {
    _searchValues.sort((a, b) => a.compareTo(b));
    notifyListeners();
  }
}
