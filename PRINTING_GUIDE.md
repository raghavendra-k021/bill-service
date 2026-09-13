# Printing & Scanning Guide

Complete reference for thermal receipt printing, gap label printing, billing scan, and price formatting in **bill-service**.

---

## 1. Hardware

| Printer | Settings slot | Paper | Use |
|---------|---------------|-------|-----|
| CN811 (or 80 mm thermal) | **Receipt printer** | 80 mm roll | Bills / receipts only |
| Posiflow P58D | **Label printer** | **2" × 1.5"** gap labels | Product labels only |

Both can stay connected at the same time (`receipt_printer_*` and `label_printer_*` in SharedPreferences).

---

## 2. Product Labels (CODE128)

### Where to print

**Inventory** → barcode icon next to product → **Barcode Label** screen

- Preview layout (2 : 1.5 aspect ratio)
- **Number of labels** (1–999)
- **Print to Label Printer**
- **Share / Save as PDF**

### Label layout

```
MRP Rs.112.00                    -10%
        SRT PRICE Rs.101.00
        (incl. of all taxes)
        [CODE128 barcode]
        111500
        SAREE
```

| Line | Alignment | Font |
|------|-----------|------|
| MRP Rs.xxx | Left | Bold large |
| -10% | Right (10px margin) | Same as MRP |
| SRT PRICE Rs.xxx | Center | Bold large (same size as MRP) |
| (incl. of all taxes) | Center | Small |
| Barcode | Center | CODE128 |
| Barcode number | Center | Bold |
| Product name | Center | Bold uppercase |

- **SRT** = shop code from Settings → Edit Shop Details (default `SRT`)
- **No shop name** printed on label

### Price calculation

| Field | Formula |
|-------|---------|
| MRP | `product.sellingPrice` (rounded to whole rupee) |
| Discount | `product.defaultDiscountPercent` |
| SRT PRICE | `round(MRP × (1 − disc/100))` displayed as `Rs.xxx.00` |

Implementation: `LabelQrCodec.netPriceFrom()` → `PriceUtils.netAfterDiscount()`

### Billing scan

At **Billing**, scan the **CODE128 barcode** on the printed label. The app looks up `product.barcode` in inventory and adds the item to cart.

The billing camera prioritizes **code128** format (not QR).

### Multi-copy printing

When printing 2+ labels:

1. Each copy prints a **full 252-dot raster** (exact 1.5" label height)
2. Between copies: **`GS V 1`** — printer **gap sensor** advances to next sticker
3. Every copy shows the **same complete layout** (MRP, -10%, SRT PRICE, barcode, etc.)

**Do not** manually feed labels between copies — the gap sensor handles alignment.

### Troubleshooting labels

| Problem | Likely cause | What we do in code |
|---------|--------------|-------------------|
| Content crosses to next label | Bitmap too tall or wrong print command | Fixed pitch 252 dots + `imageRaster` |
| Blank space above MRP | Font top padding | `_trimLabelWhitespace()` |
| Copy 2 missing MRP line | No gap feed between copies | `GS V 1` between rasters |
| QR on label (old docs) | Removed — labels use CODE128 only | Scan barcode at billing |

---

## 3. Receipt Printing (80 mm)

### Where to print

**Billing** → Print Bill (after save)  
**Bills** → bill detail → Print  
**Settings** → Receipt printer → Test receipt

### Receipt contents

- Shop logo + name (bitmap header)
- Invoice number + date
- Item table with discount column
- TOTAL DISCOUNT, Gross Total, GST breakdown
- Payment mode
- **Footer text (left)** + **Invoice QR (right)**

### Invoice QR payload

When scanned with a phone QR reader:

```text
INV:0001|SC:SRT|AMT:101.00|DT:2026-09-13
```

| Part | Meaning |
|------|---------|
| `INV:` | Invoice number |
| `SC:` | Shop code (Settings) |
| `AMT:` | Bill total (rounded rupees, `.00`) |
| `DT:` | Invoice date `yyyy-mm-dd` |

### QR technical fix

Receipt footer QR uses **`imageRaster` (GS v 0)**, not `generator.image()` (ESC *), because ESC * rotates the bitmap 270° and corrupts QR modules for phone scanners.

QR also has a **10px quiet zone** and **120px** size for reliable scanning.

---

## 4. Price Rounding (All Screens)

All monetary amounts use **whole rupee rounding** with **`.00` display**:

| Location | Example |
|----------|---------|
| Label MRP / SRT PRICE | `Rs.101.00` |
| Cart line total | `₹101.00` |
| Receipt / PDF | `Rs.101.00` |
| Invoice QR AMT | `101.00` |

Source: `lib/utils/price_utils.dart`

```dart
PriceUtils.roundRupee(100.8)  // → 101.0
PriceUtils.formatRs(100.8)    // → "Rs.101.00"
```

---

## 5. ESC/POS Commands Used

| Job | Command | Why |
|-----|---------|-----|
| Label print | `imageRaster` (GS v 0) | Correct size, no rotation |
| Label multi-copy gap | `GS V 1` (0x1D 0x56 0x01) | Gap sensor to next sticker |
| Receipt footer QR | `imageRaster` (GS v 0) | Scannable QR |
| Receipt header logo | `generator.image()` (ESC *) | Wide header strip |
| Receipt text | ESC/POS text/row commands | Standard thermal |
| Receipt end | `feed(2)` + `cut()` | Full cut after bill |

---

## 6. Shop Code Usage

| Feature | Uses shop code? |
|---------|-----------------|
| Label `SRT PRICE` line | Yes — `{shopCode} PRICE Rs.xxx` |
| Invoice QR `SC:` field | Yes |
| Label signed QR | **Removed** — not used |
| Billing label scan | **No** — uses product barcode only |

Change shop code in **Settings → Edit Shop Details → Shop Code**. Reprint labels after change so price line prefix matches.

---

## 7. Quick Test Checklist

- [ ] Connect receipt + label printers in Settings
- [ ] Test receipt → footer QR scans → shows `INV:…|SC:…|AMT:…|DT:…`
- [ ] Print 1 label → MRP left, -10% right, SRT PRICE, barcode, name
- [ ] Print **2 labels** → both identical full layouts
- [ ] Scan label barcode at billing → product added
- [ ] Save bill → amounts show whole rupees with `.00`

---

See [ARCHITECTURE.md](ARCHITECTURE.md) for system diagrams and code file references.
