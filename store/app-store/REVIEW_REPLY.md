# App Review yanıtı (Guideline 2.1, bilgi istendi)

Aşağıdaki İngilizce metni hem "Reply to App Review" mesajına hem de App Review Information > Notes alanına yapıştırın. Ekran kaydı (1. madde) fiziksel cihazda sizin çekmeniz gereken tek şey; çekim planı en altta.

---

Hello,

Thank you for the review. Here is the requested information for Take a Pill (1.0.0, build 1).

**1. Screen recording**
Attached/linked: recorded on a physical iPhone running the latest iOS, starting from app launch and showing onboarding, adding a medication, receiving a dose reminder (notification and alarm mode), marking a dose as taken, and the history screen. The app has no account registration, login, account deletion, user-generated content, or paid content, so none of those flows exist.

**2. Purpose and target audience**
Take a Pill is a simple medication reminder. Users enter a medication's name, dose, schedule and relation to meals once, and the app reminds them at the right time with a local notification or an alarm. It helps people who forget to take medication, take several medications at different times, follow antibiotic courses, take daily contraceptives or supplements, or set up a simple reminder for older family members. It is a reminder tool only: it gives no medical advice, diagnosis or treatment, and says so in the app and the description.

**3. Setup and access**
No account, login, credentials or sample files are needed. Everything works offline after install.
1. Launch the app and complete onboarding (name is optional, set meal times, choose "Notification" or "Alarm", allow notifications).
2. Tap add medication, enter a name, dose type and a schedule (for example daily, a time 2 minutes from now).
3. When the time arrives, a notification with Taken / Snooze / Skip appears. In Alarm mode on iOS 26+, an AlarmKit alarm appears on the Lock Screen and Dynamic Island with Snooze / Open buttons (allow the alarm permission when asked). On earlier iOS versions an alarm-sound notification is used.
4. The Today and History screens show doses and adherence.

**4. External services**
None. There is no server, account system, analytics, advertising, payment processor or AI service. All data is stored on the device in SQLite. Apple frameworks only: UserNotifications (local notifications), AlarmKit (iOS 26+), and StoreKit's standard rating prompt (SKStoreReviewController), shown at most 3 times.

**5. Regional differences**
The app behaves identically in all regions. The current version is available in Turkish only; features and content do not vary by region.

**6. Regulated industry / third-party material**
Not applicable. The app does not provide medical advice, does not use HealthKit, makes no clinical claims, and contains no protected third-party material.

Thank you,
Hasan Kaan Kahraman

---

## Ekran kaydı çekim planı (fiziksel iPhone, güncel iOS)

1. Uygulamayı silip yeniden kurun; kaydı ana ekrandan uygulamayı açarak başlatın.
2. Onboarding: yemek saatleri, "Alarm" seçimi, bildirim ve alarm izinleri.
3. İlaç ekle: bir ilaç, 2 dakika sonrasına günlük.
4. Telefonu kilitleyin; alarmın kilit ekranında çıkmasını, "Ertele" ve "Aç" butonlarını gösterin.
5. Bugün ekranında dozu "Aldım" işaretleyin, sonra Geçmiş ekranını gösterin.
6. Ayarlar > Gizlilik ekranını kısaca gösterin.
7. Dosyayı App Store Connect yanıtına ekleyin (veya bağlantı verin).
