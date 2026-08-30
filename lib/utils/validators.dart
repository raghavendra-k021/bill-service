class Validators {
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10 || value.length > 15) {
      return 'Phone number must be 10-15 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  static String? validateOptionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length < 10 || trimmed.length > 15) {
      return 'Phone number must be 10-15 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  static String? validateGSTIN(String? value) {
    if (value == null || value.isEmpty) {
      return null; // GSTIN is optional
    }
    if (value.length != 15) {
      return 'GSTIN must be 15 characters';
    }
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(value)) {
      return 'Invalid GSTIN format';
    }
    return null;
  }

  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Barcode is required';
    }
    if (value.length < 1 || value.length > 50) {
      return 'Barcode must be 1-50 characters';
    }
    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    final price = double.tryParse(value);
    if (price == null) {
      return 'Invalid price';
    }
    if (price < 0) {
      return 'Price cannot be negative';
    }
    return null;
  }

  /// Optional price (e.g. purchase price): empty or 0 allowed, only rejects negative/invalid.
  static String? validateOptionalPrice(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final price = double.tryParse(value);
    if (price == null) {
      return 'Invalid price';
    }
    if (price < 0) {
      return 'Price cannot be negative';
    }
    return null;
  }

  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }
    final quantity = double.tryParse(value);
    if (quantity == null) {
      return 'Invalid quantity';
    }
    if (quantity <= 0) {
      return 'Quantity must be greater than 0';
    }
    return null;
  }
}
