# School ID Card System — Administrator User Manual

This manual provides instructions for system administrators, print bureau managers, and school coordinators operating the administrative dashboard.

---

## 1. Accessing the Admin Panel

1. Open the application or web portal.
2. Select the **Admin** tab.
3. Enter your administrative email and password.
4. The **Admin Dashboard** displays real-time key performance indicators:
   - **Awaiting Review**: Submissions pending administrative sign-off.
   - **Approved**: Approved entries verified for printing.
   - **Rejected**: Entries flagged with rework instructions.
   - **Ready to Print**: Approved cards with valid photographs.

---

## 2. School Setup & Branding Configuration

To add a new school or modify existing school parameters:
1. Tap **"Add school"** or select an existing school card and tap the settings icon.
2. **Branding Colors**:
   - **Primary Color**: Used for Student Name, Class, Mobile, and Address.
   - **Secondary Color**: Used for Father's Name and Date of Birth.
   - **Header Color**: Saturated band background behind the school title.
   - **Photo Background**: Clean contrast color behind the student photo.
3. **Logos & Principal Signature**:
   - **School Logo**: Upload PNG/JPG logo file.
   - **Principal Signature**: Either upload a scanned signature image or use the **built-in digital signature canvas** to draw the signature with a stylus or finger.
4. **Card Formats**: Choose from CR-80 (54 × 86 mm), CR-79 (52 × 84 mm), 56 × 88 mm, or 60 × 90 mm.
5. **Class & Division Lists**: Configure predefined classes and divisions for the school's dropdowns.

---

## 3. Operator Account Management

1. Tap **"Operator & School Accounts"** on the dashboard.
2. View all registered accounts, filtered by role (School Operator vs. Admin) or status (Active vs. Disabled).
3. **Create New Account**: Tap **"+ New Account"**, specify email, password, role, and bind to a specific school.
4. **Instant Access Revocation**: Use the **Active / Disabled toggle** next to any account to immediately block or restore system access.

---

## 4. Review Queue & Quality Control

1. Select a school to open its **School Detail Review Queue**.
2. **Filtering & Sorting**: Filter by Approval Status (`Pending`, `Approved`, `Rejected`), Class, or Division. Sort by Newest, Oldest, or Name.
3. **Approval**:
   - Tap **"Approve"** on individual cards, or select multiple checkboxes and tap **"Approve X"**.
4. **Rejection with Mandatory Reason**:
   - Tap **"Reject"** or select bulk items and tap **"Reject X"**.
   - A dialog requires entering a specific explanation (e.g. *"Photo shadow too dark"*, *"Spell check father's name"*).
   - The operator will see this exact message on their device for correction.

---

## 5. Print Production & Imposition

1. From the school screen, tap **"Print Cards"**.
2. Select the print imposition format:
   - **10-up A4 Landscape Sheet**: 10 cards per sheet (5 columns × 2 rows) with hairline crop marks.
   - **25-up 12 × 18 inch Digital Press Sheet**: 25 cards per sheet (5 columns × 5 rows) with guillotine trim lines.
   - **Single Card PDF**: 1 card per PDF at exact 54 × 86 mm dimensions.
3. Tap **"Generate Print Run"**.
4. A printable vector PDF is produced at **300 DPI**, and a permanent **Print Batch record** is recorded in the database.

---

## 6. CSV Data Export

1. Open **"Export CSV"** from the school menu.
2. Filter the dataset by status or class if needed.
3. Tap **"Export CSV"**.
4. The system produces an **RFC 4180 compliant CSV file** with **UTF-8 BOM (`\uFEFF`)**, ensuring clean opening in Microsoft Excel without character corruption.

---

## 7. Audit Log & Activity Trail

1. Tap **"Audit Log & Activity Trail"** from the admin dashboard.
2. Chronological record of all administrative activities:
   - Approvals, Rejections, CSV Exports, Print Runs, and User Access Changes.
3. Inspect actor UID, timestamps, and full event payloads.

---

## 8. Reports & Analytics Dashboard

1. Tap **"Reports & Analytics"** or the analytics icon in the AppBar.
2. Review top-level metrics across all schools:
   - Total Students registered.
   - Overall Approval Rate percentage.
   - Pending Review volume.
   - Total Cards Printed.
3. Inspect **Monthly Submission Trends** and per-school breakdown cards with instant CSV download shortcuts.
