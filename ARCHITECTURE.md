# Bill Service — Architecture & Flows

**Project:** `bill-service` · **Package:** `com.billingservice.app` · **Stack:** Flutter + Drift (SQLite) + Provider

---

## 1. High-Level Architecture

```mermaid
flowchart TB
    subgraph UI["Presentation Layer (lib/screens)"]
        Login[Login / Biometric]
        Dash[Dashboard]
        Bill[Billing + Cart]
        Inv[Inventory + Barcode Labels]
        Cust[Customers]
        Bills[Bills List + Detail]
        Rep[Reports + Analytics]
        Set[Settings + Shop Edit]
    end

    subgraph State["App State"]
        AS[AppState Provider]
        PS[PrintService singleton]
    end

    subgraph SVC["Services Layer (lib/services)"]
        Auth[AuthService]
        BS[BillingService]
        IS[InventoryService]
        RS[ReportService]
        GST[GSTCalculator]
        PR[PrintService]
        BK[BackupService]
    end

    subgraph DB["Data Layer (Drift / SQLite)"]
        DAO[DAOs: User, Product, Customer, Invoice]
        SQLite[(billing_service.db)]
    end

    subgraph EXT["Device / External"]
        Cam[Camera — barcode scan]
        BT[Bluetooth — SPP / BLE printer]
        FS[File system — PDF / Excel export]
        GD[Google Drive — encrypted backup]
    end

    UI --> AS
    AS --> PS
    UI --> SVC
    SVC --> DAO
    DAO --> SQLite
    PR --> BT
    Bill --> Cam
    RS --> FS
    BK --> GD
    PR --> RS
```

---

## 2. Application Startup Flow

```mermaid
sequenceDiagram
    participant M as main.dart
    participant L as _AppLoader
    participant DB as AppDatabase
    participant AS as AppState
    participant S as SplashScreen
    participant Login as LoginScreen

    M->>L: runApp (deferred init)
    L->>L: Show loading spinner
    L->>DB: Create AppDatabase
    L->>AS: Provider + PrintService.restoreSavedPrinter()
    L->>S: MaterialApp home
    S->>DB: Warm up shop_settings query
    S->>Login: pushReplacement
    Login->>AS: setUser on success
    Login->>Dash: Navigate to Dashboard
```

---

## 3. Billing Flow (POS)

```mermaid
flowchart LR
    subgraph Input
        A1[Search name/barcode]
        A2[Scan barcode]
        A3[Browse all products]
        A4[Add new item +]
    end

    subgraph Dialog
        D1[Add / Edit dialog<br/>qty, price, discount, GST]
    end

    subgraph Cart
        C1[CartItem list]
        C2[Bill summary<br/>Gross excl GST, CGST/SGST]
    end

    subgraph Save
        S1[BillingService.createInvoice]
        S2[Invoice + items in DB]
        S3[Stock deduction]
        S4[Optional PrintService.printReceipt]
    end

    A1 --> D1
    A2 --> D1
    A2 -->|not found| A4
    A3 --> D1
    A4 -->|createProductFromBilling| InvDB[(products table)]
    A4 --> D1
    D1 --> C1
    C1 --> C2
    C2 --> S1
    S1 --> S2
    S1 --> S3
    S2 --> S4
```

### Billing decision points

| Step | Behavior |
|------|----------|
| Scan known barcode | Lookup → add dialog → cart |
| Scan unknown barcode | **Add New Item** dialog → inventory + cart |
| Tap product | Add dialog (editable **price**, **discount**) |
| Tap cart price line | Edit qty / price / discount |
| Save bill | Invoice row, line items, stock −qty, optional thermal print |

---

## 4. GST Calculation Flow

```mermaid
flowchart TD
    I[CartItem: unitPrice, qty, discount%, gst%] --> G[GSTCalculator.calculateGST per line]
    G --> T[Taxable = price×qty − line discount]
    T --> GSTamt[GST on taxable amount]
    GSTamt --> Sum[calculateInvoiceGST — sum all lines]
    Sum --> Out[Subtotal, CGST, SGST, total incl GST]
    Out --> Inv[Stored on invoice + printed]
```

- GST **%** comes from **product** (Inventory), not auto by price on quick-add (default **5%**).
- Line totals are **GST-inclusive**; Gross Total on bill = total − embedded GST.

---

## 5. Print & PDF Pipeline

```mermaid
flowchart TB
    subgraph Sources
        InvM[InvoiceModel]
        ProdM[ProductModel — labels]
        Shop[ShopSettings — logo, footer]
    end

    subgraph ReportService
        PDF[generateInvoicePDF]
    end

    subgraph PrintService
        RCPT[_buildReceiptBytes]
        BC[_buildBarcodeBitmap]
        FQR[buildReceiptFooterWithQr]
        IMG[generator.image — ESC/POS bitmap]
        SPP[Bluetooth SPP / BLE send]
    end

    InvM --> PDF
    InvM --> RCPT
    Shop --> PDF
    Shop --> RCPT
    ProdM --> BC
    InvM --> FQR
    RCPT --> IMG
    BC --> IMG
    FQR --> IMG
    IMG --> SPP
    PDF --> Share[Share / Files app]
```

| Output | Encoding |
|--------|----------|
| Receipt text | ESC/POS commands (esc_pos_utils_plus) |
| Shop header | Bitmap (logo + wrapped shop name) |
| Barcode labels | **Bitmap CODE128** (matches screen/PDF) |
| Invoice QR | **Bitmap** footer row — text left, QR right |
| Invoice PDF | pdf + barcode_image + shared header bitmap |

**QR payload:** `INV:<number>|AMT:<total>|DT:<yyyy-mm-dd>`

---

## 6. Data Model (Core Tables)

```mermaid
erDiagram
    users ||--o{ invoices : creates
    customers ||--o{ invoices : optional
    invoices ||--|{ invoice_items : contains
    products ||--o{ invoice_items : references
    products ||--o{ stock_history : tracks
    categories ||--o{ products : optional
    shop_settings ||--|| app : single_row

    products {
        string barcode UK
        string name
        float selling_price
        float gst_percent
        int current_stock
        string unit
    }

    invoices {
        string invoice_number
        float total_amount
        float gst_amount
        string payment_mode
    }

    invoice_items {
        int product_id
        float quantity
        float unit_price
        float discount_percent
    }
```

**DB file (Android):** `/data/data/com.billingservice.app/app_flutter/billing_service.db`

---

## 7. Reports Flow

```mermaid
flowchart LR
    R[Reports Screen] --> SR[Sales Report]
    R --> GR[GST Report]
    R --> AN[Analytics chart]
    SR --> DAO2[InvoiceDao date range]
    DAO2 --> Agg[Aggregate excl/incl GST]
    SR --> XLS[Excel bytes — subtotal excl GST]
    GR --> Split[CGST / SGST split]
```

---

## 8. Settings & Backup

```mermaid
flowchart LR
    Set[Settings] --> Shop[Edit Shop Details]
    Set --> Prt[Bluetooth printer picker]
    Set --> Usr[User management — admin]
    Set --> BK[BackupService]
    Shop --> SS[(shop_settings)]
    BK --> Enc[Encrypt DB export]
    Enc --> GD[Google Drive upload]
    Prt --> PS2[PrintService SPP/BLE]
```

---

## 9. Module Map

```
lib/
├── main.dart                 → Deferred DB init, Provider root
├── app_state.dart            → currentUser, PrintService
├── screens/
│   ├── login/                → Auth → Dashboard
│   ├── dashboard/            → Hub navigation
│   ├── billing/              → POS, cart, add_cart_item_dialog
│   ├── inventory/            → CRUD, barcode_screen
│   ├── customers/
│   ├── bills/                → list, detail, PDF, print
│   ├── reports/
│   └── settings/             → shop_details_edit_screen, printer
├── services/
│   ├── billing_service.dart  → createInvoice, CartItem
│   ├── inventory_service.dart→ CRUD, createProductFromBilling
│   ├── report_service.dart   → reports, PDF
│   ├── print_service.dart    → thermal, bitmap barcodes/QR
│   ├── gst_calculator.dart
│   ├── auth_service.dart
│   └── backup_service.dart
├── database/                 → Drift tables + DAOs
├── models/
└── utils/                    → constants, validators, formatters
```

---

## 10. Role-Based Access

| Feature | Admin | Cashier |
|---------|-------|---------|
| Billing, inventory view | Yes | Yes |
| Edit shop details | Yes | No |
| User management | Yes | No |
| Backup settings | Yes | Typically admin |

(Enforced in Settings UI; extend server-side if multi-device sync added later.)

---

See also: [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) · [README.md](README.md)
