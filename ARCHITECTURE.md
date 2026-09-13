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
        PS[PrintService — dual BT slots]
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

    subgraph UTIL["Utils"]
        LQR[LabelQrCodec — shop code + net price]
        PU[PriceUtils — round rupees]
        FMT[Formatters — display Rs. with .00]
    end

    subgraph DB["Data Layer (Drift / SQLite)"]
        DAO[DAOs: User, Product, Customer, Invoice]
        SQLite[(billing_service.db v5)]
    end

    subgraph EXT["Device / External"]
        Cam[Camera — CODE128 scan at billing]
        BT_R[Bluetooth — Receipt 80 mm SPP/BLE]
        BT_L[Bluetooth — Label 58 mm Posiflow P58D]
        FS[File system — PDF / Excel export]
        GD[Google Drive — encrypted backup]
    end

    UI --> AS
    AS --> PS
    UI --> SVC
    SVC --> DAO
    SVC --> UTIL
    DAO --> SQLite
    PR --> BT_R
    PR --> BT_L
    Bill --> Cam
    Cam --> IS
    RS --> FS
    BK --> GD
    PR --> RS
    LQR --> PR
    PU --> GST
    PU --> PR
    PU --> BS
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
    L->>DB: Create AppDatabase (schema v5)
    L->>AS: Provider + PrintService.restoreSavedPrinters()
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
        A2[Scan CODE128 on label]
        A3[Browse all products]
        A4[Add new item +]
    end

    subgraph Lookup
        L1[getProductByBarcode]
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
    A2 --> L1
    L1 -->|found| C1
    L1 -->|not found| A4
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
| Scan **CODE128 on product label** | `getProductByBarcode` → add product to cart at inventory MRP + default discount |
| Scan plain barcode (inventory) | Same lookup → add dialog if needed → cart |
| Scan unknown barcode | **Add New Item** dialog → inventory + cart |
| Tap product | Add dialog (editable **price**, **discount**) |
| Tap cart price line | Edit qty / price / discount |
| Save bill | Invoice row, line items, stock −qty, optional **receipt** thermal print |

**Note:** Billing no longer parses signed label QR. The label barcode (`product.barcode`) is the scan key.

---

## 4. GST & Price Rounding

```mermaid
flowchart TD
    I[CartItem: unitPrice, qty, discount%, gst%] --> G[GSTCalculator.calculateGST per line]
    G --> R[PriceUtils.roundRupee on discount, taxable, GST, total]
    R --> Sum[calculateInvoiceGST — sum all lines]
    Sum --> Out[Subtotal, CGST, SGST, total incl GST]
    Out --> Inv[Stored on invoice + printed]
```

### Rounding rules (`lib/utils/price_utils.dart`)

| Rule | Implementation |
|------|----------------|
| All money values | Round to **nearest whole rupee** (`amount.round()`) |
| Display | Always show **`.00`** — e.g. `Rs.101.00`, `₹101.00` |
| Label net price | `MRP × (1 − disc%)` then round |
| Cart / receipt / PDF | Same rounding via `PriceUtils` + `Formatters.formatCurrency` |

- GST **%** comes from **product** (Inventory), not auto by price on quick-add (default **5%**).
- Line totals are **GST-inclusive**; Gross Total on bill = total − embedded GST.

---

## 5. Dual Printer Architecture

Two **independent** Bluetooth connections in `PrintService`:

```mermaid
flowchart LR
    subgraph PrintService
        RSlot[_PrinterSlot receipt]
        LSlot[_PrinterSlot label]
    end

    subgraph Prefs["SharedPreferences"]
        RP[receipt_printer_*]
        LP[label_printer_*]
    end

    subgraph Hardware
        CN811[Receipt 80 mm e.g. CN811]
        P58D[Label Posiflow P58D<br/>58 mm head / 2×1.5 in gap labels]
    end

    RSlot --> RP
    LSlot --> LP
    RSlot --> CN811
    LSlot --> P58D
```

| Role | `PrinterRole` | Paper | Used for |
|------|---------------|-------|----------|
| **Receipt** | `receipt` | 80 mm | Bills, test receipt, invoice QR footer |
| **Label** | `label` | 58 mm head / **2"×1.5"** gap labels | Product CODE128 labels only |

- Settings shows **two cards**: connect, test, disconnect each printer separately.
- Legacy single-printer prefs migrate to **receipt** slot on first launch.
- `isConnected` = receipt connected (backward compatible for billing print checks).

---

## 6. Label Print Pipeline (CODE128)

```mermaid
flowchart TB
    subgraph Input
        Prod[ProductModel]
        Shop[shop_settings.shop_code]
    end

    subgraph Utils
        NET[LabelQrCodec.netPriceFrom — rounded]
        PU[PriceUtils.formatRs]
    end

    subgraph PrintService
        IMG[_buildLabelImage bitmap]
        BC[buildLabelCode128Bitmap]
        PAD[_padLabelToPitch 252 dots]
        TRIM[_trimLabelWhitespace]
        RAST[imageRaster GS v 0]
        GAP[GS V 1 between copies]
        BLE[Label slot SPP/BLE]
    end

    subgraph UI
        BS[barcode_screen — preview + copy count]
    end

    Prod --> NET
    Shop --> IMG
    NET --> IMG
    PU --> IMG
    Prod --> BC
    BC --> IMG
    IMG --> TRIM
    TRIM --> PAD
    PAD --> RAST
    RAST --> GAP
    GAP --> BLE
    BS --> PrintService
```

### Label layout (2" × 1.5" thermal)

```
MRP Rs.112.00                    -10%
        SRT PRICE Rs.101.00
        (incl. of all taxes)
        [CODE128 barcode]
        111500
        SAREE
```

| Element | Details |
|---------|---------|
| **MRP** | Left-aligned, bold, large (`arial48` or `arial24`) |
| **-10%** | Right-aligned, same font as MRP, 10px right margin |
| **SRT PRICE** | Centered, bold, same font size as MRP line |
| **Tax line** | Small (`arial14`) |
| **Barcode** | CODE128 = `product.barcode` (billing scans this) |
| **Code text** | Barcode value, bold |
| **Product name** | Uppercase, bold |

**Removed from label:** shop name header, signed QR.

### Label technical constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `_labelPaperWidth` | 384 dots | 58 mm print head |
| `_labelPitchHeightDots` | 252 dots | 1.5" label face height |
| Print command | `generator.imageRaster()` | GS v 0 — no rotation |
| Multi-copy gap | `GS V 1` (`0x1D 0x56 0x01`) | Gap sensor finds next sticker |
| Top whitespace | `_trimLabelWhitespace()` | Crop blank rows above first ink |

**Do not** use `generator.cut()` for labels — it adds extra blank lines that misalign gap-sensor printers.

### Print copies (1–999)

```text
for each copy:
  print full 252-dot raster
  if not last copy → GS V 1 (gap sensor advance)
```

Each copy prints the **identical full layout** (MRP, discount, SRT PRICE, barcode, etc.).

### Label PDF / preview

- On-screen preview: aspect ratio **2 : 1.5**
- Share PDF: page size **2" × 1.5"**, same layout as thermal

---

## 7. Receipt Print & Invoice QR Pipeline

```mermaid
flowchart TB
    subgraph Sources
        InvM[InvoiceModel]
        Shop[ShopSettings — logo, footer, shop_code]
    end

    subgraph ReportService
        PDF[generateInvoicePDF]
    end

    subgraph PrintService
        RCPT[_buildReceiptBytes — 80 mm]
        FQR[buildReceiptFooterWithQr]
        RAST[imageRaster GS v 0 — footer]
        HDR[generator.image — header logo]
        SPP[Receipt slot SPP / BLE]
    end

    InvM --> PDF
    InvM --> RCPT
    Shop --> PDF
    Shop --> RCPT
    InvM --> FQR
    Shop --> FQR
    RCPT --> HDR
    RCPT --> RAST
    FQR --> RAST
    RAST --> SPP
    PDF --> Share[Share / Files app]
```

| Output | Printer | Encoding |
|--------|---------|----------|
| Receipt text | Receipt 80 mm | ESC/POS commands |
| Shop header | Receipt | Bitmap via `generator.image()` (logo + shop name) |
| **Product labels** | Label 58 mm | **GS v 0 raster** — CODE128 layout (see §6) |
| Invoice QR footer | Receipt | **GS v 0 raster** — footer text left, QR right |
| Label PDF | — | 2"×1.5" page |
| Invoice PDF | — | 80 mm thermal format + footer bitmap |

### Invoice QR payload

```text
INV:0001|SC:SRT|AMT:101.00|DT:2026-09-13
```

| Field | Key | Source |
|-------|-----|--------|
| Invoice number | `INV:` | `invoice.invoiceNumber` |
| Shop code | `SC:` | `shop_settings.shop_code` (default **SRT**) |
| Amount | `AMT:` | `PriceUtils.roundRupee(total)` with `.00` |
| Date | `DT:` | `yyyy-mm-dd` |

### Invoice QR technical notes

| Issue | Fix applied |
|-------|-------------|
| QR not scanning | Footer changed from `generator.image()` (ESC * rotates 270°) to **`imageRaster()`** |
| Quiet zone | 10px white margin around QR modules |
| QR size | 120×120 px in footer bitmap |

---

## 8. Data Model (Core Tables)

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
        float default_discount_percent
        float gst_percent
        int current_stock
        string unit
    }

    shop_settings {
        string shop_name
        string shop_code
        string footer
        string logo_path
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

**Schema version:** 5 (adds `shop_settings.shop_code`, default `SRT` on migrate)

**DB file (Android):** `/data/data/com.billingservice.app/app_flutter/billing_service.db`

---

## 9. Reports Flow

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

## 10. Settings & Backup

```mermaid
flowchart LR
    Set[Settings] --> Shop[Edit Shop Details]
    Set --> RP[Receipt printer 80 mm]
    Set --> LP[Label printer 2×1.5 in]
    Set --> Usr[User management — admin]
    Set --> BK[BackupService]
    Shop --> SS[(shop_settings<br/>shop_code, footer, logo)]
    BK --> Enc[Encrypt DB export]
    Enc --> GD[Google Drive upload]
    RP --> PS_R[PrintService receipt slot]
    LP --> PS_L[PrintService label slot]
```

**Shop Details fields:** shop name, **shop code** (used in invoice QR + label price line prefix), address, phone (optional), email, GSTIN, state code, footer, logo.

---

## 11. Module Map

```
lib/
├── main.dart                 → Deferred DB init, Provider root
├── app_state.dart            → currentUser, PrintService
├── screens/
│   ├── login/                → Auth → Dashboard
│   ├── dashboard/            → Hub navigation
│   ├── billing/              → POS, cart, CODE128 scan at billing
│   ├── inventory/            → CRUD, barcode_screen (label preview/print)
│   ├── customers/
│   ├── bills/                → list, detail, PDF, receipt print
│   ├── reports/
│   └── settings/             → shop_details_edit_screen, dual printer cards
├── services/
│   ├── billing_service.dart  → createInvoice, CartItem
│   ├── inventory_service.dart→ CRUD, createProductFromBilling
│   ├── report_service.dart   → reports, invoice PDF
│   ├── print_service.dart    → dual BT, receipt 80mm, label 2×1.5in raster
│   ├── gst_calculator.dart   → GST + PriceUtils rounding
│   └── backup_service.dart
├── database/                 → Drift tables + DAOs (schema v5)
├── models/
│   ├── printer_device.dart   → PrinterRole, PrinterConnectionType
│   └── printer_scan_result.dart
└── utils/
    ├── label_qr_codec.dart   → shop code resolve, netPriceFrom (labels)
    ├── price_utils.dart      → round rupees, formatRs, netAfterDiscount
    ├── formatters.dart       → currency display with .00
    ├── constants.dart
    └── validators.dart       → validateShopCode
```

---

## 12. Role-Based Access

| Feature | Admin | Cashier |
|---------|-------|---------|
| Billing, inventory view | Yes | Yes |
| Edit shop details (incl. shop code) | Yes | No |
| User management | Yes | No |
| Backup settings | Yes | Typically admin |

(Enforced in Settings UI; extend server-side if multi-device sync added later.)

---

## 13. Key File Reference

| Concern | Primary files |
|---------|----------------|
| Dual printers | `print_service.dart`, `settings_screen.dart`, `printer_device.dart` |
| Label bitmap + gap feed | `print_service.dart` — `_buildLabelImage`, `_padLabelToPitch`, `_feedToNextLabelGap` |
| Label net price / shop code | `label_qr_codec.dart`, `price_utils.dart` |
| Label print UI | `barcode_screen.dart` |
| Billing CODE128 scan | `product_search_widget.dart`, `billing_screen.dart` |
| Shop code setting | `shop_details_edit_screen.dart`, `shop_settings_table.dart` |
| Receipt + invoice QR | `print_service.dart` — `invoiceQrPayload`, `buildReceiptFooterWithQr` |
| Price rounding | `price_utils.dart`, `gst_calculator.dart`, `formatters.dart` |
| Invoice PDF | `report_service.dart` |

---

## 14. Hardware Setup Summary

| Device | Role | Label/stock | Connection |
|--------|------|-------------|------------|
| CN811 (or similar) | Receipt | 80 mm continuous | Settings → Receipt printer |
| Posiflow P58D | Label | **2" × 1.5"** gap labels | Settings → Label printer |

**Default login:** `admin` / `admin123`

**Build release APK:**
```bash
cd bill-service
flutter build apk --release
```

---

See also: [README.md](README.md) · [PRINTING_GUIDE.md](PRINTING_GUIDE.md) · [TESTING_GUIDE.md](TESTING_GUIDE.md) · [EMULATOR_TESTING_GUIDE.md](EMULATOR_TESTING_GUIDE.md) · [MANUAL_BILLING_GUIDE.md](MANUAL_BILLING_GUIDE.md) · [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) · [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) · [BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md) · [DATA_AND_SECURITY.md](DATA_AND_SECURITY.md)
