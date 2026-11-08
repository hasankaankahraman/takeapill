# App Review notları: reklamlı sürüm

Reklamlı ilk iOS sürümünü incelemeye gönderirken aşağıdaki İngilizce metni App Review Information → Notes alanına yapıştırın. [REVIEW_REPLY.md](REVIEW_REPLY.md) reklamsız 1.0.0 içindir; onun 4. maddesi ("no advertising") bu sürüm için yanlış olur.

Göndermeden önce: App Privacy etiketi [BEYAN.md](BEYAN.md) §3'teki tabloyla güncellendi, gizlilik politikası sayfası reklamlı sürümle yayında.

---

Hello,

Take a Pill is a medication reminder. No account, login or sample data is needed; everything works offline after install.

**What changed in this version: advertising**
- The app shows a single Google AdMob banner above the bottom tab bar, only after onboarding. There are no ads on onboarding, permission prompts, dose action buttons, notifications, or AlarmKit alarms.
- Ads are requested as non-personalized. The app does not use App Tracking Transparency, does not request the IDFA and does not track users, so the App Privacy label lists no "Data Used to Track You".
- Health data is never used for advertising (Guideline 5.1.3): medication names, doses, schedules, history and the optional user name stay on the device and are never added to ad requests or sent to Google or any other party.
- In the EEA, UK and Switzerland, Google's consent form (UMP) is shown before ads load, and Settings → Destek → "Reklam gizlilik seçenekleri" lets users change their choice.
- The privacy policy is linked in Settings → Destek → "Gizlilik Politikası" and at https://hasankaankahraman.github.io/takeapill/privacy.html

**How to test**
1. Complete onboarding (name optional, meal times, choose "Bildirim" (notification) or "Alarm", allow notifications).
2. Add a medication with a daily time 2 minutes from now.
3. At that time a notification with Taken / Snooze / Skip appears. In Alarm mode on iOS 26+, an AlarmKit alarm appears on the Lock Screen and Dynamic Island with Snooze / Open.
4. The Today and History screens show doses and adherence; the banner appears above the tab bar.

**Services**
Google Mobile Ads SDK (advertising only). Apple frameworks: UserNotifications, AlarmKit (iOS 26+), StoreKit rating prompt. No server, analytics, accounts, payments, HealthKit or AI services. The app gives no medical advice, diagnosis or treatment.

Thank you,
Hasan Kaan Kahraman
