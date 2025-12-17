import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Common translations
  String get appTitle => _getString('appTitle');
  String get welcome => _getString('welcome');
  String get login => _getString('login');
  String get logout => _getString('logout');
  String get username => _getString('username');
  String get password => _getString('password');
  String get enterUsername => _getString('enterUsername');
  String get enterPassword => _getString('enterPassword');
  String get forgotPassword => _getString('forgotPassword');
  String get rememberMe => _getString('rememberMe');
  String get dashboard => _getString('dashboard');
  String get operations => _getString('operations');
  String get clients => _getString('clients');
  String get agents => _getString('agents');
  String get shops => _getString('shops');
  String get reports => _getString('reports');
  String get settings => _getString('settings');
  String get synchronization => _getString('synchronization');
  String get deposit => _getString('deposit');
  String get withdrawal => _getString('withdrawal');
  String get transfer => _getString('transfer');
  String get payment => _getString('payment');
  String get amount => _getString('amount');
  String get balance => _getString('balance');
  String get commission => _getString('commission');
  String get total => _getString('total');
  String get date => _getString('date');
  String get status => _getString('status');
  String get reference => _getString('reference');
  String get pending => _getString('pending');
  String get completed => _getString('completed');
  String get cancelled => _getString('cancelled');
  String get failed => _getString('failed');
  String get search => _getString('search');
  String get filter => _getString('filter');
  String get export => _getString('export');
  String get print => _getString('print');
  String get refresh => _getString('refresh');
  String get add => _getString('add');
  String get edit => _getString('edit');
  String get delete => _getString('delete');
  String get save => _getString('save');
  String get cancel => _getString('cancel');
  String get confirm => _getString('confirm');
  String get firstName => _getString('firstName');
  String get lastName => _getString('lastName');
  String get phone => _getString('phone');
  String get email => _getString('email');
  String get address => _getString('address');
  String get online => _getString('online');
  String get offline => _getString('offline');
  String get syncing => _getString('syncing');
  String get syncSuccess => _getString('syncSuccess');
  String get syncFailed => _getString('syncFailed');
  String get lastSync => _getString('lastSync');
  String get errorOccurred => _getString('errorOccurred');
  String get hideFilters => _getString('hideFilters');
  String get showFilters => _getString('showFilters');
  String get allShops => _getString('allShops');
  String get selectShop => _getString('selectShop');
  String get startDate => _getString('startDate');
  String get endDate => _getString('endDate');
  String get error => _getString('error');
  String get success => _getString('success');
  String get warning => _getString('warning');
  String get info => _getString('info');
  String get loading => _getString('loading');
  String get noData => _getString('noData');
  String get retry => _getString('retry');
  String get languageSettings => _getString('languageSettings');
  String get selectLanguage => _getString('selectLanguage');
  String get french => _getString('french');
  String get english => _getString('english');
  String get languageChanged => _getString('languageChanged');
  String get yes => _getString('yes');
  String get no => _getString('no');
  String get ok => _getString('ok');
  String get starting => _getString('starting');
  String get initializingDatabase => _getString('initializingDatabase');
  String get initializingServices => _getString('initializingServices');
  String get startingSync => _getString('startingSync');
  String get initializingConnectivity => _getString('initializingConnectivity');
  String get loadingInitialData => _getString('loadingInitialData');
  String get loadingShops => _getString('loadingShops');
  String get loadingAgents => _getString('loadingAgents');
  String get loadingRates => _getString('loadingRates');
  String get finalizing => _getString('finalizing');
  String get ready => _getString('ready');
  String get invalidCredentials => _getString('invalidCredentials');
  String get networkError => _getString('networkError');
  String get serverError => _getString('serverError');
  String get confirmLogout => _getString('confirmLogout');
  String get confirmDelete => _getString('confirmDelete');
  String get adminDashboard => _getString('adminDashboard');
  String get agentDashboard => _getString('agentDashboard');
  String get clientDashboard => _getString('clientDashboard');
  String get expenses => _getString('expenses');
  String get partners => _getString('partners');
  String get ratesAndCommissions => _getString('ratesAndCommissions');
  String get configuration => _getString('configuration');
  String get flot => _getString('flot');
  String get fees => _getString('fees');
  String get virtual => _getString('virtual');
  String get validations => _getString('validations');
  String get operationDataSynced => _getString('operationDataSynced');
  String get syncError => _getString('syncError');
  String get modernSecureTransfer => _getString('modernSecureTransfer');
  String get pleaseEnterUsername => _getString('pleaseEnterUsername');
  String get pleaseEnterPassword => _getString('pleaseEnterPassword');
  String get agentLogin => _getString('agentLogin');
  String get clientLogin => _getString('clientLogin');
  String get createDefaultAdmin => _getString('createDefaultAdmin');
  String get adminPanel => _getString('adminPanel');
  String get capitalAdjustment => _getString('capitalAdjustment');
  String get adjustCapital => _getString('adjustCapital');
  String get capitalAdjustmentHistory => _getString('capitalAdjustmentHistory');
  String get capitalAdjustments => _getString('capitalAdjustments');
  String get adjustmentType => _getString('adjustmentType');
  String get increaseCapital => _getString('increaseCapital');
  String get decreaseCapital => _getString('decreaseCapital');
  String get capitalIncrease => _getString('capitalIncrease');
  String get capitalDecrease => _getString('capitalDecrease');
  String get paymentMode => _getString('paymentMode');
  String get cash => _getString('cash');
  String get airtelMoney => _getString('airtelMoney');
  String get mPesa => _getString('mPesa');
  String get orangeMoney => _getString('orangeMoney');
  String get reason => _getString('reason');
  String get description => _getString('description');
  String get reasonRequired => _getString('reasonRequired');
  String get reasonMinLength => _getString('reasonMinLength');
  String get detailedDescription => _getString('detailedDescription');
  String get descriptionOptional => _getString('descriptionOptional');
  String get currentCapital => _getString('currentCapital');
  String get totalCurrentCapital => _getString('totalCurrentCapital');
  String get adjustmentPreview => _getString('adjustmentPreview');
  String get currentCapitalTotal => _getString('currentCapitalTotal');
  String get adjustment => _getString('adjustment');
  String get newCapital => _getString('newCapital');
  String get newCapitalTotal => _getString('newCapitalTotal');
  String get confirmAdjustment => _getString('confirmAdjustment');
  String get capitalAdjustedSuccessfully => _getString('capitalAdjustedSuccessfully');
  String get capitalUpdatedAndTracked => _getString('capitalUpdatedAndTracked');
  String get adjustmentError => _getString('adjustmentError');
  String get history => _getString('history');
  String get viewHistory => _getString('viewHistory');
  String get adjustmentHistory => _getString('adjustmentHistory');
  String get allCapitalAdjustments => _getString('allCapitalAdjustments');
  String get filterByPeriod => _getString('filterByPeriod');
  String get noAdjustmentsFound => _getString('noAdjustmentsFound');
  String get before => _getString('before');
  String get after => _getString('after');
  String get mode => _getString('mode');
  String get auditId => _getString('auditId');
  String get admin => _getString('admin');
  String get by => _getString('by');
  String get on => _getString('on');
  String get clearFilters => _getString('clearFilters');
  String get period => _getString('period');
  String get selectDate => _getString('selectDate');
  String get clear => _getString('clear');
  String get select => _getString('select');
  String get reset => _getString('reset');
  String get downloadSuccess => _getString('downloadSuccess');
  String get downloadError => _getString('downloadError');
  String get downloadFromServer => _getString('downloadFromServer');
  String get selectDataType => _getString('selectDataType');
  String get downloadAllFees => _getString('downloadAllFees');
  String get feesDescription => _getString('feesDescription');
  String get downloadAllExpenses => _getString('downloadAllExpenses');
  String get expensesDescription => _getString('expensesDescription');
  String get downloadAll => _getString('downloadAll');
  String get downloadAllDescription => _getString('downloadAllDescription');
  String get specialAccounts => _getString('specialAccounts');
  String get shopName => _getString('shopName');
  String get location => _getString('location');
  String get shopLocation => _getString('shopLocation');
  String get additionToCapital => _getString('additionToCapital');
  String get withdrawalFromCapital => _getString('withdrawalFromCapital');
  String get amountRequired => _getString('amountRequired');
  String get invalidAmount => _getString('invalidAmount');
  String get enterAmount => _getString('enterAmount');
  String get exampleAmount => _getString('exampleAmount');
  String get capitalManagement => _getString('capitalManagement');
  String get noShopsAvailable => _getString('noShopsAvailable');
  String get totalAdjustments => _getString('totalAdjustments');
  String get increases => _getString('increases');
  String get decreases => _getString('decreases');
  String get netChange => _getString('netChange');
  String get recentAdjustments => _getString('recentAdjustments');
  String get viewAll => _getString('viewAll');
  String get capitalize => _getString('capitalize');
  String get userNotConnected => _getString('userNotConnected');
  String get shopManagement => _getString('shopManagement');
  String get shopsManagement => _getString('shopsManagement');
  String get newShop => _getString('newShop');
  String get editShop => _getString('editShop');
  String get deleteShop => _getString('deleteShop');
  String get shopDetails => _getString('shopDetails');
  String get shopInformation => _getString('shopInformation');
  String get designation => _getString('designation');
  String get designationRequired => _getString('designationRequired');
  String get designationMinLength => _getString('designationMinLength');
  String get locationRequired => _getString('locationRequired');
  String get capitalByType => _getString('capitalByType');
  String get capitalCash => _getString('capitalCash');
  String get capitalCashRequired => _getString('capitalCashRequired');
  String get capitalMustBePositive => _getString('capitalMustBePositive');
  String get capitalAirtelMoney => _getString('capitalAirtelMoney');
  String get capitalMPesa => _getString('capitalMPesa');
  String get capitalOrangeMoney => _getString('capitalOrangeMoney');
  String get totalCapital => _getString('totalCapital');
  String get averageCapital => _getString('averageCapital');
  String get activeShops => _getString('activeShops');
  String get totalShops => _getString('totalShops');
  String get creating => _getString('creating');
  String get updating => _getString('updating');
  String get createShop => _getString('createShop');
  String get updateShop => _getString('updateShop');
  String get shopCreatedSuccessfully => _getString('shopCreatedSuccessfully');
  String get shopUpdatedSuccessfully => _getString('shopUpdatedSuccessfully');
  String get shopDeletedSuccessfully => _getString('shopDeletedSuccessfully');
  String get errorCreatingShop => _getString('errorCreatingShop');
  String get errorUpdatingShop => _getString('errorUpdatingShop');
  String get errorDeletingShop => _getString('errorDeletingShop');
  String get confirmDeleteShop => _getString('confirmDeleteShop');
  String get thisActionCannotBeUndone => _getString('thisActionCannotBeUndone');
  String get shopHasAgents => _getString('shopHasAgents');
  String get allAgentsWillBeUnassigned => _getString('allAgentsWillBeUnassigned');
  String get noShopsFound => _getString('noShopsFound');
  String get createFirstShop => _getString('createFirstShop');
  String get clickNewShopToCreate => _getString('clickNewShopToCreate');
  String get notSpecified => _getString('notSpecified');
  String get agentsCount => _getString('agentsCount');
  String get actions => _getString('actions');
  String get view => _getString('view');
  String get viewDetails => _getString('viewDetails');
  String get primaryCurrency => _getString('primaryCurrency');
  String get secondaryCurrency => _getString('secondaryCurrency');
  String get initialCapital => _getString('initialCapital');
  String get debts => _getString('debts');
  String get credits => _getString('credits');
  String get lastModified => _getString('lastModified');
  String get createdAt => _getString('createdAt');
  String get syncStatus => _getString('syncStatus');
  String get synced => _getString('synced');
  String get notSynced => _getString('notSynced');
  String get syncPending => _getString('syncPending');
  String get agentsManagement => _getString('agentsManagement');
  String get newAgent => _getString('newAgent');
  String get editAgent => _getString('editAgent');
  String get deleteAgent => _getString('deleteAgent');
  String get agentDetails => _getString('agentDetails');
  String get totalAgents => _getString('totalAgents');
  String get activeAgents => _getString('activeAgents');
  String get inactiveAgents => _getString('inactiveAgents');
  String get verifyAdmin => _getString('verifyAdmin');
  String get createTestAgents => _getString('createTestAgents');
  String get debugInfo => _getString('debugInfo');
  String get agentInformation => _getString('agentInformation');
  String get assignedShop => _getString('assignedShop');
  String get shopRequired => _getString('shopRequired');
  String get usernameRequired => _getString('usernameRequired');
  String get usernameMinLength => _getString('usernameMinLength');
  String get passwordRequired => _getString('passwordRequired');
  String get passwordMinLength => _getString('passwordMinLength');
  String get fullName => _getString('fullName');
  String get fullNameOptional => _getString('fullNameOptional');
  String get phoneNumber => _getString('phoneNumber');
  String get phoneOptional => _getString('phoneOptional');
  String get role => _getString('role');
  String get active => _getString('active');
  String get inactive => _getString('inactive');
  String get activate => _getString('activate');
  String get deactivate => _getString('deactivate');
  String get agentActivated => _getString('agentActivated');
  String get agentDeactivated => _getString('agentDeactivated');
  String get agentCreatedSuccessfully => _getString('agentCreatedSuccessfully');
  String get agentUpdatedSuccessfully => _getString('agentUpdatedSuccessfully');
  String get agentDeletedSuccessfully => _getString('agentDeletedSuccessfully');
  String get errorCreatingAgent => _getString('errorCreatingAgent');
  String get errorUpdatingAgent => _getString('errorUpdatingAgent');
  String get errorDeletingAgent => _getString('errorDeletingAgent');
  String get noAgentsFound => _getString('noAgentsFound');
  String get createFirstAgent => _getString('createFirstAgent');
  String get exampleUsername => _getString('exampleUsername');
  String get minimumCharacters => _getString('minimumCharacters');
  String get noShopAssigned => _getString('noShopAssigned');
  String get adminExists => _getString('adminExists');
  String get adminNotFound => _getString('adminNotFound');
  String get adminWillBeRecreated => _getString('adminWillBeRecreated');
  String get agentRole => _getString('agentRole');
  String get adminRole => _getString('adminRole');
  String get createTestAgentsConfirm => _getString('createTestAgentsConfirm');
  String get agentsToBeCreated => _getString('agentsToBeCreated');
  String get testAgentsCreatedSuccess => _getString('testAgentsCreatedSuccess');
  String get debugInfoInConsole => _getString('debugInfoInConsole');
  String get openConsoleF12 => _getString('openConsoleF12');
  String get close => _getString('close');
  String get searchAgent => _getString('searchAgent');
  String get filterByStatus => _getString('filterByStatus');
  String get allAgents => _getString('allAgents');
  String get all => _getString('all');
  String get noAgentFound => _getString('noAgentFound');
  String get clickNewAgentToCreate => _getString('clickNewAgentToCreate');
  String get createAnAgent => _getString('createAnAgent');
  String get contact => _getString('contact');
  String get agentsStatistics => _getString('agentsStatistics');
  String get withAgents => _getString('withAgents');
  String get withoutAgents => _getString('withoutAgents');
  String get rate => _getString('rate');
  String get adminReports => _getString('adminReports');
  String get adminReportsLong => _getString('adminReportsLong');
  String get analysisAndPerformanceTracking => _getString('analysisAndPerformanceTracking');
  String get advancedDashboards => _getString('advancedDashboards');
  String get companyNetPosition => _getString('companyNetPosition');
  String get cashMovements => _getString('cashMovements');
  String get dailyClosure => _getString('dailyClosure');
  String get closureHistory => _getString('closureHistory');
  String get commissionsReport => _getString('commissionsReport');
  String get interShopCredits => _getString('interShopCredits');
  String get interShopDebts => _getString('interShopDebts');
  String get flotMovements => _getString('flotMovements');
  String get shopSelected => _getString('shopSelected');
  String get useFilterAbove => _getString('useFilterAbove');
  String get dailyClosureRequiresShop => _getString('dailyClosureRequiresShop');
  String get enterprise => _getString('enterprise');
  String get cashRegister => _getString('cashRegister');
  String get closure => _getString('closure');
  String get closures => _getString('closures');
  String get previousFees => _getString('previousFees');
  String get feesCollected => _getString('feesCollected');
  String get feesWithdrawn => _getString('feesWithdrawn');
  String get totalFeesCollected => _getString('totalFeesCollected');
  String get totalFeesWithdrawn => _getString('totalFeesWithdrawn');
  String get previousExpenses => _getString('previousExpenses');
  String get deposits => _getString('deposits');
  String get withdrawals => _getString('withdrawals');
  String get totalDeposits => _getString('totalDeposits');
  String get totalWithdrawals => _getString('totalWithdrawals');
  String get download => _getString('download');
  String get exportToPdf => _getString('exportToPdf');
  String get newEntry => _getString('newEntry');
  String get newExpense => _getString('newExpense');
  String get newWithdrawal => _getString('newWithdrawal');
  String get loadingError => _getString('loadingError');
  String get operationSuccess => _getString('operationSuccess');
  String get operationFailed => _getString('operationFailed');
  String get confirmAction => _getString('confirmAction');
  String get areYouSure => _getString('areYouSure');
  String get allTypes => _getString('allTypes');
  String get advancedFilters => _getString('advancedFilters');
  String get resetFilters => _getString('resetFilters');
  String get allOperations => _getString('allOperations');
  String get feesAndExpenses => _getString('feesAndExpenses');
  String get feesManagement => _getString('feesManagement');
  String get expensesManagement => _getString('expensesManagement');
  String get expenseType => _getString('expenseType');
  String get expenseAmount => _getString('expenseAmount');
  String get feesAmount => _getString('feesAmount');
  String get expenseDescription => _getString('expenseDescription');
  String get feesDescriptionField => _getString('feesDescriptionField');
  String get saveExpense => _getString('saveExpense');
  String get saveFees => _getString('saveFees');
  String get expenseDate => _getString('expenseDate');
  String get feesDate => _getString('feesDate');
  String get expenseSuccess => _getString('expenseSuccess');
  String get feesSuccess => _getString('feesSuccess');
  String get expenseMade => _getString('expensesMade');
  String get addExpense => _getString('addExpense');
  String get addFees => _getString('addFees');
  String get feesAccount => _getString('feesAccount');
  String get expenseAccount => _getString('expenseAccount');
  String get netProfit => _getString('netProfit');

  String _getString(String key) {
    // This is a simplified implementation
    // In a real app, this would look up translations based on the locale
    final Map<String, String> englishTranslations = {
      'appTitle': 'UCASH - Modern Money Transfer',
      'welcome': 'Welcome',
      'login': 'Login',
      'logout': 'Logout',
      'username': 'Username',
      'password': 'Password',
      'enterUsername': 'Enter your username',
      'enterPassword': 'Enter your password',
      'forgotPassword': 'Forgot password?',
      'rememberMe': 'Remember me',
      'dashboard': 'Dashboard',
      'operations': 'Operations',
      'clients': 'Clients',
      'agents': 'Agents',
      'shops': 'Shops',
      'reports': 'Reports',
      'settings': 'Settings',
      'synchronization': 'Synchronization',
      'deposit': 'Deposit',
      'withdrawal': 'Withdrawal',
      'transfer': 'Transfer',
      'payment': 'Payment',
      'amount': 'Amount',
      'balance': 'Balance',
      'commission': 'Commission',
      'total': 'Total',
      'date': 'Date',
      'status': 'Status',
      'reference': 'Reference',
      'pending': 'Pending',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'failed': 'Failed',
      'search': 'Search',
      'filter': 'Filter',
      'export': 'Export',
      'print': 'Print',
      'refresh': 'Refresh',
      'add': 'Add',
      'edit': 'Edit',
      'delete': 'Delete',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'firstName': 'First Name',
      'lastName': 'Last Name',
      'phone': 'Phone',
      'email': 'Email',
      'address': 'Address',
      'online': 'Online',
      'offline': 'Offline',
      'syncing': 'Synchronizing...',
      'syncSuccess': 'Synchronization successful',
      'syncFailed': 'Synchronization failed',
      'lastSync': 'Last sync',
      'errorOccurred': 'An error occurred',
      'hideFilters': 'Hide filters',
      'showFilters': 'Show filters',
      'allShops': 'All shops',
      'selectShop': 'Select a shop',
      'startDate': 'Start date',
      'endDate': 'End date',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'info': 'Information',
      'loading': 'Loading...',
      'noData': 'No data available',
      'retry': 'Retry',
      'languageSettings': 'Language Settings',
      'selectLanguage': 'Select Language',
      'french': 'French',
      'english': 'English',
      'languageChanged': 'Language changed successfully',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
      'starting': 'Starting application...',
      'initializingDatabase': 'Initializing database...',
      'initializingServices': 'Initializing core services...',
      'startingSync': 'Starting synchronization...',
      'initializingConnectivity': 'Initializing connectivity service...',
      'loadingInitialData': 'Loading initial data...',
      'loadingShops': 'Loading shops...',
      'loadingAgents': 'Loading agents...',
      'loadingRates': 'Loading rates...',
      'finalizing': 'Finalizing...',
      'ready': 'Ready!',
      'invalidCredentials': 'Invalid username or password',
      'networkError': 'Network error. Please check your connection.',
      'serverError': 'Server error. Please try again later.',
      'confirmLogout': 'Are you sure you want to logout?',
      'confirmDelete': 'Are you sure you want to delete this item?',
      'adminDashboard': 'Admin Dashboard',
      'agentDashboard': 'Agent Dashboard',
      'clientDashboard': 'Client Dashboard',
      'expenses': 'Expenses',
      'partners': 'Partners',
      'ratesAndCommissions': 'Rates & Commissions',
      'configuration': 'Configuration',
      'flot': 'FLOT',
      'fees': 'Fees',
      'virtual': 'VIRTUAL',
      'validations': 'Validations',
      'operationDataSynced': 'Operation data synchronized',
      'syncError': 'Synchronization error',
      'modernSecureTransfer': 'Modern and secure money transfer',
      'pleaseEnterUsername': 'Please enter your username',
      'pleaseEnterPassword': 'Please enter your password',
      'agentLogin': 'Agent Login',
      'clientLogin': 'Client Login',
      'createDefaultAdmin': 'Create Default Admin',
      'adminPanel': 'Admin Panel',
      'capitalAdjustment': 'Capital Adjustment',
      'adjustCapital': 'Adjust Capital',
      'capitalAdjustmentHistory': 'Capital Adjustment History',
      'capitalAdjustments': 'Capital Adjustments',
      'adjustmentType': 'Adjustment Type',
      'increaseCapital': 'Increase Capital',
      'decreaseCapital': 'Decrease Capital',
      'capitalIncrease': 'Capital Increase',
      'capitalDecrease': 'Capital Decrease',
      'paymentMode': 'Payment Mode',
      'cash': 'Cash',
      'airtelMoney': 'Airtel Money',
      'mPesa': 'M-Pesa',
      'orangeMoney': 'Orange Money',
      'reason': 'Reason',
      'description': 'Description',
      'reasonRequired': 'Reason is required',
      'reasonMinLength': 'Please provide a detailed reason (minimum 10 characters)',
      'detailedDescription': 'Detailed Description',
      'descriptionOptional': 'Additional context, decision reference, etc. (optional)',
      'currentCapital': 'Current Capital',
      'totalCurrentCapital': 'Total Current Capital',
      'adjustmentPreview': 'Adjustment Preview',
      'currentCapitalTotal': 'Current total capital',
      'adjustment': 'Adjustment',
      'newCapital': 'New Capital',
      'newCapitalTotal': 'New total capital',
      'confirmAdjustment': 'Confirm Adjustment',
      'capitalAdjustedSuccessfully': 'Capital adjustment recorded!',
      'capitalUpdatedAndTracked': 'Capital updated and tracked in audit log',
      'adjustmentError': 'Error during adjustment',
      'history': 'History',
      'viewHistory': 'View History',
      'adjustmentHistory': 'Adjustment History',
      'allCapitalAdjustments': 'All Capital Adjustments',
      'filterByPeriod': 'Filter by period',
      'noAdjustmentsFound': 'No capital adjustments found',
      'before': 'Before',
      'after': 'After',
      'mode': 'Mode',
      'auditId': 'Audit ID',
      'admin': 'Admin',
      'by': 'by',
      'on': 'on',
      'clearFilters': 'Clear Filters',
      'period': 'Period',
      'selectDate': 'Select a date',
      'clear': 'Clear',
      'select': 'Select',
      'reset': 'Reset',
      'downloadSuccess': 'Download successful',
      'downloadError': 'Download error',
      'downloadFromServer': 'Download from server',
      'selectDataType': 'Select the type of data to download',
      'downloadAllFees': 'Download all FEES',
      'feesDescription': 'Commissions and fees collected',
      'downloadAllExpenses': 'Download all EXPENSES',
      'expensesDescription': 'Expenses made by the agency',
      'downloadAll': 'Download all',
      'downloadAllDescription': 'All special accounts (Fees and Expenses)',
      'specialAccounts': 'Special Accounts',
      'shopName': 'Shop Name',
      'location': 'Location',
      'shopLocation': 'Shop Location',
      'additionToCapital': 'Addition to Capital (Entry)',
      'withdrawalFromCapital': 'Withdrawal from Capital (Exit)',
      'amountRequired': 'Amount is required',
      'invalidAmount': 'Amount must be a positive number',
      'enterAmount': 'Enter amount',
      'exampleAmount': 'Ex: 5000.00',
      'capitalManagement': 'Capital Management',
      'noShopsAvailable': 'No shops available',
      'totalAdjustments': 'Total Adjustments',
      'increases': 'Increases',
      'decreases': 'Decreases',
      'netChange': 'Net Change',
      'recentAdjustments': 'Recent Adjustments',
      'viewAll': 'View All',
      'capitalize': 'Capitalize',
      'userNotConnected': 'User not connected',
      'shopManagement': 'Shop Management',
      'shopsManagement': 'Shops Management',
      'newShop': 'New Shop',
      'editShop': 'Edit Shop',
      'deleteShop': 'Delete Shop',
      'shopDetails': 'Shop Details',
      'shopInformation': 'Shop Information',
      'designation': 'Designation',
      'designationRequired': 'Designation is required',
      'designationMinLength': 'Designation must contain at least 3 characters',
      'locationRequired': 'Location is required',
      'capitalByType': 'Capital by Cash Type (USD)',
      'capitalCash': 'Cash Capital',
      'capitalCashRequired': 'Cash capital is required',
      'capitalMustBePositive': 'Capital must be a positive number or zero',
      'capitalAirtelMoney': 'Airtel Money Capital',
      'capitalMPesa': 'M-Pesa Capital',
      'capitalOrangeMoney': 'Orange Money Capital',
      'totalCapital': 'Total Capital',
      'averageCapital': 'Average Capital',
      'activeShops': 'Active Shops',
      'totalShops': 'Total Shops',
      'creating': 'Creating...',
      'updating': 'Updating...',
      'createShop': 'Create Shop',
      'updateShop': 'Update Shop',
      'shopCreatedSuccessfully': 'Shop created successfully!',
      'shopUpdatedSuccessfully': 'Shop updated successfully!',
      'shopDeletedSuccessfully': 'Shop deleted successfully!',
      'errorCreatingShop': 'Error creating shop',
      'errorUpdatingShop': 'Error updating shop',
      'errorDeletingShop': 'Error deleting shop',
      'confirmDeleteShop': 'Are you sure you want to delete this shop?',
      'thisActionCannotBeUndone': 'This action cannot be undone.',
      'shopHasAgents': 'This shop has agents assigned to it.',
      'allAgentsWillBeUnassigned': 'All agents will be unassigned.',
      'noShopsFound': 'No shops found',
      'createFirstShop': 'Create your first shop to get started',
      'clickNewShopToCreate': 'Click on \'New Shop\' to create your first shop',
      'notSpecified': 'Not specified',
      'agentsCount': 'Agents',
      'view': 'View',
      'viewDetails': 'View Details',
      'primaryCurrency': 'Primary Currency',
      'secondaryCurrency': 'Secondary Currency',
      'initialCapital': 'Initial Capital',
      'debts': 'Debts',
      'credits': 'Créances',
      'lastModified': 'Last Modified',
      'createdAt': 'Created At',
      'syncStatus': 'Sync Status',
      'synced': 'Synced',
      'notSynced': 'Non Synchronisé',
      'syncPending': 'En attente de sync',
      'agentsManagement': 'Gestion des Agents',
      'newAgent': 'Nouvel Agent',
      'editAgent': 'Modifier l\'Agent',
      'deleteAgent': 'Supprimer l\'Agent',
      'agentDetails': 'Détails de l\'Agent',
      'totalAgents': 'Total Agents',
      'activeAgents': 'Agents Actifs',
      'inactiveAgents': 'Agents Inactifs',
      'verifyAdmin': 'Vérifier Admin',
      'createTestAgents': 'Créer Agents de Test',
      'debugInfo': 'Info Debug',
      'agentInformation': 'Informations de l\'Agent',
      'assignedShop': 'Shop Assigné',
      'shopRequired': 'Veuillez sélectionner un shop',
      'usernameRequired': 'Le nom d\'utilisateur est requis',
      'usernameMinLength': 'Le nom d\'utilisateur doit contenir au moins 3 caractères',
      'passwordRequired': 'Le mot de passe est requis',
      'passwordMinLength': 'Le mot de passe doit contenir au moins 6 caractères',
      'fullName': 'Nom Complet',
      'fullNameOptional': 'Nom complet (optionnel)',
      'phoneNumber': 'Numéro de Téléphone',
      'phoneOptional': 'Numéro de téléphone (optionnel)',
      'role': 'Rôle',
      'activate': 'Activer',
      'deactivate': 'Désactiver',
      'agentActivated': 'Agent activé avec succès',
      'agentDeactivated': 'Agent désactivé avec succès',
      'agentCreatedSuccessfully': 'Agent créé avec succès !',
      'agentUpdatedSuccessfully': 'Agent mis à jour avec succès !',
      'agentDeletedSuccessfully': 'Agent supprimé avec succès !',
      'errorCreatingAgent': 'Erreur lors de la création de l\'agent',
      'errorUpdatingAgent': 'Erreur lors de la mise à jour de l\'agent',
      'errorDeletingAgent': 'Erreur lors de la suppression de l\'agent',
      'noAgentsFound': 'Aucun agent trouvé',
      'createFirstAgent': 'Créez votre premier agent pour commencer',
      'exampleUsername': 'Ex: agent1',
      'minimumCharacters': 'Minimum {count} caractères',
      'noShopAssigned': 'Aucun shop assigné',
      'adminExists': 'Admin existe',
      'adminNotFound': 'Admin non trouvé',
      'adminWillBeRecreated': 'L\'admin sera recréé automatiquement.',
      'agentRole': 'Agent',
      'adminRole': 'Administrateur',
      'createTestAgentsConfirm': 'Voulez-vous créer 2 agents de test pour vérifier le système ?',
      'agentsToBeCreated': 'Agents qui seront créés:',
      'testAgentsCreatedSuccess': 'Agents de test créés avec succès !',
      'debugInfoInConsole': 'Informations de debug affichées dans la console...',
      'openConsoleF12': 'Ouvrez la console (F12) pour voir les détails.',
      'close': 'Fermer',
      'searchAgent': 'Rechercher un agent...',
      'filterByStatus': 'Filtrer par statut',
      'allAgents': 'Tous les agents',
      'all': 'Tous',
      'noAgentFound': 'Aucun agent trouvé avec ces critères',
      'clickNewAgentToCreate': 'Cliquez sur "Nouvel Agent" pour créer un agent',
      'createAnAgent': 'Créer un Agent',
      'agent': 'Agent',
      'shop': 'Shop',
      'contact': 'Contact',
      'agentsStatistics': 'Statistiques des Agents',
      'withAgents': 'Avec Agents',
      'withoutAgents': 'Sans Agents',
      'rate': 'Taux',
      'adminReports': 'Rapports Admin',
      'adminReportsLong': 'Rapports Administrateur',
      'analysisAndPerformanceTracking': 'Analyse et suivi des performances',
      'advancedDashboards': 'Tableaux de bord avancés',
      'companyNetPosition': 'Situation Nette Entreprise',
      'cashMovements': 'Mouvements de Caisse',
      'dailyClosure': 'Clôture Journalière',
      'closureHistory': 'Historique Clôtures',
      'commissionsReport': 'Commissions',
      'interShopCredits': 'Crédits Inter-Shops',
      'interShopDebts': 'Dettes Intershop',
      'flotMovements': 'Mouvements FLOT',
      'allShops': 'Tous les shops',
      'shopSelected': 'Shop sélectionné',
      'useFilterAbove': 'Utilisez le filtre ci-dessus pour sélectionner un shop spécifique',
      'dailyClosureRequiresShop': 'La clôture journalière nécessite un shop spécifique',
      'enterprise': 'Entreprise',
      'cashRegister': 'Caisse',
      'closure': 'Clôture',
      'closures': 'Clôtures',
      'previousFees': 'Frais Antérieur',
      'feesCollected': 'Frais encaissés',
      'feesWithdrawn': 'Sortie Frais',
      'totalFeesCollected': 'Total Frais encaissés',
      'totalFeesWithdrawn': 'Total Sortie Frais',
      'previousExpenses': 'Dépense Antérieur',
      'deposits': 'Dépôts',
      'withdrawals': 'Sorties',
      'totalDeposits': 'Total Dépôts',
      'totalWithdrawals': 'Total Sorties',
      'download': 'Télécharger',
      'exportToPdf': 'Exporter en PDF',
      'newEntry': 'Nouvelle entrée',
      'newExpense': 'Nouvelle dépense',
      'newWithdrawal': 'Nouveau retrait',
      'loadingError': 'Erreur de chargement des données',
      'operationSuccess': 'Opération réussie',
      'operationFailed': 'Échec de l\'opération',
      'confirmAction': 'Confirmer l\'action',
      'areYouSure': 'Êtes-vous sûr ?',
      'allTypes': 'Tous les types',
      'advancedFilters': 'Filtres avancés',
      'resetFilters': 'Réinitialiser les filtres',
      'allOperations': 'Toutes les opérations',
      'feesAndExpenses': 'Frais & Dépenses',
      'feesManagement': 'Gestion des Frais',
      'expensesManagement': 'Gestion des Dépenses',
      'expenseType': 'Type de dépense',
      'expenseAmount': 'Montant de la dépense',
      'feesAmount': 'Montant des frais',
      'expenseDescription': 'Description de la dépense',
      'feesDescriptionField': 'Description des frais',
      'saveExpense': 'Enregistrer la dépense',
      'saveFees': 'Enregistrer les frais',
      'expenseDate': 'Date de la dépense',
      'feesDate': 'Date des frais',
      'expenseSuccess': 'Dépense enregistrée avec succès',
      'feesSuccess': 'Frais enregistrés avec succès',
      'expensesMade': 'Dépenses effectuées',
      'addExpense': 'Ajouter une dépense',
      'addFees': 'Ajouter des frais',
      'feesAccount': 'Compte FRAIS',
      'expenseAccount': 'Compte DÉPENSE',
      'netProfit': 'Bénéfice Net',
    };

    final Map<String, String> frenchTranslations = {
      'appTitle': 'UCASH - Transfert d\'Argent Moderne',
      'welcome': 'Bienvenue',
      'login': 'Connexion',
      'logout': 'Déconnexion',
      'username': 'Nom d\'utilisateur',
      'password': 'Mot de passe',
      'enterUsername': 'Entrez votre nom d\'utilisateur',
      'enterPassword': 'Entrez votre mot de passe',
      'forgotPassword': 'Mot de passe oublié ?',
      'rememberMe': 'Se souvenir de moi',
      'dashboard': 'Tableau de bord',
      'operations': 'Opérations',
      'clients': 'Clients',
      'agents': 'Agents',
      'shops': 'Shops',
      'reports': 'Rapports',
      'settings': 'Paramètres',
      'synchronization': 'Synchronisation',
      'deposit': 'Dépôt',
      'withdrawal': 'Retrait',
      'transfer': 'Transfert',
      'payment': 'Paiement',
      'amount': 'Montant',
      'balance': 'Solde',
      'commission': 'Commission',
      'total': 'Total',
      'date': 'Date',
      'status': 'Statut',
      'reference': 'Référence',
      'pending': 'En attente',
      'completed': 'Terminé',
      'cancelled': 'Annulé',
      'failed': 'Échoué',
      'search': 'Rechercher',
      'filter': 'Filtrer',
      'export': 'Exporter',
      'print': 'Imprimer',
      'refresh': 'Actualiser',
      'add': 'Ajouter',
      'edit': 'Modifier',
      'delete': 'Supprimer',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'firstName': 'Prénom',
      'lastName': 'Nom',
      'phone': 'Téléphone',
      'email': 'Email',
      'address': 'Adresse',
      'online': 'En ligne',
      'offline': 'Hors ligne',
      'syncing': 'Synchronisation en cours...',
      'syncSuccess': 'Synchronisation réussie',
      'syncFailed': 'Échec de la synchronisation',
      'lastSync': 'Dernière synchronisation',
      'errorOccurred': 'Une erreur est survenue',
      'hideFilters': 'Masquer les filtres',
      'showFilters': 'Afficher les filtres',
      'allShops': 'Tous les shops',
      'selectShop': 'Sélectionner un shop',
      'startDate': 'Date de début',
      'endDate': 'Date de fin',
      'error': 'Erreur',
      'success': 'Succès',
      'warning': 'Avertissement',
      'info': 'Information',
      'loading': 'Chargement...',
      'noData': 'Aucune donnée disponible',
      'retry': 'Réessayer',
      'languageSettings': 'Paramètres de langue',
      'selectLanguage': 'Sélectionner la langue',
      'french': 'Français',
      'english': 'Anglais',
      'languageChanged': 'Langue changée avec succès',
      'yes': 'Oui',
      'no': 'Non',
      'ok': 'OK',
      'starting': 'Démarrage de l\'application...',
      'initializingDatabase': 'Initialisation de la base de données...',
      'initializingServices': 'Initialisation des services de base...',
      'startingSync': 'Démarrage de la synchronisation...',
      'initializingConnectivity': 'Initialisation du service de connectivité...',
      'loadingInitialData': 'Chargement des données initiales...',
      'loadingShops': 'Chargement des boutiques...',
      'loadingAgents': 'Chargement des agents...',
      'loadingRates': 'Chargement des taux...',
      'finalizing': 'Finalisation...',
      'ready': 'Prêt !',
      'invalidCredentials': 'Nom d\'utilisateur ou mot de passe invalide',
      'networkError': 'Erreur réseau. Veuillez vérifier votre connexion.',
      'serverError': 'Erreur serveur. Veuillez réessayer plus tard.',
      'confirmLogout': 'Êtes-vous sûr de vouloir vous déconnecter ?',
      'confirmDelete': 'Êtes-vous sûr de vouloir supprimer cet élément ?',
      'adminDashboard': 'Tableau de bord Administrateur',
      'agentDashboard': 'Tableau de bord Agent',
      'clientDashboard': 'Tableau de bord Client',
      'expenses': 'Dépenses',
      'partners': 'Partenaires',
      'ratesAndCommissions': 'Taux & Commissions',
      'configuration': 'Configuration',
      'flot': 'FLOT',
      'fees': 'Frais',
      'virtual': 'VIRTUEL',
      'validations': 'Validations',
      'operationDataSynced': 'Données des opérations synchronisées',
      'syncError': 'Erreur lors de la synchronisation',
      'modernSecureTransfer': 'Transfert d\'argent moderne et sécurisé',
      'pleaseEnterUsername': 'Veuillez saisir votre nom d\'utilisateur',
      'pleaseEnterPassword': 'Veuillez saisir votre mot de passe',
      'agentLogin': 'Connexion Agent',
      'clientLogin': 'Connexion Client',
      'createDefaultAdmin': 'Créer Admin par défaut',
      'adminPanel': 'Panneau d\'administration',
      'capitalAdjustment': 'Ajustement du Capital',
      'adjustCapital': 'Ajuster le Capital',
      'capitalAdjustmentHistory': 'Historique des Ajustements de Capital',
      'capitalAdjustments': 'Ajustements de Capital',
      'adjustmentType': 'Type d\'ajustement',
      'increaseCapital': 'Augmentation du capital',
      'decreaseCapital': 'Diminution du capital',
      'capitalIncrease': 'Augmentation',
      'capitalDecrease': 'Diminution',
      'paymentMode': 'Mode de paiement',
      'cash': 'Cash',
      'airtelMoney': 'Airtel Money',
      'mPesa': 'M-Pesa',
      'orangeMoney': 'Orange Money',
      'reason': 'Raison',
      'description': 'Description',
      'reasonRequired': 'La raison est obligatoire',
      'reasonMinLength': 'Veuillez fournir une raison détaillée (minimum 10 caractères)',
      'detailedDescription': 'Description détaillée',
      'descriptionOptional': 'Contexte additionnel, référence décision, etc. (optionnel)',
      'currentCapital': 'Capital actuel',
      'totalCurrentCapital': 'Capital total actuel',
      'adjustmentPreview': 'Aperçu de l\'ajustement',
      'currentCapitalTotal': 'Capital total actuel',
      'adjustment': 'Ajustement',
      'newCapital': 'Nouveau capital',
      'newCapitalTotal': 'Nouveau capital total',
      'confirmAdjustment': 'Confirmer l\'ajustement',
      'capitalAdjustedSuccessfully': 'Ajustement de capital enregistré !',
      'capitalUpdatedAndTracked': 'Capital mis à jour et tracé dans l\'audit log',
      'adjustmentError': 'Erreur lors de l\'ajustement',
      'history': 'Historique',
      'viewHistory': 'Voir l\'Historique',
      'adjustmentHistory': 'Historique des Ajustements',
      'allCapitalAdjustments': 'Tous les Ajustements de Capital',
      'filterByPeriod': 'Filtrer par période',
      'noAdjustmentsFound': 'Aucun ajustement de capital trouvé',
      'before': 'Avant',
      'after': 'Après',
      'mode': 'Mode',
      'auditId': 'ID Audit',
      'admin': 'Admin',
      'by': 'par',
      'on': 'le',
      'clearFilters': 'Effacer les filtres',
      'period': 'Période',
      'selectDate': 'Sélectionner une date',
      'clear': 'Effacer',
      'select': 'Sélectionner',
      'reset': 'Réinitialiser',
      'downloadSuccess': 'Téléchargement réussi',
      'downloadError': 'Erreur de téléchargement',
      'downloadFromServer': 'Télécharger depuis le serveur',
      'selectDataType': 'Sélectionnez le type de données à télécharger',
      'downloadAllFees': 'Télécharger tous les FRAIS',
      'feesDescription': 'Commissions et frais encaissés',
      'downloadAllExpenses': 'Télécharger toutes les DÉPENSES',
      'expensesDescription': 'Dépenses effectuées par l\'agence',
      'downloadAll': 'Tout télécharger',
      'downloadAllDescription': 'Tous les comptes spéciaux (Frais et Dépenses)',
      'specialAccounts': 'Comptes Spéciaux',
      'shopName': 'Nom du Shop',
      'location': 'Localisation',
      'shopLocation': 'Localisation du Shop',
      'additionToCapital': 'Ajout au capital (Entrée)',
      'withdrawalFromCapital': 'Retrait du capital (Sortie)',
      'amountRequired': 'Le montant est requis',
      'invalidAmount': 'Le montant doit être un nombre positif',
      'enterAmount': 'Entrez le montant',
      'exampleAmount': 'Ex : 5000.00',
      'capitalManagement': 'Gestion du Capital',
      'noShopsAvailable': 'Aucun shop disponible',
      'totalAdjustments': 'Total des Ajustements',
      'increases': 'Augmentations',
      'decreases': 'Diminutions',
      'netChange': 'Changement Net',
      'recentAdjustments': 'Ajustements Récents',
      'viewAll': 'Voir Tout',
      'capitalize': 'Capitaliser',
      'userNotConnected': 'Utilisateur non connecté',
      'shopManagement': 'Gestion des Shops',
      'shopsManagement': 'Gestion des Shops',
      'newShop': 'Nouveau Shop',
      'editShop': 'Modifier le Shop',
      'deleteShop': 'Supprimer le Shop',
      'shopDetails': 'Détails du Shop',
      'shopInformation': 'Informations du Shop',
      'designation': 'Désignation',
      'designationRequired': 'La désignation est requise',
      'designationMinLength': 'La désignation doit contenir au moins 3 caractères',
      'locationRequired': 'La localisation est requise',
      'capitalByType': 'Capitaux par Type de Caisse (USD)',
      'capitalCash': 'Capital Cash',
      'capitalCashRequired': 'Le capital Cash est requis',
      'capitalMustBePositive': 'Le capital doit être un nombre positif ou zéro',
      'capitalAirtelMoney': 'Capital Airtel Money',
      'capitalMPesa': 'Capital M-Pesa',
      'capitalOrangeMoney': 'Capital Orange Money',
      'totalCapital': 'Capital Total',
      'averageCapital': 'Capital Moyen',
      'activeShops': 'Shops Actifs',
      'totalShops': 'Total Shops',
      'creating': 'Création...',
      'updating': 'Mise à jour...',
      'createShop': 'Créer le Shop',
      'updateShop': 'Mettre à jour le Shop',
      'shopCreatedSuccessfully': 'Shop créé avec succès !',
      'shopUpdatedSuccessfully': 'Shop mis à jour avec succès !',
      'shopDeletedSuccessfully': 'Shop supprimé avec succès !',
      'errorCreatingShop': 'Erreur lors de la création du shop',
      'errorUpdatingShop': 'Erreur lors de la mise à jour du shop',
      'errorDeletingShop': 'Erreur lors de la suppression du shop',
      'confirmDeleteShop': 'Êtes-vous sûr de vouloir supprimer ce shop ?',
      'thisActionCannotBeUndone': 'Cette action ne peut pas être annulée.',
      'shopHasAgents': 'Ce shop a des agents qui lui sont assignés.',
      'allAgentsWillBeUnassigned': 'Tous les agents seront désassignés.',
      'noShopsFound': 'Aucun shop trouvé',
      'createFirstShop': 'Créez votre premier shop pour commencer',
      'clickNewShopToCreate': 'Cliquez sur \'Nouveau Shop\' pour créer votre premier shop',
      'notSpecified': 'Non spécifié',
      'agentsCount': 'Agents',
      'view': 'Voir',
      'viewDetails': 'Voir les détails',
      'primaryCurrency': 'Devise Principale',
      'secondaryCurrency': 'Devise Secondaire',
      'initialCapital': 'Capital Initial',
      'debts': 'Dettes',
      'credits': 'Créances',
      'lastModified': 'Dernière Modification',
      'createdAt': 'Créé le',
      'syncStatus': 'Statut de Sync',
      'synced': 'Synchronisé',
      'notSynced': 'Non Synchronisé',
      'syncPending': 'En attente de sync',
      'agentsManagement': 'Gestion des Agents',
      'newAgent': 'Nouvel Agent',
      'editAgent': 'Modifier l\'Agent',
      'deleteAgent': 'Supprimer l\'Agent',
      'agentDetails': 'Détails de l\'Agent',
      'totalAgents': 'Total Agents',
      'activeAgents': 'Agents Actifs',
      'inactiveAgents': 'Agents Inactifs',
      'verifyAdmin': 'Vérifier Admin',
      'createTestAgents': 'Créer Agents de Test',
      'debugInfo': 'Info Debug',
      'agentInformation': 'Informations de l\'Agent',
      'assignedShop': 'Shop Assigné',
      'shopRequired': 'Veuillez sélectionner un shop',
      'usernameRequired': 'Le nom d\'utilisateur est requis',
      'usernameMinLength': 'Le nom d\'utilisateur doit contenir au moins 3 caractères',
      'passwordRequired': 'Le mot de passe est requis',
      'passwordMinLength': 'Le mot de passe doit contenir au moins 6 caractères',
      'fullName': 'Nom Complet',
      'fullNameOptional': 'Nom complet (optionnel)',
      'phoneNumber': 'Numéro de Téléphone',
      'phoneOptional': 'Numéro de téléphone (optionnel)',
      'role': 'Rôle',
      'activate': 'Activer',
      'deactivate': 'Désactiver',
      'agentActivated': 'Agent activé avec succès',
      'agentDeactivated': 'Agent désactivé avec succès',
      'agentCreatedSuccessfully': 'Agent créé avec succès !',
      'agentUpdatedSuccessfully': 'Agent mis à jour avec succès !',
      'agentDeletedSuccessfully': 'Agent supprimé avec succès !',
      'errorCreatingAgent': 'Erreur lors de la création de l\'agent',
      'errorUpdatingAgent': 'Erreur lors de la mise à jour de l\'agent',
      'errorDeletingAgent': 'Erreur lors de la suppression de l\'agent',
      'noAgentsFound': 'Aucun agent trouvé',
      'createFirstAgent': 'Créez votre premier agent pour commencer',
      'exampleUsername': 'Ex: agent1',
      'minimumCharacters': 'Minimum {count} caractères',
      'noShopAssigned': 'Aucun shop assigné',
      'adminExists': 'Admin existe',
      'adminNotFound': 'Admin non trouvé',
      'adminWillBeRecreated': 'L\'admin sera recréé automatiquement.',
      'agentRole': 'Agent',
      'adminRole': 'Administrateur',
      'createTestAgentsConfirm': 'Voulez-vous créer 2 agents de test pour vérifier le système ?',
      'agentsToBeCreated': 'Agents qui seront créés:',
      'testAgentsCreatedSuccess': 'Agents de test créés avec succès !',
      'debugInfoInConsole': 'Informations de debug affichées dans la console...',
      'openConsoleF12': 'Ouvrez la console (F12) pour voir les détails.',
      'close': 'Fermer',
      'searchAgent': 'Rechercher un agent...',
      'filterByStatus': 'Filtrer par statut',
      'allAgents': 'Tous les agents',
      'all': 'Tous',
      'noAgentFound': 'Aucun agent trouvé avec ces critères',
      'clickNewAgentToCreate': 'Cliquez sur "Nouvel Agent" pour créer un agent',
      'createAnAgent': 'Créer un Agent',
      'agent': 'Agent',
      'shop': 'Shop',
      'contact': 'Contact',
      'agentsStatistics': 'Statistiques des Agents',
      'withAgents': 'Avec Agents',
      'withoutAgents': 'Sans Agents',
      'rate': 'Taux',
      'adminReports': 'Rapports Admin',
      'adminReportsLong': 'Rapports Administrateur',
      'analysisAndPerformanceTracking': 'Analyse et suivi des performances',
      'advancedDashboards': 'Tableaux de bord avancés',
      'companyNetPosition': 'Situation Nette Entreprise',
      'cashMovements': 'Mouvements de Caisse',
      'dailyClosure': 'Clôture Journalière',
      'closureHistory': 'Historique Clôtures',
      'commissionsReport': 'Commissions',
      'interShopCredits': 'Crédits Inter-Shops',
      'interShopDebts': 'Dettes Intershop',
      'flotMovements': 'Mouvements FLOT',
      'allShops': 'Tous les shops',
      'shopSelected': 'Shop sélectionné',
      'useFilterAbove': 'Utilisez le filtre ci-dessus pour sélectionner un shop spécifique',
      'dailyClosureRequiresShop': 'La clôture journalière nécessite un shop spécifique',
      'enterprise': 'Entreprise',
      'cashRegister': 'Caisse',
      'closure': 'Clôture',
      'closures': 'Clôtures',
      'previousFees': 'Frais Antérieur',
      'feesCollected': 'Frais encaissés',
      'feesWithdrawn': 'Sortie Frais',
      'totalFeesCollected': 'Total Frais encaissés',
      'totalFeesWithdrawn': 'Total Sortie Frais',
      'previousExpenses': 'Dépense Antérieur',
      'deposits': 'Dépôts',
      'withdrawals': 'Sorties',
      'totalDeposits': 'Total Dépôts',
      'totalWithdrawals': 'Total Sorties',
      'download': 'Télécharger',
      'exportToPdf': 'Exporter en PDF',
      'newEntry': 'Nouvelle entrée',
      'newExpense': 'Nouvelle dépense',
      'newWithdrawal': 'Nouveau retrait',
      'loadingError': 'Erreur de chargement des données',
      'operationSuccess': 'Opération réussie',
      'operationFailed': 'Échec de l\'opération',
      'confirmAction': 'Confirmer l\'action',
      'areYouSure': 'Êtes-vous sûr ?',
      'allTypes': 'Tous les types',
      'advancedFilters': 'Filtres avancés',
      'resetFilters': 'Réinitialiser les filtres',
      'allOperations': 'Toutes les opérations',
      'feesAndExpenses': 'Frais & Dépenses',
      'feesManagement': 'Gestion des Frais',
      'expensesManagement': 'Gestion des Dépenses',
      'expenseType': 'Type de dépense',
      'expenseAmount': 'Montant de la dépense',
      'feesAmount': 'Montant des frais',
      'expenseDescription': 'Description de la dépense',
      'feesDescriptionField': 'Description des frais',
      'saveExpense': 'Enregistrer la dépense',
      'saveFees': 'Enregistrer les frais',
      'expenseDate': 'Date de la dépense',
      'feesDate': 'Date des frais',
      'expenseSuccess': 'Dépense enregistrée avec succès',
      'feesSuccess': 'Frais enregistrés avec succès',
      'expensesMade': 'Dépenses effectuées',
      'addExpense': 'Ajouter une dépense',
      'addFees': 'Ajouter des frais',
      'feesAccount': 'Compte FRAIS',
      'expenseAccount': 'Compte DÉPENSE',
      'netProfit': 'Bénéfice Net',
    };

    if (locale.languageCode == 'fr') {
      return frenchTranslations[key] ?? englishTranslations[key] ?? key;
    } else {
      return englishTranslations[key] ?? key;
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}