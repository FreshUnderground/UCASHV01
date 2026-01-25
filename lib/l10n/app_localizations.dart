import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'UCASH - Modern Money Transfer'**
  String get appTitle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @physicalFees.
  ///
  /// In en, this message translates to:
  /// **'Physical fees'**
  String get physicalFees;

  /// No description provided for @virtualFees.
  ///
  /// In en, this message translates to:
  /// **'Virtual fees'**
  String get virtualFees;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get enterUsername;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @operations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operations;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @agents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agents;

  /// No description provided for @shops.
  ///
  /// In en, this message translates to:
  /// **'Shops'**
  String get shops;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @synchronization.
  ///
  /// In en, this message translates to:
  /// **'Synchronization'**
  String get synchronization;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get withdrawal;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @commission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get commission;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing...'**
  String get syncing;

  /// No description provided for @syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Synchronization successful'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Synchronization failed'**
  String get syncFailed;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get lastSync;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @hideFilters.
  ///
  /// In en, this message translates to:
  /// **'Hide filters'**
  String get hideFilters;

  /// No description provided for @showFilters.
  ///
  /// In en, this message translates to:
  /// **'Show filters'**
  String get showFilters;

  /// No description provided for @allShops.
  ///
  /// In en, this message translates to:
  /// **'All shops'**
  String get allShops;

  /// No description provided for @selectShop.
  ///
  /// In en, this message translates to:
  /// **'Select a Shop'**
  String get selectShop;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get info;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed successfully'**
  String get languageChanged;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting application...'**
  String get starting;

  /// No description provided for @initializingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Initializing database...'**
  String get initializingDatabase;

  /// No description provided for @initializingServices.
  ///
  /// In en, this message translates to:
  /// **'Initializing core services...'**
  String get initializingServices;

  /// No description provided for @startingSync.
  ///
  /// In en, this message translates to:
  /// **'Starting synchronization...'**
  String get startingSync;

  /// No description provided for @initializingConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Initializing connectivity service...'**
  String get initializingConnectivity;

  /// No description provided for @loadingInitialData.
  ///
  /// In en, this message translates to:
  /// **'Loading initial data...'**
  String get loadingInitialData;

  /// No description provided for @loadingShops.
  ///
  /// In en, this message translates to:
  /// **'Loading shops...'**
  String get loadingShops;

  /// No description provided for @loadingAgents.
  ///
  /// In en, this message translates to:
  /// **'Loading agents...'**
  String get loadingAgents;

  /// No description provided for @loadingRates.
  ///
  /// In en, this message translates to:
  /// **'Loading rates...'**
  String get loadingRates;

  /// No description provided for @finalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing...'**
  String get finalizing;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get ready;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get invalidCredentials;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirmLogout;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete this employee?'**
  String get confirmDelete;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @agentDashboard.
  ///
  /// In en, this message translates to:
  /// **'Agent Dashboard'**
  String get agentDashboard;

  /// No description provided for @clientDashboard.
  ///
  /// In en, this message translates to:
  /// **'Client Dashboard'**
  String get clientDashboard;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @partners.
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get partners;

  /// No description provided for @ratesAndCommissions.
  ///
  /// In en, this message translates to:
  /// **'Rates & Commissions'**
  String get ratesAndCommissions;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @flot.
  ///
  /// In en, this message translates to:
  /// **'FLOT'**
  String get flot;

  /// No description provided for @fees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get fees;

  /// No description provided for @virtual.
  ///
  /// In en, this message translates to:
  /// **'VIRTUAL'**
  String get virtual;

  /// No description provided for @validations.
  ///
  /// In en, this message translates to:
  /// **'Validations'**
  String get validations;

  /// No description provided for @operationDataSynced.
  ///
  /// In en, this message translates to:
  /// **'Operation data synchronized'**
  String get operationDataSynced;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Synchronization error'**
  String get syncError;

  /// No description provided for @modernSecureTransfer.
  ///
  /// In en, this message translates to:
  /// **'Modern and secure money transfer'**
  String get modernSecureTransfer;

  /// No description provided for @pleaseEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get pleaseEnterUsername;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @agentLogin.
  ///
  /// In en, this message translates to:
  /// **'Agent Login'**
  String get agentLogin;

  /// No description provided for @clientLogin.
  ///
  /// In en, this message translates to:
  /// **'Client Login'**
  String get clientLogin;

  /// No description provided for @createDefaultAdmin.
  ///
  /// In en, this message translates to:
  /// **'Create Default Admin'**
  String get createDefaultAdmin;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @capitalAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Capital Adjustment'**
  String get capitalAdjustment;

  /// No description provided for @adjustCapital.
  ///
  /// In en, this message translates to:
  /// **'Adjust Capital'**
  String get adjustCapital;

  /// No description provided for @capitalAdjustmentHistory.
  ///
  /// In en, this message translates to:
  /// **'Capital Adjustment History'**
  String get capitalAdjustmentHistory;

  /// No description provided for @capitalAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Capital Adjustments'**
  String get capitalAdjustments;

  /// No description provided for @adjustmentType.
  ///
  /// In en, this message translates to:
  /// **'Adjustment Type'**
  String get adjustmentType;

  /// No description provided for @increaseCapital.
  ///
  /// In en, this message translates to:
  /// **'Increase Capital'**
  String get increaseCapital;

  /// No description provided for @decreaseCapital.
  ///
  /// In en, this message translates to:
  /// **'Decrease Capital'**
  String get decreaseCapital;

  /// No description provided for @capitalIncrease.
  ///
  /// In en, this message translates to:
  /// **'Capital Increase'**
  String get capitalIncrease;

  /// No description provided for @capitalDecrease.
  ///
  /// In en, this message translates to:
  /// **'Capital Decrease'**
  String get capitalDecrease;

  /// No description provided for @paymentMode.
  ///
  /// In en, this message translates to:
  /// **'Payment Mode'**
  String get paymentMode;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @airtelMoney.
  ///
  /// In en, this message translates to:
  /// **'Airtel Money'**
  String get airtelMoney;

  /// No description provided for @mPesa.
  ///
  /// In en, this message translates to:
  /// **'M-Pesa'**
  String get mPesa;

  /// No description provided for @orangeMoney.
  ///
  /// In en, this message translates to:
  /// **'Orange Money'**
  String get orangeMoney;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason is required'**
  String get reasonRequired;

  /// No description provided for @reasonMinLength.
  ///
  /// In en, this message translates to:
  /// **'Please provide a detailed reason (minimum 10 characters)'**
  String get reasonMinLength;

  /// No description provided for @detailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Detailed Description'**
  String get detailedDescription;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Additional context, decision reference, etc. (optional)'**
  String get descriptionOptional;

  /// No description provided for @currentCapital.
  ///
  /// In en, this message translates to:
  /// **'Current Capital'**
  String get currentCapital;

  /// No description provided for @totalCurrentCapital.
  ///
  /// In en, this message translates to:
  /// **'Total Current Capital'**
  String get totalCurrentCapital;

  /// No description provided for @adjustmentPreview.
  ///
  /// In en, this message translates to:
  /// **'Adjustment Preview'**
  String get adjustmentPreview;

  /// No description provided for @currentCapitalTotal.
  ///
  /// In en, this message translates to:
  /// **'Current total capital'**
  String get currentCapitalTotal;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @newCapital.
  ///
  /// In en, this message translates to:
  /// **'New Capital'**
  String get newCapital;

  /// No description provided for @newCapitalTotal.
  ///
  /// In en, this message translates to:
  /// **'New total capital'**
  String get newCapitalTotal;

  /// No description provided for @confirmAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Adjustment'**
  String get confirmAdjustment;

  /// No description provided for @capitalAdjustedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Capital adjustment recorded!'**
  String get capitalAdjustedSuccessfully;

  /// No description provided for @capitalUpdatedAndTracked.
  ///
  /// In en, this message translates to:
  /// **'Capital updated and tracked in audit log'**
  String get capitalUpdatedAndTracked;

  /// No description provided for @adjustmentError.
  ///
  /// In en, this message translates to:
  /// **'Error during adjustment'**
  String get adjustmentError;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @viewHistory.
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get viewHistory;

  /// No description provided for @adjustmentHistory.
  ///
  /// In en, this message translates to:
  /// **'Adjustment History'**
  String get adjustmentHistory;

  /// No description provided for @allCapitalAdjustments.
  ///
  /// In en, this message translates to:
  /// **'All Capital Adjustments'**
  String get allCapitalAdjustments;

  /// No description provided for @filterByPeriod.
  ///
  /// In en, this message translates to:
  /// **'Filter by period'**
  String get filterByPeriod;

  /// No description provided for @noAdjustmentsFound.
  ///
  /// In en, this message translates to:
  /// **'No capital adjustments found'**
  String get noAdjustmentsFound;

  /// No description provided for @before.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get before;

  /// No description provided for @after.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get after;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @auditId.
  ///
  /// In en, this message translates to:
  /// **'Audit ID'**
  String get auditId;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @by.
  ///
  /// In en, this message translates to:
  /// **'by'**
  String get by;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get on;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get selectDate;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @downloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Download successful'**
  String get downloadSuccess;

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Download error'**
  String get downloadError;

  /// No description provided for @downloadFromServer.
  ///
  /// In en, this message translates to:
  /// **'Download from server'**
  String get downloadFromServer;

  /// No description provided for @selectDataType.
  ///
  /// In en, this message translates to:
  /// **'Select the type of data to download'**
  String get selectDataType;

  /// No description provided for @downloadAllFees.
  ///
  /// In en, this message translates to:
  /// **'Download all FEES'**
  String get downloadAllFees;

  /// No description provided for @feesDescription.
  ///
  /// In en, this message translates to:
  /// **'Commissions and fees collected'**
  String get feesDescription;

  /// No description provided for @downloadAllExpenses.
  ///
  /// In en, this message translates to:
  /// **'Download all EXPENSES'**
  String get downloadAllExpenses;

  /// No description provided for @expensesDescription.
  ///
  /// In en, this message translates to:
  /// **'Expenses made by the agency'**
  String get expensesDescription;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get downloadAll;

  /// No description provided for @downloadAllDescription.
  ///
  /// In en, this message translates to:
  /// **'All special accounts (Fees and Expenses)'**
  String get downloadAllDescription;

  /// No description provided for @specialAccounts.
  ///
  /// In en, this message translates to:
  /// **'Special Accounts'**
  String get specialAccounts;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopName;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @shopLocation.
  ///
  /// In en, this message translates to:
  /// **'Shop Location'**
  String get shopLocation;

  /// No description provided for @additionToCapital.
  ///
  /// In en, this message translates to:
  /// **'Addition to Capital (Entry)'**
  String get additionToCapital;

  /// No description provided for @withdrawalFromCapital.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal from Capital (Exit)'**
  String get withdrawalFromCapital;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get amountRequired;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get invalidAmount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @exampleAmount.
  ///
  /// In en, this message translates to:
  /// **'Ex: 5000.00'**
  String get exampleAmount;

  /// No description provided for @capitalManagement.
  ///
  /// In en, this message translates to:
  /// **'Capital Management'**
  String get capitalManagement;

  /// No description provided for @noShopsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No shops available'**
  String get noShopsAvailable;

  /// No description provided for @totalAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Total Adjustments'**
  String get totalAdjustments;

  /// No description provided for @increases.
  ///
  /// In en, this message translates to:
  /// **'Increases'**
  String get increases;

  /// No description provided for @decreases.
  ///
  /// In en, this message translates to:
  /// **'Decreases'**
  String get decreases;

  /// No description provided for @netChange.
  ///
  /// In en, this message translates to:
  /// **'Net Change'**
  String get netChange;

  /// No description provided for @recentAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Recent Adjustments'**
  String get recentAdjustments;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @capitalize.
  ///
  /// In en, this message translates to:
  /// **'Capitalize'**
  String get capitalize;

  /// No description provided for @userNotConnected.
  ///
  /// In en, this message translates to:
  /// **'User not connected'**
  String get userNotConnected;

  /// No description provided for @shopManagement.
  ///
  /// In en, this message translates to:
  /// **'Shop Management'**
  String get shopManagement;

  /// No description provided for @shopsManagement.
  ///
  /// In en, this message translates to:
  /// **'Shops Management'**
  String get shopsManagement;

  /// No description provided for @newShop.
  ///
  /// In en, this message translates to:
  /// **'New Shop'**
  String get newShop;

  /// No description provided for @editShop.
  ///
  /// In en, this message translates to:
  /// **'Edit Shop'**
  String get editShop;

  /// No description provided for @deleteShop.
  ///
  /// In en, this message translates to:
  /// **'Delete Shop'**
  String get deleteShop;

  /// No description provided for @shopDetails.
  ///
  /// In en, this message translates to:
  /// **'Shop Details'**
  String get shopDetails;

  /// No description provided for @shopInformation.
  ///
  /// In en, this message translates to:
  /// **'Shop Information'**
  String get shopInformation;

  /// No description provided for @designation.
  ///
  /// In en, this message translates to:
  /// **'Designation'**
  String get designation;

  /// No description provided for @designationRequired.
  ///
  /// In en, this message translates to:
  /// **'Designation is required'**
  String get designationRequired;

  /// No description provided for @designationMinLength.
  ///
  /// In en, this message translates to:
  /// **'Designation must contain at least 3 characters'**
  String get designationMinLength;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location is required'**
  String get locationRequired;

  /// No description provided for @capitalByType.
  ///
  /// In en, this message translates to:
  /// **'Capital by Cash Type (USD)'**
  String get capitalByType;

  /// No description provided for @capitalCash.
  ///
  /// In en, this message translates to:
  /// **'Cash Capital'**
  String get capitalCash;

  /// No description provided for @capitalCashRequired.
  ///
  /// In en, this message translates to:
  /// **'Cash capital is required'**
  String get capitalCashRequired;

  /// No description provided for @capitalMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Capital must be a positive number or zero'**
  String get capitalMustBePositive;

  /// No description provided for @capitalAirtelMoney.
  ///
  /// In en, this message translates to:
  /// **'Airtel Money Capital'**
  String get capitalAirtelMoney;

  /// No description provided for @capitalMPesa.
  ///
  /// In en, this message translates to:
  /// **'M-Pesa Capital'**
  String get capitalMPesa;

  /// No description provided for @capitalOrangeMoney.
  ///
  /// In en, this message translates to:
  /// **'Orange Money Capital'**
  String get capitalOrangeMoney;

  /// No description provided for @totalCapital.
  ///
  /// In en, this message translates to:
  /// **'Total Capital'**
  String get totalCapital;

  /// No description provided for @averageCapital.
  ///
  /// In en, this message translates to:
  /// **'Average Capital'**
  String get averageCapital;

  /// No description provided for @activeShops.
  ///
  /// In en, this message translates to:
  /// **'Active Shops'**
  String get activeShops;

  /// No description provided for @totalShops.
  ///
  /// In en, this message translates to:
  /// **'Total Shops'**
  String get totalShops;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creating;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updating;

  /// No description provided for @createShop.
  ///
  /// In en, this message translates to:
  /// **'Create Shop'**
  String get createShop;

  /// No description provided for @updateShop.
  ///
  /// In en, this message translates to:
  /// **'Update Shop'**
  String get updateShop;

  /// No description provided for @shopCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Shop created successfully!'**
  String get shopCreatedSuccessfully;

  /// No description provided for @shopUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Shop updated successfully!'**
  String get shopUpdatedSuccessfully;

  /// No description provided for @shopDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Shop deleted successfully!'**
  String get shopDeletedSuccessfully;

  /// No description provided for @errorCreatingShop.
  ///
  /// In en, this message translates to:
  /// **'Error creating shop'**
  String get errorCreatingShop;

  /// No description provided for @errorUpdatingShop.
  ///
  /// In en, this message translates to:
  /// **'Error updating shop'**
  String get errorUpdatingShop;

  /// No description provided for @errorDeletingShop.
  ///
  /// In en, this message translates to:
  /// **'Error deleting shop'**
  String get errorDeletingShop;

  /// No description provided for @confirmDeleteShop.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this shop?'**
  String get confirmDeleteShop;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get thisActionCannotBeUndone;

  /// No description provided for @shopHasAgents.
  ///
  /// In en, this message translates to:
  /// **'This shop has agents assigned to it.'**
  String get shopHasAgents;

  /// No description provided for @allAgentsWillBeUnassigned.
  ///
  /// In en, this message translates to:
  /// **'All agents will be unassigned.'**
  String get allAgentsWillBeUnassigned;

  /// No description provided for @noShopsFound.
  ///
  /// In en, this message translates to:
  /// **'No shops found'**
  String get noShopsFound;

  /// No description provided for @createFirstShop.
  ///
  /// In en, this message translates to:
  /// **'Create your first shop to get started'**
  String get createFirstShop;

  /// No description provided for @clickNewShopToCreate.
  ///
  /// In en, this message translates to:
  /// **'Click on \'New Shop\' to create your first shop'**
  String get clickNewShopToCreate;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @agentsCount.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsCount;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @primaryCurrency.
  ///
  /// In en, this message translates to:
  /// **'Primary Currency'**
  String get primaryCurrency;

  /// No description provided for @secondaryCurrency.
  ///
  /// In en, this message translates to:
  /// **'Secondary Currency'**
  String get secondaryCurrency;

  /// No description provided for @initialCapital.
  ///
  /// In en, this message translates to:
  /// **'Initial Capital'**
  String get initialCapital;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debts;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @lastModified.
  ///
  /// In en, this message translates to:
  /// **'Last Modified'**
  String get lastModified;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get createdAt;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @notSynced.
  ///
  /// In en, this message translates to:
  /// **'Not Synced'**
  String get notSynced;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'Sync Pending'**
  String get syncPending;

  /// No description provided for @agentsManagement.
  ///
  /// In en, this message translates to:
  /// **'Agents Management'**
  String get agentsManagement;

  /// No description provided for @newAgent.
  ///
  /// In en, this message translates to:
  /// **'New Agent'**
  String get newAgent;

  /// No description provided for @editAgent.
  ///
  /// In en, this message translates to:
  /// **'Edit Agent'**
  String get editAgent;

  /// No description provided for @deleteAgent.
  ///
  /// In en, this message translates to:
  /// **'Delete Agent'**
  String get deleteAgent;

  /// No description provided for @agentDetails.
  ///
  /// In en, this message translates to:
  /// **'Agent Details'**
  String get agentDetails;

  /// No description provided for @totalAgents.
  ///
  /// In en, this message translates to:
  /// **'Total Agents'**
  String get totalAgents;

  /// No description provided for @activeAgents.
  ///
  /// In en, this message translates to:
  /// **'Active Agents'**
  String get activeAgents;

  /// No description provided for @inactiveAgents.
  ///
  /// In en, this message translates to:
  /// **'Inactive Agents'**
  String get inactiveAgents;

  /// No description provided for @verifyAdmin.
  ///
  /// In en, this message translates to:
  /// **'Verify Admin'**
  String get verifyAdmin;

  /// No description provided for @createTestAgents.
  ///
  /// In en, this message translates to:
  /// **'Create Test Agents'**
  String get createTestAgents;

  /// No description provided for @debugInfo.
  ///
  /// In en, this message translates to:
  /// **'Debug Info'**
  String get debugInfo;

  /// No description provided for @agentInformation.
  ///
  /// In en, this message translates to:
  /// **'Agent Information'**
  String get agentInformation;

  /// No description provided for @assignedShop.
  ///
  /// In en, this message translates to:
  /// **'Assigned Shop'**
  String get assignedShop;

  /// No description provided for @shopRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a shop'**
  String get shopRequired;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @usernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must contain at least 3 characters'**
  String get usernameMinLength;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Full name (optional)'**
  String get fullNameOptional;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone number (optional)'**
  String get phoneOptional;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @agentActivated.
  ///
  /// In en, this message translates to:
  /// **'Agent activated successfully'**
  String get agentActivated;

  /// No description provided for @agentDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Agent deactivated successfully'**
  String get agentDeactivated;

  /// No description provided for @agentCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Agent created successfully!'**
  String get agentCreatedSuccessfully;

  /// No description provided for @agentUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Agent updated successfully!'**
  String get agentUpdatedSuccessfully;

  /// No description provided for @agentDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Agent deleted successfully!'**
  String get agentDeletedSuccessfully;

  /// No description provided for @errorCreatingAgent.
  ///
  /// In en, this message translates to:
  /// **'Error creating agent'**
  String get errorCreatingAgent;

  /// No description provided for @errorUpdatingAgent.
  ///
  /// In en, this message translates to:
  /// **'Error updating agent'**
  String get errorUpdatingAgent;

  /// No description provided for @errorDeletingAgent.
  ///
  /// In en, this message translates to:
  /// **'Error deleting agent'**
  String get errorDeletingAgent;

  /// No description provided for @confirmDeleteAgent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this agent?'**
  String get confirmDeleteAgent;

  /// No description provided for @noAgentsFound.
  ///
  /// In en, this message translates to:
  /// **'No agents found'**
  String get noAgentsFound;

  /// No description provided for @createFirstAgent.
  ///
  /// In en, this message translates to:
  /// **'Create your first agent to get started'**
  String get createFirstAgent;

  /// No description provided for @exampleUsername.
  ///
  /// In en, this message translates to:
  /// **'Ex: agent1'**
  String get exampleUsername;

  /// No description provided for @minimumCharacters.
  ///
  /// In en, this message translates to:
  /// **'Minimum {count} characters'**
  String minimumCharacters(int count);

  /// No description provided for @noShopAssigned.
  ///
  /// In en, this message translates to:
  /// **'No shop assigned'**
  String get noShopAssigned;

  /// No description provided for @adminExists.
  ///
  /// In en, this message translates to:
  /// **'Admin exists'**
  String get adminExists;

  /// No description provided for @adminNotFound.
  ///
  /// In en, this message translates to:
  /// **'Admin not found'**
  String get adminNotFound;

  /// No description provided for @adminWillBeRecreated.
  ///
  /// In en, this message translates to:
  /// **'Admin will be automatically recreated.'**
  String get adminWillBeRecreated;

  /// No description provided for @agentRole.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentRole;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminRole;

  /// No description provided for @createTestAgentsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to create 2 test agents to verify the system?'**
  String get createTestAgentsConfirm;

  /// No description provided for @agentsToBeCreated.
  ///
  /// In en, this message translates to:
  /// **'Agents to be created:'**
  String get agentsToBeCreated;

  /// No description provided for @testAgentsCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Test agents created successfully!'**
  String get testAgentsCreatedSuccess;

  /// No description provided for @debugInfoInConsole.
  ///
  /// In en, this message translates to:
  /// **'Debug information displayed in console...'**
  String get debugInfoInConsole;

  /// No description provided for @openConsoleF12.
  ///
  /// In en, this message translates to:
  /// **'Open the console (F12) to see details.'**
  String get openConsoleF12;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @searchAgent.
  ///
  /// In en, this message translates to:
  /// **'Search for an agent...'**
  String get searchAgent;

  /// No description provided for @filterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by Status'**
  String get filterByStatus;

  /// No description provided for @allAgents.
  ///
  /// In en, this message translates to:
  /// **'All agents'**
  String get allAgents;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noAgentFound.
  ///
  /// In en, this message translates to:
  /// **'No agent found with these criteria'**
  String get noAgentFound;

  /// No description provided for @clickNewAgentToCreate.
  ///
  /// In en, this message translates to:
  /// **'Click on \"New Agent\" to create an agent'**
  String get clickNewAgentToCreate;

  /// No description provided for @createAnAgent.
  ///
  /// In en, this message translates to:
  /// **'Create an Agent'**
  String get createAnAgent;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @agentsStatistics.
  ///
  /// In en, this message translates to:
  /// **'Agents Statistics'**
  String get agentsStatistics;

  /// No description provided for @withAgents.
  ///
  /// In en, this message translates to:
  /// **'With Agents'**
  String get withAgents;

  /// No description provided for @withoutAgents.
  ///
  /// In en, this message translates to:
  /// **'Without Agents'**
  String get withoutAgents;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @adminReports.
  ///
  /// In en, this message translates to:
  /// **'Admin Reports'**
  String get adminReports;

  /// No description provided for @adminReportsLong.
  ///
  /// In en, this message translates to:
  /// **'Administrator Reports'**
  String get adminReportsLong;

  /// No description provided for @analysisAndPerformanceTracking.
  ///
  /// In en, this message translates to:
  /// **'Analysis and performance tracking'**
  String get analysisAndPerformanceTracking;

  /// No description provided for @advancedDashboards.
  ///
  /// In en, this message translates to:
  /// **'Advanced dashboards'**
  String get advancedDashboards;

  /// No description provided for @companyNetPosition.
  ///
  /// In en, this message translates to:
  /// **'Company Net Position'**
  String get companyNetPosition;

  /// No description provided for @cashMovements.
  ///
  /// In en, this message translates to:
  /// **'Cash Movements'**
  String get cashMovements;

  /// No description provided for @dailyClosure.
  ///
  /// In en, this message translates to:
  /// **'Daily Closure'**
  String get dailyClosure;

  /// No description provided for @closureHistory.
  ///
  /// In en, this message translates to:
  /// **'Closure History'**
  String get closureHistory;

  /// No description provided for @commissionsReport.
  ///
  /// In en, this message translates to:
  /// **'Commissions'**
  String get commissionsReport;

  /// No description provided for @interShopCredits.
  ///
  /// In en, this message translates to:
  /// **'Inter-Shop Credits'**
  String get interShopCredits;

  /// No description provided for @interShopDebts.
  ///
  /// In en, this message translates to:
  /// **'Intershop Debts'**
  String get interShopDebts;

  /// No description provided for @flotMovements.
  ///
  /// In en, this message translates to:
  /// **'FLOT Movements'**
  String get flotMovements;

  /// No description provided for @shopSelected.
  ///
  /// In en, this message translates to:
  /// **'Shop selected'**
  String get shopSelected;

  /// No description provided for @useFilterAbove.
  ///
  /// In en, this message translates to:
  /// **'Use the filter above to select a specific shop'**
  String get useFilterAbove;

  /// No description provided for @dailyClosureRequiresShop.
  ///
  /// In en, this message translates to:
  /// **'Daily closure requires a specific shop'**
  String get dailyClosureRequiresShop;

  /// No description provided for @enterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get enterprise;

  /// No description provided for @cashRegister.
  ///
  /// In en, this message translates to:
  /// **'Cash Register'**
  String get cashRegister;

  /// No description provided for @closure.
  ///
  /// In en, this message translates to:
  /// **'Closure'**
  String get closure;

  /// No description provided for @closures.
  ///
  /// In en, this message translates to:
  /// **'Closures'**
  String get closures;

  /// No description provided for @previousFees.
  ///
  /// In en, this message translates to:
  /// **'Previous Fees'**
  String get previousFees;

  /// No description provided for @feesCollected.
  ///
  /// In en, this message translates to:
  /// **'Fees Collected'**
  String get feesCollected;

  /// No description provided for @feesWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Fees Withdrawn'**
  String get feesWithdrawn;

  /// No description provided for @totalFeesCollected.
  ///
  /// In en, this message translates to:
  /// **'Total Fees Collected'**
  String get totalFeesCollected;

  /// No description provided for @totalFeesWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Total Fees Withdrawn'**
  String get totalFeesWithdrawn;

  /// No description provided for @previousExpenses.
  ///
  /// In en, this message translates to:
  /// **'Previous Expenses'**
  String get previousExpenses;

  /// No description provided for @deposits.
  ///
  /// In en, this message translates to:
  /// **'Deposits'**
  String get deposits;

  /// No description provided for @withdrawals.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals'**
  String get withdrawals;

  /// No description provided for @totalDeposits.
  ///
  /// In en, this message translates to:
  /// **'Total Deposits'**
  String get totalDeposits;

  /// No description provided for @totalWithdrawals.
  ///
  /// In en, this message translates to:
  /// **'Total Withdrawals'**
  String get totalWithdrawals;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @exportToPdf.
  ///
  /// In en, this message translates to:
  /// **'Export to PDF'**
  String get exportToPdf;

  /// No description provided for @newEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get newEntry;

  /// No description provided for @newExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get newExpense;

  /// No description provided for @newWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'New withdrawal'**
  String get newWithdrawal;

  /// No description provided for @loadingError.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get loadingError;

  /// No description provided for @operationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get operationSuccess;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm action'**
  String get confirmAction;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get allTypes;

  /// No description provided for @advancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get advancedFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @allOperations.
  ///
  /// In en, this message translates to:
  /// **'All operations'**
  String get allOperations;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @loadingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Loading in progress...'**
  String get loadingInProgress;

  /// No description provided for @dataLoadingError.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get dataLoadingError;

  /// No description provided for @feesAccount.
  ///
  /// In en, this message translates to:
  /// **'FEES Account'**
  String get feesAccount;

  /// No description provided for @expenseAccount.
  ///
  /// In en, this message translates to:
  /// **'EXPENSE Account'**
  String get expenseAccount;

  /// No description provided for @netProfit.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get netProfit;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get availableBalance;

  /// No description provided for @statement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get statement;

  /// No description provided for @transactionsCount.
  ///
  /// In en, this message translates to:
  /// **'Number of transactions'**
  String get transactionsCount;

  /// No description provided for @clientCommissions.
  ///
  /// In en, this message translates to:
  /// **'Client commissions'**
  String get clientCommissions;

  /// No description provided for @bossWithdrawals.
  ///
  /// In en, this message translates to:
  /// **'Boss withdrawals'**
  String get bossWithdrawals;

  /// No description provided for @bossDeposits.
  ///
  /// In en, this message translates to:
  /// **'Boss deposits'**
  String get bossDeposits;

  /// No description provided for @expensesOutflows.
  ///
  /// In en, this message translates to:
  /// **'Expenses outflows'**
  String get expensesOutflows;

  /// No description provided for @transactionsDetails.
  ///
  /// In en, this message translates to:
  /// **'Transactions details'**
  String get transactionsDetails;

  /// No description provided for @noTransactionsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No transactions for this period'**
  String get noTransactionsForPeriod;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @totalIn.
  ///
  /// In en, this message translates to:
  /// **'Total inflows'**
  String get totalIn;

  /// No description provided for @totalOut.
  ///
  /// In en, this message translates to:
  /// **'Total outflows'**
  String get totalOut;

  /// No description provided for @feesTotal.
  ///
  /// In en, this message translates to:
  /// **'Total fees'**
  String get feesTotal;

  /// No description provided for @transfersDetails.
  ///
  /// In en, this message translates to:
  /// **'Transfer details'**
  String get transfersDetails;

  /// No description provided for @noRoutesFound.
  ///
  /// In en, this message translates to:
  /// **'No route found'**
  String get noRoutesFound;

  /// No description provided for @noFeesCollected.
  ///
  /// In en, this message translates to:
  /// **'No fees collected'**
  String get noFeesCollected;

  /// No description provided for @noServedTransfers.
  ///
  /// In en, this message translates to:
  /// **'No served transfers'**
  String get noServedTransfers;

  /// No description provided for @feesWillAppearWhenServingTransfers.
  ///
  /// In en, this message translates to:
  /// **'Fees will appear here when you serve transfers'**
  String get feesWillAppearWhenServingTransfers;

  /// No description provided for @nationalTransfer.
  ///
  /// In en, this message translates to:
  /// **'National transfer'**
  String get nationalTransfer;

  /// No description provided for @internationalIncomingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Incoming international transfer'**
  String get internationalIncomingTransfer;

  /// No description provided for @internationalOutgoingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Outgoing international transfer'**
  String get internationalOutgoingTransfer;

  /// No description provided for @personnel.
  ///
  /// In en, this message translates to:
  /// **'Personnel'**
  String get personnel;

  /// No description provided for @personnelManagement.
  ///
  /// In en, this message translates to:
  /// **'Personnel Management'**
  String get personnelManagement;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @salaries.
  ///
  /// In en, this message translates to:
  /// **'Salaries'**
  String get salaries;

  /// No description provided for @advances.
  ///
  /// In en, this message translates to:
  /// **'Advances'**
  String get advances;

  /// No description provided for @payslips.
  ///
  /// In en, this message translates to:
  /// **'Payslips'**
  String get payslips;

  /// No description provided for @monthlyReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly Report'**
  String get monthlyReport;

  /// No description provided for @paymentReport.
  ///
  /// In en, this message translates to:
  /// **'Payment Report'**
  String get paymentReport;

  /// No description provided for @matricule.
  ///
  /// In en, this message translates to:
  /// **'ID Number'**
  String get matricule;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDate;

  /// No description provided for @birthPlace.
  ///
  /// In en, this message translates to:
  /// **'Birth Place'**
  String get birthPlace;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @maritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Marital Status'**
  String get maritalStatus;

  /// No description provided for @numberOfChildren.
  ///
  /// In en, this message translates to:
  /// **'Number of Children'**
  String get numberOfChildren;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @contractType.
  ///
  /// In en, this message translates to:
  /// **'Contract Type'**
  String get contractType;

  /// No description provided for @hireDate.
  ///
  /// In en, this message translates to:
  /// **'Hire Date'**
  String get hireDate;

  /// No description provided for @contractEndDate.
  ///
  /// In en, this message translates to:
  /// **'Contract End Date'**
  String get contractEndDate;

  /// No description provided for @baseSalary.
  ///
  /// In en, this message translates to:
  /// **'Base Salary'**
  String get baseSalary;

  /// No description provided for @transportAllowance.
  ///
  /// In en, this message translates to:
  /// **'Transport Allowance'**
  String get transportAllowance;

  /// No description provided for @housingAllowance.
  ///
  /// In en, this message translates to:
  /// **'Housing Allowance'**
  String get housingAllowance;

  /// No description provided for @positionAllowance.
  ///
  /// In en, this message translates to:
  /// **'Position Allowance'**
  String get positionAllowance;

  /// No description provided for @otherAllowances.
  ///
  /// In en, this message translates to:
  /// **'Other Allowances'**
  String get otherAllowances;

  /// No description provided for @overtime.
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get overtime;

  /// No description provided for @bonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get bonus;

  /// No description provided for @grossSalary.
  ///
  /// In en, this message translates to:
  /// **'Gross Salary'**
  String get grossSalary;

  /// No description provided for @netSalary.
  ///
  /// In en, this message translates to:
  /// **'Net Salary'**
  String get netSalary;

  /// No description provided for @deductions.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get deductions;

  /// No description provided for @totalDeductions.
  ///
  /// In en, this message translates to:
  /// **'Total Deductions'**
  String get totalDeductions;

  /// No description provided for @advancesDeducted.
  ///
  /// In en, this message translates to:
  /// **'Advances Deducted'**
  String get advancesDeducted;

  /// No description provided for @creditsDeducted.
  ///
  /// In en, this message translates to:
  /// **'Credits Deducted'**
  String get creditsDeducted;

  /// No description provided for @taxes.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get taxes;

  /// No description provided for @cnssContribution.
  ///
  /// In en, this message translates to:
  /// **'CNSS Contribution'**
  String get cnssContribution;

  /// No description provided for @otherDeductions.
  ///
  /// In en, this message translates to:
  /// **'Other Deductions'**
  String get otherDeductions;

  /// No description provided for @suspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspended;

  /// No description provided for @onLeave.
  ///
  /// In en, this message translates to:
  /// **'On Leave'**
  String get onLeave;

  /// No description provided for @resigned.
  ///
  /// In en, this message translates to:
  /// **'Resigned'**
  String get resigned;

  /// No description provided for @terminated.
  ///
  /// In en, this message translates to:
  /// **'Terminated'**
  String get terminated;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add Employee'**
  String get addEmployee;

  /// No description provided for @editEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get editEmployee;

  /// No description provided for @deleteEmployee.
  ///
  /// In en, this message translates to:
  /// **'Delete Employee'**
  String get deleteEmployee;

  /// No description provided for @employeeDetails.
  ///
  /// In en, this message translates to:
  /// **'Employee Details'**
  String get employeeDetails;

  /// No description provided for @noEmployeesFound.
  ///
  /// In en, this message translates to:
  /// **'No employees found'**
  String get noEmployeesFound;

  /// No description provided for @addFirstEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add your first employee'**
  String get addFirstEmployee;

  /// No description provided for @generateSalaries.
  ///
  /// In en, this message translates to:
  /// **'Generate Salaries'**
  String get generateSalaries;

  /// No description provided for @generateMonthly.
  ///
  /// In en, this message translates to:
  /// **'Generate Monthly'**
  String get generateMonthly;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @advanceAmount.
  ///
  /// In en, this message translates to:
  /// **'Advance Amount'**
  String get advanceAmount;

  /// No description provided for @reimbursedAmount.
  ///
  /// In en, this message translates to:
  /// **'Reimbursed Amount'**
  String get reimbursedAmount;

  /// No description provided for @remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'Remaining Amount'**
  String get remainingAmount;

  /// No description provided for @repaymentMode.
  ///
  /// In en, this message translates to:
  /// **'Repayment Mode'**
  String get repaymentMode;

  /// No description provided for @repaymentDuration.
  ///
  /// In en, this message translates to:
  /// **'Repayment Duration'**
  String get repaymentDuration;

  /// No description provided for @monthlyPayment.
  ///
  /// In en, this message translates to:
  /// **'Monthly Payment'**
  String get monthlyPayment;

  /// No description provided for @creditAmount.
  ///
  /// In en, this message translates to:
  /// **'Credit Amount'**
  String get creditAmount;

  /// No description provided for @interestRate.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate'**
  String get interestRate;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @totalToReimburse.
  ///
  /// In en, this message translates to:
  /// **'Total to Reimburse'**
  String get totalToReimburse;

  /// No description provided for @grantDate.
  ///
  /// In en, this message translates to:
  /// **'Grant Date'**
  String get grantDate;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @payslip.
  ///
  /// In en, this message translates to:
  /// **'Payslip'**
  String get payslip;

  /// No description provided for @generatePayslip.
  ///
  /// In en, this message translates to:
  /// **'Generate Payslip'**
  String get generatePayslip;

  /// No description provided for @downloadPDF.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPDF;

  /// No description provided for @payslipFor.
  ///
  /// In en, this message translates to:
  /// **'Payslip for'**
  String get payslipFor;

  /// No description provided for @monthlyPaymentReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly Payment Report'**
  String get monthlyPaymentReport;

  /// No description provided for @financialSummary.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financialSummary;

  /// No description provided for @employeeCount.
  ///
  /// In en, this message translates to:
  /// **'Employee Count'**
  String get employeeCount;

  /// No description provided for @paidCount.
  ///
  /// In en, this message translates to:
  /// **'Paid Count'**
  String get paidCount;

  /// No description provided for @totalGross.
  ///
  /// In en, this message translates to:
  /// **'Total Gross'**
  String get totalGross;

  /// No description provided for @totalNet.
  ///
  /// In en, this message translates to:
  /// **'Total Net'**
  String get totalNet;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// No description provided for @amountUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Unpaid'**
  String get amountUnpaid;

  /// No description provided for @detailByEmployee.
  ///
  /// In en, this message translates to:
  /// **'Detail by Employee'**
  String get detailByEmployee;

  /// No description provided for @makePayment.
  ///
  /// In en, this message translates to:
  /// **'Make Payment'**
  String get makePayment;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @mobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoney;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @professionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Professional Information'**
  String get professionalInfo;

  /// No description provided for @salaryInfo.
  ///
  /// In en, this message translates to:
  /// **'Salary Information'**
  String get salaryInfo;

  /// No description provided for @searchEmployee.
  ///
  /// In en, this message translates to:
  /// **'Search (name, ID, phone...)'**
  String get searchEmployee;

  /// No description provided for @filterByPosition.
  ///
  /// In en, this message translates to:
  /// **'Filter by Position'**
  String get filterByPosition;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @activeEmployees.
  ///
  /// In en, this message translates to:
  /// **'Active Employees'**
  String get activeEmployees;

  /// No description provided for @totalEmployees.
  ///
  /// In en, this message translates to:
  /// **'Total Employees'**
  String get totalEmployees;

  /// No description provided for @monthlyPayroll.
  ///
  /// In en, this message translates to:
  /// **'Monthly Payroll'**
  String get monthlyPayroll;

  /// No description provided for @byStatus.
  ///
  /// In en, this message translates to:
  /// **'By Status'**
  String get byStatus;

  /// No description provided for @employeeCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Employee created successfully'**
  String get employeeCreatedSuccess;

  /// No description provided for @employeeUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Employee updated successfully'**
  String get employeeUpdatedSuccess;

  /// No description provided for @employeeDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Employee deleted successfully'**
  String get employeeDeletedSuccess;

  /// No description provided for @salaryGeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Salary generated successfully'**
  String get salaryGeneratedSuccess;

  /// No description provided for @paymentRecordedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded successfully'**
  String get paymentRecordedSuccess;

  /// No description provided for @confirmGenerate.
  ///
  /// In en, this message translates to:
  /// **'Do you want to generate salaries for all active employees?'**
  String get confirmGenerate;

  /// No description provided for @confirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get confirmPayment;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @closureReport.
  ///
  /// In en, this message translates to:
  /// **'Closure Report'**
  String get closureReport;

  /// No description provided for @dailyClosureReport.
  ///
  /// In en, this message translates to:
  /// **'Daily Closure Report'**
  String get dailyClosureReport;

  /// No description provided for @generateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get generateReport;

  /// No description provided for @reportDate.
  ///
  /// In en, this message translates to:
  /// **'Report date'**
  String get reportDate;

  /// No description provided for @previousBalance.
  ///
  /// In en, this message translates to:
  /// **'Previous Balance'**
  String get previousBalance;

  /// No description provided for @transfersReceived.
  ///
  /// In en, this message translates to:
  /// **'Transfers Received'**
  String get transfersReceived;

  /// No description provided for @transfersServed.
  ///
  /// In en, this message translates to:
  /// **'Transfers Served'**
  String get transfersServed;

  /// No description provided for @feesWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Fees Withdrawal'**
  String get feesWithdrawal;

  /// No description provided for @detailByShop.
  ///
  /// In en, this message translates to:
  /// **'Detail by Shop'**
  String get detailByShop;

  /// No description provided for @dailyFeesBalance.
  ///
  /// In en, this message translates to:
  /// **'Daily Fees Balance'**
  String get dailyFeesBalance;

  /// No description provided for @servedPartners.
  ///
  /// In en, this message translates to:
  /// **'Served Partners'**
  String get servedPartners;

  /// No description provided for @partnersDeposits.
  ///
  /// In en, this message translates to:
  /// **'Partners Deposits'**
  String get partnersDeposits;

  /// No description provided for @shopsWeOwe.
  ///
  /// In en, this message translates to:
  /// **'Shops We Owe'**
  String get shopsWeOwe;

  /// No description provided for @shopsOwingUs.
  ///
  /// In en, this message translates to:
  /// **'Shops Owing Us'**
  String get shopsOwingUs;

  /// No description provided for @totalIntershopDebts.
  ///
  /// In en, this message translates to:
  /// **'Total Intershop Debts'**
  String get totalIntershopDebts;

  /// No description provided for @noPartnerOperations.
  ///
  /// In en, this message translates to:
  /// **'No partner operations found for this day'**
  String get noPartnerOperations;

  /// No description provided for @previewPdf.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewPdf;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @printReport.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printReport;

  /// No description provided for @confirmPrint.
  ///
  /// In en, this message translates to:
  /// **'Confirm printing'**
  String get confirmPrint;

  /// No description provided for @printingLaunched.
  ///
  /// In en, this message translates to:
  /// **'Printing launched successfully'**
  String get printingLaunched;

  /// No description provided for @reportFor.
  ///
  /// In en, this message translates to:
  /// **'Report for'**
  String get reportFor;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @usePreviewBeforePrinting.
  ///
  /// In en, this message translates to:
  /// **'Use \"Preview\" to see the content before printing'**
  String get usePreviewBeforePrinting;

  /// No description provided for @noReportAvailable.
  ///
  /// In en, this message translates to:
  /// **'No report available'**
  String get noReportAvailable;

  /// No description provided for @generatingReport.
  ///
  /// In en, this message translates to:
  /// **'Generating report...'**
  String get generatingReport;

  /// No description provided for @refreshReport.
  ///
  /// In en, this message translates to:
  /// **'Refresh Report'**
  String get refreshReport;

  /// No description provided for @pdfGeneratedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'PDF generated successfully'**
  String get pdfGeneratedSuccessfully;

  /// No description provided for @pdfError.
  ///
  /// In en, this message translates to:
  /// **'PDF Error'**
  String get pdfError;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @debtor.
  ///
  /// In en, this message translates to:
  /// **'Debtor'**
  String get debtor;

  /// No description provided for @creditor.
  ///
  /// In en, this message translates to:
  /// **'Creditor'**
  String get creditor;

  /// No description provided for @installApp.
  ///
  /// In en, this message translates to:
  /// **'Install App'**
  String get installApp;

  /// No description provided for @installUcashApp.
  ///
  /// In en, this message translates to:
  /// **'Install UCASH App'**
  String get installUcashApp;

  /// No description provided for @installPwaDescription.
  ///
  /// In en, this message translates to:
  /// **'Install UCASH on your device for quick access, offline support, and a native app experience'**
  String get installPwaDescription;

  /// No description provided for @installPwaTitle.
  ///
  /// In en, this message translates to:
  /// **'Install Application'**
  String get installPwaTitle;

  /// No description provided for @installPwaMessage.
  ///
  /// In en, this message translates to:
  /// **'Install UCASH for better performance and offline access'**
  String get installPwaMessage;

  /// No description provided for @pwaInstallSuccess.
  ///
  /// In en, this message translates to:
  /// **'Application ready to install!'**
  String get pwaInstallSuccess;

  /// No description provided for @pwaNotSupported.
  ///
  /// In en, this message translates to:
  /// **'PWA installation not supported on this device'**
  String get pwaNotSupported;

  /// No description provided for @pwaAlreadyInstalled.
  ///
  /// In en, this message translates to:
  /// **'Application already installed'**
  String get pwaAlreadyInstalled;

  /// No description provided for @installNow.
  ///
  /// In en, this message translates to:
  /// **'Install Now'**
  String get installNow;

  /// No description provided for @alreadyInstalled.
  ///
  /// In en, this message translates to:
  /// **'Already Installed'**
  String get alreadyInstalled;

  /// No description provided for @workOffline.
  ///
  /// In en, this message translates to:
  /// **'Work Offline'**
  String get workOffline;

  /// No description provided for @fastAccess.
  ///
  /// In en, this message translates to:
  /// **'Fast Access'**
  String get fastAccess;

  /// No description provided for @likeNativeApp.
  ///
  /// In en, this message translates to:
  /// **'Like a Native App'**
  String get likeNativeApp;

  /// No description provided for @intershopDebtsMovements.
  ///
  /// In en, this message translates to:
  /// **'Intershop Debts Movements'**
  String get intershopDebtsMovements;

  /// No description provided for @intershopDebtsReport.
  ///
  /// In en, this message translates to:
  /// **'Intershop Debts Report'**
  String get intershopDebtsReport;

  /// No description provided for @totalReceivables.
  ///
  /// In en, this message translates to:
  /// **'Total Receivables'**
  String get totalReceivables;

  /// No description provided for @totalDebts.
  ///
  /// In en, this message translates to:
  /// **'Total Debts'**
  String get totalDebts;

  /// No description provided for @netBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get netBalance;

  /// No description provided for @movements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get movements;

  /// No description provided for @noIntershopDebt.
  ///
  /// In en, this message translates to:
  /// **'No intershop debt'**
  String get noIntershopDebt;

  /// No description provided for @noReceivablesOrDebtsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'This shop has neither receivables nor debts for the selected period'**
  String get noReceivablesOrDebtsForPeriod;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @periodSelection.
  ///
  /// In en, this message translates to:
  /// **'Period Selection'**
  String get periodSelection;

  /// No description provided for @generatePdf.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get generatePdf;

  /// No description provided for @dailyEvolution.
  ///
  /// In en, this message translates to:
  /// **'Daily Evolution'**
  String get dailyEvolution;

  /// No description provided for @movementDetails.
  ///
  /// In en, this message translates to:
  /// **'Movement Details'**
  String get movementDetails;

  /// No description provided for @errorGeneratingReport.
  ///
  /// In en, this message translates to:
  /// **'Error generating report'**
  String get errorGeneratingReport;

  /// No description provided for @totalOperations.
  ///
  /// In en, this message translates to:
  /// **'Total Operations'**
  String get totalOperations;

  /// No description provided for @clickForDetails.
  ///
  /// In en, this message translates to:
  /// **'Click for details'**
  String get clickForDetails;

  /// No description provided for @operation.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get operation;

  /// No description provided for @receivable.
  ///
  /// In en, this message translates to:
  /// **'Receivable'**
  String get receivable;

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get debt;

  /// No description provided for @previousDebt.
  ///
  /// In en, this message translates to:
  /// **'Previous Debt'**
  String get previousDebt;

  /// No description provided for @cumulativeBalance.
  ///
  /// In en, this message translates to:
  /// **'Cumulative Balance'**
  String get cumulativeBalance;

  /// No description provided for @dailyBalance.
  ///
  /// In en, this message translates to:
  /// **'Daily Balance'**
  String get dailyBalance;

  /// No description provided for @noMovementsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No movements for this period'**
  String get noMovementsForPeriod;

  /// No description provided for @showDailyEvolution.
  ///
  /// In en, this message translates to:
  /// **'Show daily evolution'**
  String get showDailyEvolution;

  /// No description provided for @hideDailyEvolution.
  ///
  /// In en, this message translates to:
  /// **'Hide daily evolution'**
  String get hideDailyEvolution;

  /// No description provided for @showMovementDetails.
  ///
  /// In en, this message translates to:
  /// **'Show movement details'**
  String get showMovementDetails;

  /// No description provided for @hideMovementDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide movement details'**
  String get hideMovementDetails;

  /// No description provided for @served.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get served;

  /// No description provided for @awaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting'**
  String get awaiting;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// No description provided for @groupByType.
  ///
  /// In en, this message translates to:
  /// **'Group by type'**
  String get groupByType;

  /// No description provided for @groupBySourceShop.
  ///
  /// In en, this message translates to:
  /// **'Group by source shop'**
  String get groupBySourceShop;

  /// No description provided for @groupByDestinationShop.
  ///
  /// In en, this message translates to:
  /// **'Group by destination shop'**
  String get groupByDestinationShop;

  /// No description provided for @transferServed.
  ///
  /// In en, this message translates to:
  /// **'Transfer served'**
  String get transferServed;

  /// No description provided for @transferPending.
  ///
  /// In en, this message translates to:
  /// **'Transfer pending'**
  String get transferPending;

  /// No description provided for @transferInitiated.
  ///
  /// In en, this message translates to:
  /// **'Transfer initiated'**
  String get transferInitiated;

  /// No description provided for @depositReceived.
  ///
  /// In en, this message translates to:
  /// **'Deposit received'**
  String get depositReceived;

  /// No description provided for @depositMade.
  ///
  /// In en, this message translates to:
  /// **'Deposit made'**
  String get depositMade;

  /// No description provided for @withdrawalServed.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal served'**
  String get withdrawalServed;

  /// No description provided for @withdrawalMade.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal made'**
  String get withdrawalMade;

  /// No description provided for @flotShopToShop.
  ///
  /// In en, this message translates to:
  /// **'FLOT shop-to-shop'**
  String get flotShopToShop;

  /// No description provided for @flotReceived.
  ///
  /// In en, this message translates to:
  /// **'FLOT received'**
  String get flotReceived;

  /// No description provided for @flotSent.
  ///
  /// In en, this message translates to:
  /// **'FLOT sent'**
  String get flotSent;

  /// No description provided for @shopToShopFlot.
  ///
  /// In en, this message translates to:
  /// **'Shop-to-shop FLOT'**
  String get shopToShopFlot;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @partnersNetPosition.
  ///
  /// In en, this message translates to:
  /// **'Partners Net Position'**
  String get partnersNetPosition;

  /// No description provided for @searchPartner.
  ///
  /// In en, this message translates to:
  /// **'Search for a partner (name, phone, account number)'**
  String get searchPartner;

  /// No description provided for @enterNamePhoneOrAccount.
  ///
  /// In en, this message translates to:
  /// **'Enter a name, phone or account number'**
  String get enterNamePhoneOrAccount;

  /// No description provided for @globalNetPosition.
  ///
  /// In en, this message translates to:
  /// **'Global Net Position'**
  String get globalNetPosition;

  /// No description provided for @theyOweUs.
  ///
  /// In en, this message translates to:
  /// **'They Owe Us'**
  String get theyOweUs;

  /// No description provided for @weOweThem.
  ///
  /// In en, this message translates to:
  /// **'We Owe Them'**
  String get weOweThem;

  /// No description provided for @netPosition.
  ///
  /// In en, this message translates to:
  /// **'Net Position'**
  String get netPosition;

  /// No description provided for @thoseWhoOweUs.
  ///
  /// In en, this message translates to:
  /// **'Those Who Owe Us'**
  String get thoseWhoOweUs;

  /// No description provided for @thoseWeOwe.
  ///
  /// In en, this message translates to:
  /// **'Those We Owe'**
  String get thoseWeOwe;

  /// No description provided for @noPartner.
  ///
  /// In en, this message translates to:
  /// **'No partner'**
  String get noPartner;

  /// No description provided for @inThisCategory.
  ///
  /// In en, this message translates to:
  /// **'in this category'**
  String get inThisCategory;

  /// No description provided for @trashBin.
  ///
  /// In en, this message translates to:
  /// **'Trash Bin'**
  String get trashBin;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get emptyTrash;

  /// No description provided for @restoreOperation.
  ///
  /// In en, this message translates to:
  /// **'Restore operation'**
  String get restoreOperation;

  /// No description provided for @restoreThisOperation.
  ///
  /// In en, this message translates to:
  /// **'Restore this operation'**
  String get restoreThisOperation;

  /// No description provided for @confirmRestore.
  ///
  /// In en, this message translates to:
  /// **'Confirm restoration of this operation?'**
  String get confirmRestore;

  /// No description provided for @operationRestored.
  ///
  /// In en, this message translates to:
  /// **'Operation restored successfully'**
  String get operationRestored;

  /// No description provided for @errorRestoring.
  ///
  /// In en, this message translates to:
  /// **'Error restoring operation'**
  String get errorRestoring;

  /// No description provided for @deletedOn.
  ///
  /// In en, this message translates to:
  /// **'Deleted on'**
  String get deletedOn;

  /// No description provided for @deletedBy.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get deletedBy;

  /// No description provided for @syncedOnServer.
  ///
  /// In en, this message translates to:
  /// **'Synced on server'**
  String get syncedOnServer;

  /// No description provided for @waitingForSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting for synchronization'**
  String get waitingForSync;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @grossAmount.
  ///
  /// In en, this message translates to:
  /// **'Gross amount'**
  String get grossAmount;

  /// No description provided for @netAmount.
  ///
  /// In en, this message translates to:
  /// **'Net amount'**
  String get netAmount;

  /// No description provided for @operationDate.
  ///
  /// In en, this message translates to:
  /// **'Operation date'**
  String get operationDate;

  /// No description provided for @deletionReason.
  ///
  /// In en, this message translates to:
  /// **'Deletion reason'**
  String get deletionReason;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
