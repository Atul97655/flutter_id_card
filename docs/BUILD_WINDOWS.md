# Building the Windows (Admin / Print) Desktop App

The Android build is what operators use in schools. The **Windows build is the
admin office workstation** — it is the only platform where the bulk‑print
workflow works end to end, because it is the only one with a real file manager
and a default‑printer / silent print queue:

| Capability | Android | Windows |
|---|---|---|
| Enter students, capture photos | ✅ | ✅ (works, but not the intended use) |
| Review / approve / reject submissions | ✅ | ✅ |
| Generate imposition sheets (12×18, A4) & single‑card PDFs | ✅ | ✅ |
| **"Open folder"** to reveal the exported PDFs | ❌ | ✅ |
| **"Print all (N)"** — send a whole batch to one printer, no dialog per file | ❌ | ✅ |

`ExportService.canOpenFolder` / `canPrintDirectly` gate these in the UI, so the
buttons simply aren't shown on Android rather than failing silently.

---

## 1. One‑time prerequisites (on the build machine)

Flutter for Windows compiles native C++, so it needs the Microsoft C++
toolchain. `flutter doctor` will say **"Visual Studio not installed"** until this
is done.

1. Install **Visual Studio 2022 Community** (free): <https://visualstudio.microsoft.com/downloads/>
2. In the installer, tick the **"Desktop development with C++"** workload and
   install it with its default components. (Visual Studio *Code* is not the same
   thing and will not work.)
3. Reboot if the installer asks, then confirm:

   ```bash
   flutter doctor
   ```

   The line **`[√] Visual Studio - develop Windows apps`** must be a check, not
   an `X`.

Windows desktop support is already enabled in this checkout; if you ever need to
re‑enable it: `flutter config --enable-windows-desktop`.

---

## 2. Build

From the project root:

```bash
flutter pub get
flutter build windows --release
```

Output lands in:

```
build\windows\x64\runner\Release\
    id_entity.exe        <- the app
    *.dll                <- Flutter + plugin runtimes
    data\                <- assets, fonts, icu
```

`flutter run -d windows` launches a debug build for quick checks without
packaging.

---

## 3. Hand‑off package

The `.exe` **cannot run on its own** — it needs the sibling DLLs and the `data\`
folder next to it. To give the admin office a copy:

1. Zip the **entire `Release\` folder** (not just the exe).
2. On the target PC, unzip anywhere (e.g. `C:\ID entity\`) and run
   `id_entity.exe`. No installer, no admin rights required.
3. There is a Visual C++ runtime dependency that is present on virtually all
   Windows 10/11 machines; if the app fails to start with a `VCRUNTIME140*.dll`
   error, install the **Microsoft Visual C++ 2015–2022 Redistributable (x64)**
   on that PC once.

> The Windows build has **no `applicationId`** the way Android does, so none of
> this affects Firebase registration. It signs in to the same Firebase project
> and reads the same Firestore data as the Android app.

---

## 4. The bulk‑print workflow on Windows

1. Launch `id_entity.exe`, sign in with the **admin** account.
2. **Admin → pick a school → Print & Export.**
3. Choose crop marks / bleed, then **Generate** the sheet type you need. PDFs are
   written to:

   ```
   C:\Users\<you>\Documents\Output\<School Name>\12x18_Sheets\  (or A4_Sheets\, Single_Cards\)
   ```

4. **Open folder** reveals them in Explorer. **Print all (N)** asks you to pick a
   printer *once*, then sends every sheet to it with no further dialogs.
   **Print first** sends a single sheet through the normal print dialog — use it
   for a test print before committing a full run.
5. In the printer dialog, set scaling to **100% / Actual Size** — never "Fit to
   page". See [`PRINT_CALIBRATION_GUIDE.md`](PRINT_CALIBRATION_GUIDE.md) for the
   full driver settings and the ruler check that a 54 × 86 mm card really
   measures 54 × 86 mm.

---

## 5. Branding note

The window title, the taskbar name, the `.exe` file‑version metadata and the
app icon are all set to **ID entity** (`windows/runner/main.cpp`,
`windows/runner/Runner.rc`, `windows/CMakeLists.txt`,
`windows/runner/resources/app_icon.ico`). The `CompanyName` /
`LegalCopyright` strings in `Runner.rc` currently also read "ID entity" — change
them there if the client wants their registered business name on the file
properties instead.
