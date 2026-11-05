# App Review cevabı — Submission 8c516020-8f76-454c-a8b0-e9cc8a3f280d

Guideline 2.1(a) · "The Save button was unresponsive" · Build 1.0 (3)

## Gönderilecek metin (İngilizce)

```
Hello,

Thank you for the detailed report and the screenshot — they let us reproduce
the issue immediately.

WHAT CAUSED IT

The screenshot shows the "Yeni deneme" (New mock exam) screen. On that screen
the exam name field sits at the very top, and it scrolls out of view once the
user scrolls down to enter the per-subject results. Our save handler treated
the name as required and returned early when it was empty — without saving,
without navigating, and without showing any message. So the Save button was
indeed unresponsive: it did nothing and explained nothing.

This was not a crash and not specific to iPad; the same result occurs on
iPhone. Your reviewer hit it because they entered the results without typing
a name, which is the natural thing to do when the name field is off-screen.

WHAT WE CHANGED IN BUILD 1.0 (4)

1. The exam name is no longer required. If it is left empty, the app derives
   a name from the exam date, and that exact name is shown as the field's
   placeholder — so what will be saved is visible before Save is pressed.
   Save now always saves and always navigates to the saved exam.

2. We audited every other button in the app for the same defect and fixed the
   two remaining cases (add subject, add task). Where an input is genuinely
   required, the button is now visibly disabled instead of silently doing
   nothing when pressed.

3. Every save path now handles write failures by re-enabling the button and
   showing an error message, so a failed write can never leave a button
   permanently dead.

HOW WE VERIFIED IT

We reproduced your exact steps in an automated UI test running on an
iPad Air 11-inch (M3) simulator. The test fails on build 1.0 (3) and passes
on build 1.0 (4). The full test suite (154 tests) passes as well.

Thank you again for catching this.
```

## Türkçe karşılığı (istenirse)

Aynı metnin Türkçesi App Store Connect'te de kabul ediliyor; İngilizce
gönderilmesi incelemeyi hızlandırdığı için varsayılan yukarıdaki.
