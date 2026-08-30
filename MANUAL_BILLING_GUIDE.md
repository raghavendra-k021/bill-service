# Manual Billing Guide (Without Barcode Scanner)

The app works fully **without** a barcode scanner. You can search, browse, add new items, edit prices, and complete bills manually.

**Project:** `bill-service`

## Ways to Add Products to Billing

### Method 1: Search by Product Name

1. Open **Billing**
2. Type product name in search (matches **starts with**)
3. Tap product → **Add dialog** (quantity, price, discount)
4. Tap **Add**

---

### Method 2: Search or Type Barcode

1. Type barcode in search box, or scan with camera
2. If found → add dialog → cart
3. If **not found** → **Add as new item** (or dialog opens automatically after scan)

---

### Method 3: Browse All Products

1. Tap **list icon** (☰) next to search
2. Scroll all products → tap to add

---

### Method 4: Add New Item (Not in Inventory)

Use when product is not in the system yet:

1. Tap **+** in billing app bar, **or**
2. Search/scan unknown barcode → **Add as new item**

Fill the dialog:

| Field | Notes |
|-------|--------|
| Item name | Required |
| Barcode | Optional; auto-generated if blank |
| Unit | pcs, meters, kg, etc. |
| Quantity | Amount to sell |
| Selling price | Editable |
| Discount % | Optional |
| GST % | **Default 5%** — change here or later in Inventory |

Tap **Add to Inventory & Cart** → product saved and added to cart.

---

### Method 5: Barcode Scanner (Optional)

1. Tap **QR scanner** icon
2. Scan label → product found and add dialog opens
3. Stays on billing screen (does not exit)

**Tip:** Reprint barcode labels after app updates so printed codes match inventory (thermal print uses bitmap encoding).

---

## Edit Items in Cart

- **Quantity:** +/- buttons or tap quantity to type
- **Price / discount:** Tap the **₹ price × qty** line → edit dialog → **Update**

---

## Complete Billing Flow

1. **Billing** → add products (any method above)
2. Optional: select **customer**
3. Select **payment mode**
4. Review summary (Gross Total excl. GST, CGST/SGST)
5. **Save Bill** → invoice number, stock updated, optional receipt print

---

## Receipt & PDF

- **Custom footer** — Settings → Edit Shop Details → Footer (left-aligned on bill)
- **Invoice QR** — right side of footer (`INV:…|AMT:…|DT:…`)
- **TOTAL DISCOUNT**, item lines with Rs and unit, Total Items after Gross Total
- Bills list shows amount **excluding GST**

---

## Reports

- **Sales:** Total Sales (excl. GST), Total GST, Total (incl. GST)
- **Excel:** Subtotal column **excl. GST**

---

## Features Without Scanner

| Feature | Available |
|---------|-----------|
| Search by name/barcode | ✅ |
| Browse all products | ✅ |
| Add new item to inventory | ✅ |
| Edit price in cart | ✅ |
| Save bills & print | ✅ |
| Barcode labels (print/PDF from Inventory) | ✅ |
| Custom footer + QR on bills | ✅ |

---

## Tips

1. **Browse** when you don’t remember the exact name
2. **Edit price** at add time or from cart — useful for negotiated rates
3. **Quick-add** one-off items without pre-creating in Inventory separately
4. **GST 5% default** on quick-add — set 12% in dialog if needed
5. **Shop phone** is optional in Settings

---

## Troubleshooting

| Issue | Try |
|-------|-----|
| Scan says product not found | Add as new item, or reprint barcode label |
| Printed barcode wrong number | Update app, reprint label (bitmap print fix) |
| Can’t save shop details (phone) | Phone is optional — leave blank |

---

**The scanner is optional — all billing features work without it.**
