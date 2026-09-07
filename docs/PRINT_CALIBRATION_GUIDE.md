# Print Calibration & Production Guide

This guide defines the physical specifications, printer configurations, and calibration workflows for producing finished school ID cards with true 1:1 physical dimensions at **300 DPI**.

---

## 1. Card Specifications (CR-80 Standard)

| Parameter | Specification | Tolerance |
|---|---|---|
| **Finished Trim Size** | 54.00 mm (width) × 86.00 mm (height) | ± 0.25 mm |
| **Corner Radius** | 3.18 mm (1/8 in) rounded corners | ± 0.10 mm |
| **Resolution** | 300 DPI (raster elements & photographs) | Strict |
| **Color Model** | sRGB / CMYK standard press calibration | Delta E < 2.0 |
| **Student Photo Size** | 1.20 in × 1.50 in (30.48 mm × 38.10 mm) | Exact |
| **Bleed** | 3.00 mm extended past trim line | Included in imposition |

---

## 2. Imposition Schemes

### Scheme A: 10-Up A4 Landscape (Office & Standard Production)
- **Sheet Dimensions**: 297.00 mm (width) × 210.00 mm (height)
- **Grid Layout**: 5 columns × 2 rows = **10 cards per sheet**
- **Margin Allocation**:
  - Horizontal card span: 5 × 54 mm = 270 mm (leaving 27.0 mm total margin, 13.5 mm left and right).
  - Vertical card span: 2 × 86 mm = 172 mm (leaving 38.0 mm total margin, 19.0 mm top and bottom).
- **Cut Guides**: Hairline corner crop marks (0.15 mm weight, 3.0 mm length, 1.0 mm offset from trim line).

### Scheme B: 25-Up 12 × 18 Inch (Digital Commercial Press)
- **Sheet Dimensions**: 304.80 mm (width) × 457.20 mm (height)
- **Grid Layout**: 5 columns × 5 rows = **25 cards per sheet**
- **Margin Allocation**:
  - Horizontal card span: 5 × 54 mm = 270 mm (leaving 34.8 mm total margin, 17.4 mm left and right).
  - Vertical card span: 5 × 86 mm = 430 mm (leaving 27.2 mm total margin, 13.6 mm top and bottom).
- **Cut Guides**: Continuous guillotine trim channels and crop ticks for commercial paper cutters.

---

## 3. Printer Driver & Rip Calibration Settings

> [!IMPORTANT]
> Always print at **100% (Actual Size)**. Never select *"Fit to Printable Area"* or *"Shrink Oversized Pages"*, as any scaling will invalidate the 54 × 86 mm card dimensions.

1. **Page Scaling**: Set to **"None"** or **"100% / Actual Size"**.
2. **Auto-Rotate & Center**: **Enabled**.
3. **Print Quality**: Set to **High Quality / 1200 dpi / 2400 dpi engine smoothing** with raster input at 300 DPI.
4. **Media Types**:
   - **Art Card**: 250 – 300 GSM coated cardstock.
   - **Synthetic Paper**: Teslin / Polyart 250 micron (waterproof and tear-resistant).
   - **Fused PVC**: 30 mil (0.76 mm) PVC core with dual laminate overlay for thermal card laminators.

---

## 4. Physical Measurement & Verification Checklist

Before running a production batch of 100+ cards, print a single calibration sheet and verify using a vernier caliper or millimeter ruler:

- [ ] Measure Card #1 width: Must be exactly **54.0 mm**.
- [ ] Measure Card #1 height: Must be exactly **86.0 mm**.
- [ ] Measure Student Photo box: Must be exactly **30.5 mm × 38.1 mm** (1.2 × 1.5 in).
- [ ] Text Sharpness: Arial/Liberation Sans 8pt Bold (Name), 7pt Regular (Father, DOB, Mobile), 5pt Regular (Address) must be crisp and legible with no blur.
- [ ] Header Color Band: Colors must match the school's configured hexadecimal brand values.
- [ ] Guillotine Alignment: Cut marks must align cleanly with the ruler guide.
