# ID entity — Operator User Guide

This user guide is intended for school operators, field photographers, and data entry personnel using the Android application to register students and capture ID card photographs.

---

## 1. Getting Started & Logging In

1. **Launch the Application**: Open **ID entity** on your tablet or smartphone.
2. **Select "School" Role**: Ensure the **School** tab is active on the login screen.
3. **Enter Credentials**:
   - Enter your assigned **School Name or Code** (e.g. `SACRED HEART CONVENT` or `shc`).
   - Enter your **Password**.
4. **Offline Test / Field Mode**: If you are in a remote area without an internet connection or Firebase setup, tap **"Debug: continue without Firebase"** to work locally. All data will be safely stored in the on-device SQLite database.

---

## 2. Main Dashboard

The Operator Dashboard presents large, high-contrast action cards designed for fast field operation:
- **New ID Card**: Start a new student registration form and photo capture.
- **Saved Entries**: View, filter, and inspect all student entries stored on the device.
- **Sync Status**: View pending uploads and trigger manual synchronization when internet is available.
- **Messages**: Communication channel with the central admin office.
- **Logout**: Safely exit your session.

> [!NOTE]
> If internet connection is lost, an amber **"Working offline. Entries are saved locally and will sync when connected."** banner automatically appears at the top of the screen.

---

## 3. Student Data Entry Form

### Form Fields & Validation
- **Automatic Capitalization**: All text entered into **Name, Father's Name, Class, Division, Mobile, and Address** is automatically transformed into uppercase.
- **Class & Division Dropdowns**: Select the student's class and division from the predefined school list, or type a custom division.
- **Date of Birth**: Tap the calendar picker to select the birth date; ages are validated automatically.
- **Duplicate Detection**: The system automatically detects potential duplicate entries with identical names and classes within the school and alerts you before saving.
- **Autosave & Draft Recovery**: If the app is closed or the device battery runs out, the form draft is restored on launch.

---

## 4. AI Camera & Photo Capture

### Step-by-Step Capture Flow
1. Tap **"Add Photo"** on the student form.
2. The camera screen opens with a **1.2 × 1.5 inch** aspect-ratio framing guide and dynamic guidance pill.
3. Align the student's head within the oval guide:
   - **Green pill ("Face Detected")**: The face is centered and ready for capture.
   - **Yellow / Warning pill ("No Face" / "Move Closer" / "Low Light")**: Adjust position, lighting, or framing.
4. Tap the capture button. The image processing pipeline will automatically:
   - Center and crop the face to 1.2 × 1.5 in.
   - Sample luminance to verify sufficient lighting.
   - Store both the processed crop and raw capture.
5. Tap **Accept** to attach the photo to the student form, or **Retake** if needed.

---

## 5. Review, Preview & Submission

1. After filling all fields and capturing the photo, tap **Save & Preview**.
2. A pixel-accurate 54 × 86 mm ID card preview is generated displaying the school header, photo, student details, and card styling.
3. Tap **Submit Entry** to finalize the record into the review queue.

---

## 6. Understanding Submission Statuses

In the **Saved Entries** list, each entry displays two status badges:
- **Approval Status**:
  - `Pending Review`: Waiting for the school administration to review and approve.
  - `Approved`: Signed off by the administrator and ready for the print run.
  - `Rejected`: Sent back with an explanation (e.g., *"Photo blurry"*, *"Incorrect class"*). Tap to edit and resubmit.
- **Sync Status**:
  - `Pending`: Saved locally on device; waiting for internet connection to upload.
  - `Synced`: Safely backed up to cloud storage.
  - `Failed`: Error during upload; tap Sync Status to retry.
