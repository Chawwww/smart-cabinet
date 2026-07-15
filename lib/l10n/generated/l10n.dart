// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Smart Cabinet`
  String get appName {
    return Intl.message('Smart Cabinet', name: 'appName', desc: '', args: []);
  }

  /// `Smart Cabinet Finder`
  String get appTitle {
    return Intl.message(
      'Smart Cabinet Finder',
      name: 'appTitle',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Select Language`
  String get selectLanguage {
    return Intl.message(
      'Select Language',
      name: 'selectLanguage',
      desc: '',
      args: [],
    );
  }

  /// `English`
  String get english {
    return Intl.message('English', name: 'english', desc: '', args: []);
  }

  /// `中文`
  String get chinese {
    return Intl.message('中文', name: 'chinese', desc: '', args: []);
  }

  /// `Bahasa Melayu`
  String get malay {
    return Intl.message('Bahasa Melayu', name: 'malay', desc: '', args: []);
  }

  /// `Choose your preferred language`
  String get chooseLanguage {
    return Intl.message(
      'Choose your preferred language',
      name: 'chooseLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Home`
  String get home {
    return Intl.message('Home', name: 'home', desc: '', args: []);
  }

  /// `Items`
  String get items {
    return Intl.message('Items', name: 'items', desc: '', args: []);
  }

  /// `Search`
  String get search {
    return Intl.message('Search', name: 'search', desc: '', args: []);
  }

  /// `Notifications`
  String get notifications {
    return Intl.message(
      'Notifications',
      name: 'notifications',
      desc: '',
      args: [],
    );
  }

  /// `Menu`
  String get menu {
    return Intl.message('Menu', name: 'menu', desc: '', args: []);
  }

  /// `Profile`
  String get profile {
    return Intl.message('Profile', name: 'profile', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Dark Mode`
  String get darkMode {
    return Intl.message('Dark Mode', name: 'darkMode', desc: '', args: []);
  }

  /// `Light Mode`
  String get lightMode {
    return Intl.message('Light Mode', name: 'lightMode', desc: '', args: []);
  }

  /// `Logout`
  String get logout {
    return Intl.message('Logout', name: 'logout', desc: '', args: []);
  }

  /// `Login`
  String get login {
    return Intl.message('Login', name: 'login', desc: '', args: []);
  }

  /// `Register`
  String get register {
    return Intl.message('Register', name: 'register', desc: '', args: []);
  }

  /// `Email`
  String get email {
    return Intl.message('Email', name: 'email', desc: '', args: []);
  }

  /// `Password`
  String get password {
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Name`
  String get name {
    return Intl.message('Name', name: 'name', desc: '', args: []);
  }

  /// `Confirm Password`
  String get confirmPassword {
    return Intl.message(
      'Confirm Password',
      name: 'confirmPassword',
      desc: '',
      args: [],
    );
  }

  /// `Forgot Password?`
  String get forgotPassword {
    return Intl.message(
      'Forgot Password?',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Don't have an account?`
  String get noAccount {
    return Intl.message(
      'Don\'t have an account?',
      name: 'noAccount',
      desc: '',
      args: [],
    );
  }

  /// `Already have an account?`
  String get hasAccount {
    return Intl.message(
      'Already have an account?',
      name: 'hasAccount',
      desc: '',
      args: [],
    );
  }

  /// `Continue`
  String get continueText {
    return Intl.message('Continue', name: 'continueText', desc: '', args: []);
  }

  /// `Welcome!`
  String get welcome {
    return Intl.message('Welcome!', name: 'welcome', desc: '', args: []);
  }

  /// `Guest User`
  String get guestUser {
    return Intl.message('Guest User', name: 'guestUser', desc: '', args: []);
  }

  /// `Sign in to access all features`
  String get signInToAccess {
    return Intl.message(
      'Sign in to access all features',
      name: 'signInToAccess',
      desc: '',
      args: [],
    );
  }

  /// `Language will be saved for your next visit`
  String get languageSaved {
    return Intl.message(
      'Language will be saved for your next visit',
      name: 'languageSaved',
      desc: '',
      args: [],
    );
  }

  /// `Manage Categories`
  String get manageCategories {
    return Intl.message(
      'Manage Categories',
      name: 'manageCategories',
      desc: '',
      args: [],
    );
  }

  /// `Add New Item`
  String get addNewItem {
    return Intl.message('Add New Item', name: 'addNewItem', desc: '', args: []);
  }

  /// `AI Assistant`
  String get aiAssistant {
    return Intl.message(
      'AI Assistant',
      name: 'aiAssistant',
      desc: '',
      args: [],
    );
  }

  /// `Medicine Info`
  String get medicineInfo {
    return Intl.message(
      'Medicine Info',
      name: 'medicineInfo',
      desc: '',
      args: [],
    );
  }

  /// `Reports`
  String get reports {
    return Intl.message('Reports', name: 'reports', desc: '', args: []);
  }

  /// `Bulk Import`
  String get bulkImport {
    return Intl.message('Bulk Import', name: 'bulkImport', desc: '', args: []);
  }

  /// `Custom Fields`
  String get customFields {
    return Intl.message(
      'Custom Fields',
      name: 'customFields',
      desc: '',
      args: [],
    );
  }

  /// `Manage Tags`
  String get manageTags {
    return Intl.message('Manage Tags', name: 'manageTags', desc: '', args: []);
  }

  /// `Sync Inventory`
  String get syncInventory {
    return Intl.message(
      'Sync Inventory',
      name: 'syncInventory',
      desc: '',
      args: [],
    );
  }

  /// `Sync Now`
  String get syncNow {
    return Intl.message('Sync Now', name: 'syncNow', desc: '', args: []);
  }

  /// `Help & Support`
  String get helpSupport {
    return Intl.message(
      'Help & Support',
      name: 'helpSupport',
      desc: '',
      args: [],
    );
  }

  /// `Cabinet`
  String get cabinet {
    return Intl.message('Cabinet', name: 'cabinet', desc: '', args: []);
  }

  /// `Boxes`
  String get boxes {
    return Intl.message('Boxes', name: 'boxes', desc: '', args: []);
  }

  /// `Category`
  String get category {
    return Intl.message('Category', name: 'category', desc: '', args: []);
  }

  /// `Quantity`
  String get quantity {
    return Intl.message('Quantity', name: 'quantity', desc: '', args: []);
  }

  /// `Unit`
  String get unit {
    return Intl.message('Unit', name: 'unit', desc: '', args: []);
  }

  /// `Expiry Date`
  String get expiryDate {
    return Intl.message('Expiry Date', name: 'expiryDate', desc: '', args: []);
  }

  /// `Production Date`
  String get productionDate {
    return Intl.message(
      'Production Date',
      name: 'productionDate',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get status {
    return Intl.message('Status', name: 'status', desc: '', args: []);
  }

  /// `Brand`
  String get brand {
    return Intl.message('Brand', name: 'brand', desc: '', args: []);
  }

  /// `Tags`
  String get tags {
    return Intl.message('Tags', name: 'tags', desc: '', args: []);
  }

  /// `Notes`
  String get notes {
    return Intl.message('Notes', name: 'notes', desc: '', args: []);
  }

  /// `Description`
  String get description {
    return Intl.message('Description', name: 'description', desc: '', args: []);
  }

  /// `Location`
  String get location {
    return Intl.message('Location', name: 'location', desc: '', args: []);
  }

  /// `Favorite`
  String get favorite {
    return Intl.message('Favorite', name: 'favorite', desc: '', args: []);
  }

  /// `Share`
  String get share {
    return Intl.message('Share', name: 'share', desc: '', args: []);
  }

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Confirm`
  String get confirm {
    return Intl.message('Confirm', name: 'confirm', desc: '', args: []);
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
  }

  /// `No data available`
  String get noData {
    return Intl.message(
      'No data available',
      name: 'noData',
      desc: '',
      args: [],
    );
  }

  /// `An error occurred`
  String get error {
    return Intl.message('An error occurred', name: 'error', desc: '', args: []);
  }

  /// `Retry`
  String get retry {
    return Intl.message('Retry', name: 'retry', desc: '', args: []);
  }

  /// `Success`
  String get success {
    return Intl.message('Success', name: 'success', desc: '', args: []);
  }

  /// `Failed`
  String get failed {
    return Intl.message('Failed', name: 'failed', desc: '', args: []);
  }

  /// `Search items...`
  String get searchHint {
    return Intl.message(
      'Search items...',
      name: 'searchHint',
      desc: '',
      args: [],
    );
  }

  /// `No results found`
  String get noResults {
    return Intl.message(
      'No results found',
      name: 'noResults',
      desc: '',
      args: [],
    );
  }

  /// `Add`
  String get add {
    return Intl.message('Add', name: 'add', desc: '', args: []);
  }

  /// `Remove`
  String get remove {
    return Intl.message('Remove', name: 'remove', desc: '', args: []);
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Create`
  String get create {
    return Intl.message('Create', name: 'create', desc: '', args: []);
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Back`
  String get back {
    return Intl.message('Back', name: 'back', desc: '', args: []);
  }

  /// `Next`
  String get next {
    return Intl.message('Next', name: 'next', desc: '', args: []);
  }

  /// `Done`
  String get done {
    return Intl.message('Done', name: 'done', desc: '', args: []);
  }

  /// `Yes`
  String get yes {
    return Intl.message('Yes', name: 'yes', desc: '', args: []);
  }

  /// `No`
  String get no {
    return Intl.message('No', name: 'no', desc: '', args: []);
  }

  /// `OK`
  String get ok {
    return Intl.message('OK', name: 'ok', desc: '', args: []);
  }

  /// `Warning`
  String get warning {
    return Intl.message('Warning', name: 'warning', desc: '', args: []);
  }

  /// `Info`
  String get info {
    return Intl.message('Info', name: 'info', desc: '', args: []);
  }

  /// `Expired`
  String get expired {
    return Intl.message('Expired', name: 'expired', desc: '', args: []);
  }

  /// `Expiring Soon`
  String get expiringSoon {
    return Intl.message(
      'Expiring Soon',
      name: 'expiringSoon',
      desc: '',
      args: [],
    );
  }

  /// `Low Stock`
  String get lowStock {
    return Intl.message('Low Stock', name: 'lowStock', desc: '', args: []);
  }

  /// `Out of Stock`
  String get outOfStock {
    return Intl.message('Out of Stock', name: 'outOfStock', desc: '', args: []);
  }

  /// `Inside Cabinet`
  String get insideCabinet {
    return Intl.message(
      'Inside Cabinet',
      name: 'insideCabinet',
      desc: '',
      args: [],
    );
  }

  /// `Taken`
  String get taken {
    return Intl.message('Taken', name: 'taken', desc: '', args: []);
  }

  /// `Used`
  String get used {
    return Intl.message('Used', name: 'used', desc: '', args: []);
  }

  /// `Damaged`
  String get damaged {
    return Intl.message('Damaged', name: 'damaged', desc: '', args: []);
  }

  /// `Normal`
  String get normal {
    return Intl.message('Normal', name: 'normal', desc: '', args: []);
  }

  /// `All`
  String get all {
    return Intl.message('All', name: 'all', desc: '', args: []);
  }

  /// `Select Category`
  String get selectCategory {
    return Intl.message(
      'Select Category',
      name: 'selectCategory',
      desc: '',
      args: [],
    );
  }

  /// `Select Cabinet`
  String get selectCabinet {
    return Intl.message(
      'Select Cabinet',
      name: 'selectCabinet',
      desc: '',
      args: [],
    );
  }

  /// `Select Box`
  String get selectBox {
    return Intl.message('Select Box', name: 'selectBox', desc: '', args: []);
  }

  /// `No Cabinet`
  String get noCabinet {
    return Intl.message('No Cabinet', name: 'noCabinet', desc: '', args: []);
  }

  /// `No Box`
  String get noBox {
    return Intl.message('No Box', name: 'noBox', desc: '', args: []);
  }

  /// `e.g. Paracetamol 500mg`
  String get itemNameHint {
    return Intl.message(
      'e.g. Paracetamol 500mg',
      name: 'itemNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Optional description`
  String get itemDescriptionHint {
    return Intl.message(
      'Optional description',
      name: 'itemDescriptionHint',
      desc: '',
      args: [],
    );
  }

  /// `e.g. Pfizer`
  String get brandHint {
    return Intl.message('e.g. Pfizer', name: 'brandHint', desc: '', args: []);
  }

  /// `Enter quantity`
  String get quantityHint {
    return Intl.message(
      'Enter quantity',
      name: 'quantityHint',
      desc: '',
      args: [],
    );
  }

  /// `Select unit`
  String get unitHint {
    return Intl.message('Select unit', name: 'unitHint', desc: '', args: []);
  }

  /// `Select expiry date`
  String get expiryDateHint {
    return Intl.message(
      'Select expiry date',
      name: 'expiryDateHint',
      desc: '',
      args: [],
    );
  }

  /// `Select production date`
  String get productionDateHint {
    return Intl.message(
      'Select production date',
      name: 'productionDateHint',
      desc: '',
      args: [],
    );
  }

  /// `Comma separated tags`
  String get tagsHint {
    return Intl.message(
      'Comma separated tags',
      name: 'tagsHint',
      desc: '',
      args: [],
    );
  }

  /// `Any extra notes`
  String get notesHint {
    return Intl.message(
      'Any extra notes',
      name: 'notesHint',
      desc: '',
      args: [],
    );
  }

  /// `Alert when quantity is at or below`
  String get lowStockAlertHint {
    return Intl.message(
      'Alert when quantity is at or below',
      name: 'lowStockAlertHint',
      desc: '',
      args: [],
    );
  }

  /// `Enter cabinet name`
  String get cabinetNameHint {
    return Intl.message(
      'Enter cabinet name',
      name: 'cabinetNameHint',
      desc: '',
      args: [],
    );
  }

  /// `e.g. Kitchen, Living Room`
  String get cabinetLocationHint {
    return Intl.message(
      'e.g. Kitchen, Living Room',
      name: 'cabinetLocationHint',
      desc: '',
      args: [],
    );
  }

  /// `Optional description`
  String get cabinetDescriptionHint {
    return Intl.message(
      'Optional description',
      name: 'cabinetDescriptionHint',
      desc: '',
      args: [],
    );
  }

  /// `Enter box name`
  String get boxNameHint {
    return Intl.message(
      'Enter box name',
      name: 'boxNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Optional description`
  String get boxDescriptionHint {
    return Intl.message(
      'Optional description',
      name: 'boxDescriptionHint',
      desc: '',
      args: [],
    );
  }

  /// `Enter category name`
  String get categoryNameHint {
    return Intl.message(
      'Enter category name',
      name: 'categoryNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Select an icon`
  String get categoryIconHint {
    return Intl.message(
      'Select an icon',
      name: 'categoryIconHint',
      desc: '',
      args: [],
    );
  }

  /// `Select a color`
  String get categoryColorHint {
    return Intl.message(
      'Select a color',
      name: 'categoryColorHint',
      desc: '',
      args: [],
    );
  }

  /// `Take Out`
  String get takeOut {
    return Intl.message('Take Out', name: 'takeOut', desc: '', args: []);
  }

  /// `Return Item`
  String get returnItem {
    return Intl.message('Return Item', name: 'returnItem', desc: '', args: []);
  }

  /// `AI Count`
  String get aiCount {
    return Intl.message('AI Count', name: 'aiCount', desc: '', args: []);
  }

  /// `AI Auto-Fill`
  String get aiAutoFill {
    return Intl.message('AI Auto-Fill', name: 'aiAutoFill', desc: '', args: []);
  }

  /// `Scan for Devices`
  String get scanDevice {
    return Intl.message(
      'Scan for Devices',
      name: 'scanDevice',
      desc: '',
      args: [],
    );
  }

  /// `Connect`
  String get connectDevice {
    return Intl.message('Connect', name: 'connectDevice', desc: '', args: []);
  }

  /// `Device Connected`
  String get deviceConnected {
    return Intl.message(
      'Device Connected',
      name: 'deviceConnected',
      desc: '',
      args: [],
    );
  }

  /// `Device Disconnected`
  String get deviceDisconnected {
    return Intl.message(
      'Device Disconnected',
      name: 'deviceDisconnected',
      desc: '',
      args: [],
    );
  }

  /// `Open`
  String get doorOpen {
    return Intl.message('Open', name: 'doorOpen', desc: '', args: []);
  }

  /// `Closed`
  String get doorClosed {
    return Intl.message('Closed', name: 'doorClosed', desc: '', args: []);
  }

  /// `Upper Door`
  String get upperDoor {
    return Intl.message('Upper Door', name: 'upperDoor', desc: '', args: []);
  }

  /// `Lower Door`
  String get lowerDoor {
    return Intl.message('Lower Door', name: 'lowerDoor', desc: '', args: []);
  }

  /// `LED On`
  String get ledOn {
    return Intl.message('LED On', name: 'ledOn', desc: '', args: []);
  }

  /// `LED Off`
  String get ledOff {
    return Intl.message('LED Off', name: 'ledOff', desc: '', args: []);
  }

  /// `Last Synced`
  String get lastSynced {
    return Intl.message('Last Synced', name: 'lastSynced', desc: '', args: []);
  }

  /// `No Internet Connection`
  String get noInternet {
    return Intl.message(
      'No Internet Connection',
      name: 'noInternet',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get connected {
    return Intl.message('Connected', name: 'connected', desc: '', args: []);
  }

  /// `Disconnected`
  String get disconnected {
    return Intl.message(
      'Disconnected',
      name: 'disconnected',
      desc: '',
      args: [],
    );
  }

  /// `Scanning...`
  String get scanning {
    return Intl.message('Scanning...', name: 'scanning', desc: '', args: []);
  }

  /// `Scan Complete`
  String get scanComplete {
    return Intl.message(
      'Scan Complete',
      name: 'scanComplete',
      desc: '',
      args: [],
    );
  }

  /// `No devices found`
  String get noDevicesFound {
    return Intl.message(
      'No devices found',
      name: 'noDevicesFound',
      desc: '',
      args: [],
    );
  }

  /// `Permission Required`
  String get permissionRequired {
    return Intl.message(
      'Permission Required',
      name: 'permissionRequired',
      desc: '',
      args: [],
    );
  }

  /// `Bluetooth permission is required to connect to the smart cabinet.`
  String get bluetoothPermission {
    return Intl.message(
      'Bluetooth permission is required to connect to the smart cabinet.',
      name: 'bluetoothPermission',
      desc: '',
      args: [],
    );
  }

  /// `Location permission is required for BLE scanning.`
  String get locationPermission {
    return Intl.message(
      'Location permission is required for BLE scanning.',
      name: 'locationPermission',
      desc: '',
      args: [],
    );
  }

  /// `Camera permission is required to take photos of items.`
  String get cameraPermission {
    return Intl.message(
      'Camera permission is required to take photos of items.',
      name: 'cameraPermission',
      desc: '',
      args: [],
    );
  }

  /// `Microphone permission is required for voice input.`
  String get microphonePermission {
    return Intl.message(
      'Microphone permission is required for voice input.',
      name: 'microphonePermission',
      desc: '',
      args: [],
    );
  }

  /// `Notification permission is required for alerts.`
  String get notificationPermission {
    return Intl.message(
      'Notification permission is required for alerts.',
      name: 'notificationPermission',
      desc: '',
      args: [],
    );
  }

  /// `Add Item`
  String get addItem {
    return Intl.message('Add Item', name: 'addItem', desc: '', args: []);
  }

  /// `Edit Item`
  String get editItem {
    return Intl.message('Edit Item', name: 'editItem', desc: '', args: []);
  }

  /// `Delete Item`
  String get deleteItem {
    return Intl.message('Delete Item', name: 'deleteItem', desc: '', args: []);
  }

  /// `Withdraw`
  String get withdraw {
    return Intl.message('Withdraw', name: 'withdraw', desc: '', args: []);
  }

  /// `Taken By`
  String get takenBy {
    return Intl.message('Taken By', name: 'takenBy', desc: '', args: []);
  }

  /// `History`
  String get history {
    return Intl.message('History', name: 'history', desc: '', args: []);
  }

  /// `No items found`
  String get noItems {
    return Intl.message('No items found', name: 'noItems', desc: '', args: []);
  }

  /// `Shared Cabinets`
  String get sharedCabinets {
    return Intl.message(
      'Shared Cabinets',
      name: 'sharedCabinets',
      desc: '',
      args: [],
    );
  }

  /// `Smart Cabinet Control`
  String get smartCabinetControl {
    return Intl.message(
      'Smart Cabinet Control',
      name: 'smartCabinetControl',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ms'),
      Locale.fromSubtags(languageCode: 'zh'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
