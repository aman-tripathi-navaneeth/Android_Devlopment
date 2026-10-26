import 'package:flutter/material.dart';

import 'language_controller.dart';

/// Centralized localization dictionary for English and Telugu.
/// Conforms to PART 5 glossary and specifications.
class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    return AppStrings(LanguageController().locale);
  }

  bool get isTe => locale.languageCode == 'te';

  // NAVIGATION & SHELL
  String get appTitle => isTe ? 'మెడికల్ స్టోర్' : 'Pharmacy Store';
  String get navHome => isTe ? 'హోమ్' : 'Home';
  String get navMedicines => isTe ? 'మందులు' : 'Medicines';
  String get navPurchasing => isTe ? 'కొనుగోళ్లు' : 'Purchasing';
  String get navSales => isTe ? 'అమ్మకాలు' : 'Sales';
  String get navTransactions => isTe ? 'లావాదేవీలు' : 'Transactions';
  String get navScan => isTe ? 'కెమెరా' : 'Camera';
  String get navMore => isTe ? 'మరిన్ని' : 'More';

  // SCAN WORKFLOW
  String get whatWouldYouLikeToScan => isTe
      ? 'మీరు ఏమి స్కాన్ చేయాలనుకుంటున్నారు?'
      : 'What would you like to scan?';
  String get chooseDocumentType => isTe
      ? 'కెమెరాను తెరవడానికి ముందు పత్రం రకాన్ని ఎంచుకోండి.'
      : 'Choose the document type before opening the camera.';
  String get purchaseInvoice =>
      isTe ? 'కొనుగోలు ఇన్వాయిస్' : 'Purchase Invoice';
  String get addReceivedStockFromSupplier => isTe
      ? 'అందుకున్న స్టాక్‌ను చేర్చడానికి సప్లయర్ ఇన్వాయిస్‌ను స్కాన్ చేయండి.'
      : 'Scan a supplier invoice to add received stock.';
  String get salesReport => isTe ? 'అమ్మకాల నివేదిక' : 'Sales Report';
  String get recordSoldMedicines => isTe
      ? 'అమ్మిన మందులను నమోదు చేయడానికి అమ్మకాల నివేదికను స్కాన్ చేయండి.'
      : 'Scan a sales report to record sold medicines.';
  String get manualTransaction =>
      isTe ? 'మాన్యువల్ లావాదేవీ' : 'Manual Transaction';
  String get manualTransactionSubtitle => isTe
      ? 'మందులను వెతికి పరిమాణాలను మాన్యువల్‌గా నమోదు చేయండి.'
      : 'Search medicines and enter quantities manually.';
  String get stockIn => isTe ? 'స్టాక్ ఇన్' : 'Stock In';
  String get stockOut => isTe ? 'స్టాక్ అవుట్' : 'Stock Out';
  String get inwardBills => isTe ? 'ఇన్వర్డ్ బిల్లులు' : 'Inward Bills';
  String get scanInvoiceOrSalesReport => isTe
      ? 'కొనుగోలు ఇన్వాయిస్ లేదా అమ్మకాల నివేదికను స్కాన్ చేయండి.'
      : 'Scan a purchase invoice or sales report.';

  // COMMONS
  String get search => isTe ? 'వెతకండి…' : 'Search…';
  String get filter => isTe ? 'ఫిల్టర్' : 'Filter';
  String get all => isTe ? 'అన్నీ' : 'All';
  String get active => isTe ? 'యాక్టివ్' : 'Active';
  String get inactive => isTe ? 'ఇన్‌యాక్టివ్' : 'Inactive';
  String get save => isTe ? 'సేవ్ చేయండి' : 'Save';
  String get cancel => isTe ? 'వెనక్కి' : 'Cancel';
  String get confirm => isTe ? 'నిర్ధారించండి' : 'Confirm';
  String get retry => isTe ? 'మళ్లీ ప్రయత్నించండి' : 'Retry';
  String get loading => isTe ? 'లోడ్ అవుతోంది…' : 'Loading…';
  String get empty => isTe ? 'డేటా ఏమీ లేదు' : 'No records found';
  String get notes => isTe ? 'గమనికలు' : 'Notes';
  String get date => isTe ? 'తేదీ' : 'Date';
  String get status => isTe ? 'స్థితి' : 'Status';
  String get total => isTe ? 'మొత్తం' : 'Total';
  String get quantity => isTe ? 'పరిమాణం' : 'Quantity';
  String get rate => isTe ? 'రేటు' : 'Rate';
  String get unit => isTe ? 'యూనిట్' : 'Unit';

  // AUTH & SHOP SETUP
  String get login => isTe ? 'లాగిన్' : 'Login';
  String get logout => isTe ? 'లాగ్అవుట్' : 'Logout';
  String get usernameOrPhone =>
      isTe ? 'యూజర్‌నేమ్ లేదా ఫోన్' : 'Username or Phone';
  String get password => isTe ? 'పాస్‌వర్డ్' : 'Password';
  String get shopSetupTitle => isTe ? 'షాప్ సెటప్' : 'Shop Setup';
  String get shopName => isTe ? 'షాప్ పేరు' : 'Shop Name';
  String get ownerName => isTe ? 'యజమాని పేరు' : 'Owner Name';
  String get phone => isTe ? 'ఫోన్ నంబర్' : 'Phone Number';
  String get address => isTe ? 'చిరునామా' : 'Address';
  String get gstNumber => isTe ? 'జీఎస్టీ నంబర్' : 'GST Number';
  String get drugLicence =>
      isTe ? 'డ్రగ్ లైసెన్స్ నంబర్' : 'Drug Licence Number';
  String get nearExpiryWindow =>
      isTe ? 'గడువు ముగింపు విండో (రోజులు)' : 'Near-expiry Window (days)';

  // DASHBOARD
  String get needsAttention => isTe ? 'శ్రద్ధ అవసరమైనవి' : 'Needs Attention';
  String get lowStockCount => isTe ? 'తక్కువ నిల్వ' : 'Low Stock';
  String get nearExpiryCount => isTe ? 'గడువు సమీపిస్తోంది' : 'Near Expiry';
  String get openOrdersCount => isTe ? 'ఓపెన్ ఆర్డర్లు' : 'Open Orders';
  String get pendingReviewsCount =>
      isTe ? 'పెండింగ్ సమీక్షలు' : 'Pending Reviews';
  String get quickActions => isTe ? 'త్వరిత చర్యలు' : 'Quick Actions';
  String get newPoAction => isTe ? 'కొత్త PO' : 'New PO';
  String get scanInvoiceAction => isTe ? 'ఇన్వాయిస్ స్కాన్' : 'Scan Invoice';
  String get scanSalesAction => isTe ? 'సేల్స్ స్కాన్' : 'Scan Sales';
  String get addMedicineAction => isTe ? 'మందు జోడించండి' : 'Add Medicine';

  // MODULE 4: SUPPLIERS
  String get suppliers => isTe ? 'సరఫరాదారులు' : 'Suppliers';
  String get addSupplier => isTe ? '+ సరఫరాదారుని జోడించండి' : '+ Add Supplier';
  String get editSupplier => isTe ? 'సరఫరాదారు సవరణ' : 'Edit Supplier';
  String get supplierDetails => isTe ? 'సరఫరాదారు వివరాలు' : 'Supplier Details';
  String get contactPerson => isTe ? 'సంప్రదింపు వ్యక్తి' : 'Contact Person';
  String get email => isTe ? 'ఇమెయిల్' : 'Email';
  String get paymentTerms => isTe ? 'చెల్లింపు నిబంధనలు' : 'Payment Terms';
  String get totalOrderValue =>
      isTe ? 'మొత్తం ఆర్డర్ విలువ' : 'Total Order Value';
  String get openOrders => isTe ? 'ఓపెన్ ఆర్డర్లు' : 'Open Orders';
  String get outstandingUnits =>
      isTe ? 'మిగిలిన యూనిట్లు' : 'Outstanding Units';
  String get callSupplier => isTe ? 'కాల్ చేయండి' : 'Call';
  String get deactivate => isTe ? 'నిష్క్రియం చేయండి' : 'Deactivate';
  String get reactivate => isTe ? 'పునరుద్ధరించండి' : 'Reactivate';
  String get noSuppliersYet =>
      isTe ? 'సరఫరాదారులు ఎవరూ లేరు' : 'No suppliers yet';

  // MODULE 4: PURCHASE ORDERS
  String get purchaseOrders => isTe ? 'కొనుగోలు ఆర్డర్లు' : 'Purchase Orders';
  String get newPurchaseOrder =>
      isTe ? '+ కొత్త కొనుగోలు ఆర్డర్' : '+ New Purchase Order';
  String get orderNumber => isTe ? 'ఆర్డర్ నంబర్' : 'Order Number';
  String get awaitingDelivery =>
      isTe ? 'డెలివరీ కోసం వేచి ఉంది' : 'Awaiting delivery';
  String get selectSupplier =>
      isTe ? 'సరఫరాదారుని ఎంచుకోండి' : 'Select Supplier';
  String get addLineItem => isTe ? '+ మందు జోడించండి' : '+ Add Medicine';
  String get saveAsDraft => isTe ? 'డ్రాఫ్ట్‌గా సేవ్ చేయండి' : 'Save as Draft';
  String get sendOrder => isTe ? 'ఆర్డర్ పంపండి' : 'Send Order';
  String get cancelOrder => isTe ? 'ఆర్డర్ రద్దు చేయండి' : 'Cancel Order';
  String get orderedQty => isTe ? 'ఆర్డర్ చేసినది' : 'Ordered';
  String get receivedQty => isTe ? 'అందింది' : 'Received';
  String get remainingQty => isTe ? 'మిగిలినది' : 'Remaining';
  String get estimatedTotalLabel => isTe
      ? 'అంచనా మొత్తం (సర్వర్ లెక్కిస్తుంది)'
      : 'Estimated total (calculated by server)';
  String get lineTotal => isTe ? 'లైన్ మొత్తం' : 'Line Total';
  String get recordGoodsReceipt =>
      isTe ? 'సరుకు రసీదు నమోదు' : 'Record Goods Receipt';
  String get receiptHistory => isTe ? 'రసీదుల చరిత్ర' : 'Receipt History';

  // MODULE 4: GOODS RECEIPT FLOW
  String get goodsReceiptTitle => isTe ? 'సరుకు రసీదు' : 'Goods Receipt';
  String get stepCount => isTe ? '1. లెక్కింపు' : '1. Count';
  String get stepReview => isTe ? '2. సమీక్ష' : '2. Review';
  String get stepResult => isTe ? '3. ఫలితం' : '3. Result';
  String get receivedNow => isTe ? 'ఇప్పుడు అందింది' : 'Received Now';
  String get damagedShort => isTe ? 'దెబ్బతిన్నవి / కొరత' : 'Damaged / Short';
  String get damageReason => isTe ? 'కారణం (ఐచ్ఛికం)' : 'Reason (optional)';
  String get acceptedQuantity =>
      isTe ? 'స్వీకరించిన పరిమాణం' : 'Accepted Quantity';
  String get stockIncreaseNotice => isTe
      ? 'మీరు నిర్ధారించిన తర్వాత మాత్రమే నిల్వ పెరుగుతుంది.'
      : 'Stock will increase only after you confirm.';
  String get confirmReceiptAction =>
      isTe ? 'రసీదు నిర్ధారించండి' : 'Confirm Receipt';
  String get receiptSuccess =>
      isTe ? 'రసీదు విజయవంతంగా నమోదైంది' : 'Goods Receipt Recorded';
  String get inventoryPosting =>
      isTe ? 'ఇన్వెంటరీ పోస్టింగ్' : 'Inventory Posting';

  // STATUS LABELS
  String get statusDraft => isTe ? 'డ్రాఫ్ట్' : 'Draft';
  String get statusSent => isTe ? 'పంపబడింది' : 'Sent';
  String get statusPartiallyReceived =>
      isTe ? 'పాక్షికంగా అందింది' : 'Partially Received';
  String get statusReceived => isTe ? 'అందింది' : 'Received';
  String get statusCancelled => isTe ? 'రద్దయింది' : 'Cancelled';
  String get statusPosted => isTe ? 'పోస్ట్ అయింది' : 'Posted';
  String get statusPending => isTe ? 'పెండింగ్' : 'Pending';
  String get statusFailed => isTe ? 'విఫలమైంది' : 'Failed';

  // MEDICINES & STOCK
  String get medicineCatalogue => isTe ? 'మందుల కేటలాగ్' : 'Medicine Catalogue';
  String get currentStock => isTe ? 'ప్రస్తుత నిల్వ' : 'Current Stock';
  String get unitConversion => isTe ? 'యూనిట్ మార్పిడి' : 'Unit Conversion';
  String get strip => isTe ? 'స్ట్రిప్' : 'Strip';
  String get tablet => isTe ? 'టాబ్లెట్' : 'Tablet';

  // STOCK ADJUSTMENT & RECONCILIATION
  String get physicalCount => isTe ? 'భౌతిక లెక్కింపు' : 'Physical Count';
  String get recordedStock => isTe ? 'రికార్డు నిల్వ' : 'Recorded Stock';
  String get discrepancy => isTe ? 'తేడా' : 'Discrepancy';
  String get resultingStock => isTe ? 'తుది నిల్వ' : 'Resulting Stock';
  String get reasonForDiscrepancy =>
      isTe ? 'తేడాకు కారణం' : 'Reason for Discrepancy';
  String get adjustStock => isTe ? 'స్టాక్ సరిచేయండి' : 'Adjust Stock';
  String get expiryAlerts => isTe ? 'గడువు హెచ్చరికలు' : 'Expiry Alerts';

  // CUSTOMERS & UDHAAR
  String get outstandingBalance =>
      isTe ? 'బకాయి మొత్తం' : 'Outstanding Balance';
  String get recordPayment => isTe ? 'చెల్లింపు నమోదు' : 'Record Payment';
  String get paymentMethod => isTe ? 'చెల్లింపు విధానం' : 'Payment Method';
  String get amountReceived => isTe ? 'స్వీకరించిన మొత్తం' : 'Amount Received';

  // MORE TAB
  String get stockLedger => isTe ? 'స్టాక్ లెడ్జర్' : 'Stock Ledger';
  String get reconciliation =>
      isTe ? 'స్టాక్ సరిపోల్చడం' : 'Stock Reconciliation';
  String get customers => isTe ? 'కస్టమర్లు' : 'Customers';
  String get udhaarCredit =>
      isTe ? 'ఉద్దెర & చెల్లింపులు' : 'Udhaar & Payments';
  String get reports => isTe ? 'నివేదికలు' : 'Reports';
  String get notifications => isTe ? 'నోటిఫికేషన్లు' : 'Notifications';
  String get languageSettings => isTe ? 'భాష (Language)' : 'Language Settings';
  String get settings => isTe ? 'సెట్టింగ్‌లు' : 'Settings';

  // PROCUREMENT & ORDER TRACKING
  String get reviewOrder => isTe ? 'ఆర్డర్ సమీక్షించండి' : 'Review Order';
  String get orderTrackingTimeline =>
      isTe ? 'ఆర్డర్ ట్రాకింగ్ టైమ్‌లైన్' : 'Order Tracking Timeline';
  String get expectedDeliveryDate =>
      isTe ? 'ఆశించిన డెలివరీ తేదీ' : 'Expected Delivery Date';
  String get purchaseHistory => isTe ? 'కొనుగోలు చరిత్ర' : 'Purchase History';
  String get draftCreatedMilestone =>
      isTe ? 'డ్రాఫ్ట్ సృష్టించబడింది' : 'Draft Created';
  String get orderReviewedMilestone =>
      isTe ? 'ఆర్డర్ సమీక్షించబడింది' : 'Order Reviewed';
  String get orderConfirmedMilestone =>
      isTe ? 'ఆర్డర్ నిర్ధారించబడింది' : 'Order Confirmed';
  String get orderPlacedMilestone =>
      isTe ? 'సరఫరాదారుకు పంపబడింది' : 'Order Placed with Supplier';
  String get deliveryInProgressMilestone =>
      isTe ? 'డెలివరీ మార్గంలో ఉంది' : 'Delivery in Progress';
  String get partialDeliveryMilestone =>
      isTe ? 'పాక్షిక డెలివరీ అందింది' : 'Partially Received';
  String get deliveryCompletedMilestone =>
      isTe ? 'డెలివరీ పూర్తయింది' : 'Delivery Completed';
  String get orderClosedMilestone => isTe ? 'ఆర్డర్ ముగిసింది' : 'Order Closed';
  String get viewTimeline =>
      isTe ? 'టైమ్‌లైన్ చూడండి' : 'View Tracking Timeline';
  String get sortBy => isTe ? 'క్రమబద్ధీకరించండి' : 'Sort by';
  String get clearFilters => isTe ? 'ఫిల్టర్లు తొలగించు' : 'Clear Filters';
  String get receiptSummary => isTe ? 'రసీదు సారాంశం' : 'Receipt Summary';
  String get receiptRecordedSuccess => isTe
      ? 'వస్తువుల రసీదు విజయవంతంగా నమోదు చేయబడింది'
      : 'Goods Receipt Recorded Successfully';

  // MEMBER 2: MEDICINE CATALOGUE & PACK UNITS
  String get medicineDetails => isTe ? 'మందు వివరాలు' : 'Medicine Details';
  String get genericNameLabel => isTe ? 'జెనెరిక్ పేరు' : 'Generic Name';
  String get brandNameLabel => isTe ? 'బ్రాండ్ పేరు' : 'Brand Name';
  String get categoryLabel => isTe ? 'వర్గం' : 'Category';
  String get manufacturerLabel => isTe ? 'తయారీదారు' : 'Manufacturer';
  String get packUnitLabel => isTe ? 'ప్యాక్ యూనిట్' : 'Pack Unit';
  String get saleUnitLabel => isTe ? 'అమ్మకపు యూనిట్' : 'Sale Unit';
  String get unitsPerPackLabel =>
      isTe ? 'ప్యాక్‌కు యూనిట్లు' : 'Units per Pack';
  String get conversionFactorLabel =>
      isTe ? 'మార్పిడి కారకం' : 'Conversion Factor';
  String get conversionRuleLabel => isTe ? 'మార్పిడి నియమం' : 'Conversion Rule';
  String get deactivateMedicine =>
      isTe ? 'మందును నిష్క్రియం చేయండి' : 'Deactivate Medicine';
  String get reactivateMedicine =>
      isTe ? 'మందును పునరుద్ధరించండి' : 'Reactivate Medicine';
  String get confirmDeactivation =>
      isTe ? 'నిష్క్రియం చేయడాన్ని నిర్ధారించండి' : 'Confirm Deactivation';
  String get duplicateWarning =>
      isTe ? 'డూప్లికేట్ రికార్డ్ హెచ్చరిక' : 'Possible Duplicate Medicine';
  String get lowStockThresholdLabel =>
      isTe ? 'తక్కువ నిల్వ పరిమితి' : 'Low Stock Threshold';
  String get dosageFormLabel => isTe ? 'మోతాదు రూపం' : 'Dosage Form';
  String get productIdLabel => isTe ? 'ప్రొడక్ట్ ID' : 'Product ID';
  String get interactiveConverter =>
      isTe ? 'ఇంటరాక్టివ్ యూనిట్ కన్వర్టర్' : 'Interactive Unit Converter';

  // MEMBER 7: OUTWARD SALES REPORT SCANNING & VERIFICATION
  String get salesReportScanning =>
      isTe ? 'అమ్మకాల నివేదిక స్కానింగ్' : 'Sales Report Scanning';
  String get scanOrUploadReport =>
      isTe ? 'నివేదిక స్కాన్ లేదా అప్‌లోడ్ చేయండి' : 'Scan or Upload Report';
  String get reportReferenceLabel =>
      isTe ? 'నివేదిక రిఫరెన్స్' : 'Report Reference';
  String get reportDateLabel => isTe ? 'నివేదిక తేదీ' : 'Report Date';
  String get framingInstructions =>
      isTe ? 'ఫ్రేమింగ్ & నాణ్యత సూచనలు' : 'Framing & Quality Guidelines';
  String get captureCamera => isTe ? 'కెమెరాతో తీయండి' : 'Capture with Camera';
  String get uploadImageFile =>
      isTe ? 'చిత్రాన్ని అప్‌లోడ్ చేయండి' : 'Upload Image';
  String get uploadPdfFile =>
      isTe ? 'PDFని అప్‌లోడ్ చేయండి' : 'Upload PDF Document';
  String get replaceRetake =>
      isTe ? 'మళ్లీ తీయండి / మార్చండి' : 'Retake / Replace';
  String get removeFile => isTe ? 'ఫైల్ తీసివేయండి' : 'Remove File';
  String get reviewExtractedLines =>
      isTe ? 'సేకరించిన లైన్లను సమీక్షించండి' : 'Review Extracted Lines';
  String get resolveUnmatched =>
      isTe ? 'సరిపోలని మందులను పరిష్కరించండి' : 'Resolve Unmatched Items';
  String get confidenceHigh => isTe ? 'అధిక విశ్వాసం' : 'High Confidence';
  String get confidenceMedium =>
      isTe ? 'మధ్యస్థ విశ్వాసం' : 'Medium Confidence';
  String get confidenceLow => isTe ? 'తక్కువ విశ్వాసం' : 'Low Confidence';
  String get confirmAndPost =>
      isTe ? 'నిర్ధారించి పోస్ట్ చేయండి' : 'Confirm and Post';
  String get confirmDeductionsTitle =>
      isTe ? 'స్టాక్ తగ్గింపులను నిర్ధారించాలా?' : 'Confirm Stock Deductions?';
  String get confirmDeductionsMessage => isTe
      ? 'ఇది ఇన్వెంటరీ లెడ్జర్ నుండి స్టాక్ తగ్గింపులను నమోదు చేస్తుంది. ఈ చర్య శాశ్వతమైనది.'
      : 'This will permanently record stock deductions in the inventory ledger under your authorization.';
  String get deductionsPostedSuccess => isTe
      ? 'స్టాక్ తగ్గింపులు విజయవంతంగా పోస్ట్ చేయబడ్డాయి'
      : 'Stock Deductions Posted Successfully';
  String get salesReportHistory =>
      isTe ? 'అమ్మకాల నివేదికల చరిత్ర' : 'Sales Report History';
  String get salesReportDetail =>
      isTe ? 'అమ్మకాల నివేదిక వివరాలు' : 'Sales Report Detail';
  String get proposedStockDeductions =>
      isTe ? 'ప్రతిపాదిత స్టాక్ తగ్గింపులు' : 'Proposed Stock Deductions';
  String get fefoBatchAllocation =>
      isTe ? 'FEFO బ్యాచ్ కేటాయింపు' : 'FEFO Batch Allocation';
  String get unresolvedLinesAlert =>
      isTe ? 'పరిష్కరించని లైన్లు మిగిలి ఉన్నాయి' : 'Unresolved lines remain';
  String get duplicateReportWarning =>
      isTe ? 'డూప్లికేట్ నివేదిక హెచ్చరిక' : 'Possible Duplicate Report';
  String get simulatedFrontendResult =>
      isTe ? 'సిమ్యులేటెడ్ ఫ్రంటెండ్ ఫలితం' : 'Simulated Frontend Result';
  String get postingInProgress =>
      isTe ? 'పోస్టింగ్ జరుగుతోంది...' : 'Posting in progress...';
  String get allMatchedLabel => isTe ? 'అన్నీ సరిపోలాయి' : 'All Lines Matched';
  String get attentionNeededLabel =>
      isTe ? 'పరిష్కారం అవసరం' : 'Requires Attention';
  String get orders => isTe ? 'ఆర్డర్లు' : 'Orders';
  String get createDraftPO =>
      isTe ? 'డ్రాఫ్ట్ ఆర్డర్ సృష్టించండి' : 'Create Draft PO';
  String get salesReports => isTe ? 'అమ్మకాల నివేదికలు' : 'Sales Reports';
}
