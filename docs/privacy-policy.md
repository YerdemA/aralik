---
layout: page
title: Gizlilik Politikası
lead: Kabaca hangi verileri nasıl kullanır? Kısa cevap, neredeyse hiçbirini.
description: Kabaca kişisel veri toplamaz. Oyun verileri cihazda kalır; istisnalar isteğe bağlı liderlik tablosu, düello ve turnuvadır.
updated: 7 Kasım 2026
---

Kabaca, Yusuf Erdem Aykaç tarafından geliştirilen bir tahmin oyunudur. Bu politika uygulamanın hangi verileri nasıl kullandığını açıklar.

## Kısaca
- **Kişisel veri toplamayız.** Hesap, giriş, reklam, analiz ya da takip aracı yoktur.
- **Oyun verilerin cihazında kalır.** Skorların, serin, kalibrasyonun ve cevapladığın soruların listesi yalnızca telefonunda saklanır.
- **İstisnalar isteğe bağlı: liderlik tablosu, düello ve turnuva.** Yalnızca sen katılırsan, seçtiğin ad ve cevapların gönderilir. Katılmazsan hiçbir şey gönderilmez.
- **İnternet yalnızca gerektiğinde.** Uygulama yeni soruları indirmek ve (katıldıysan) liderlik tablosu, düello ya da turnuva için bağlanır.
{: .summary}

## İnternet bağlantısı
Uygulama yeni soru ve veri dosyalarını en fazla 6 saatte bir `yerdema.github.io` adresinden indirir. Bu, GitHub Pages üzerinde duran herkese açık, statik bir dosyadır. Bu istekte senin hakkında hiçbir bilgi göndermeyiz.

Her internet isteğinde olduğu gibi, sunucuyu işleten GitHub bağlantı sırasında IP adresini ve cihaz bilgisini teknik kayıtlarında tutabilir. Bu kayıtlara erişimimiz yoktur. Ayrıntılar için [GitHub Gizlilik Bildirimi](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)'ne bakabilirsin.

İnternet yoksa uygulama, içindeki sorularla eksiksiz çalışmaya devam eder.

## Günün liderleri (isteğe bağlı)
Günün liderleri tablosuna katılmak tamamen isteğe bağlıdır. Katılmak için yalnızca Ayarlar'da seçtiğin **kullanıcı adı** gerekir; e-posta, telefon numarası, gerçek isim ya da giriş istenmez. Uygulamada tek bir kullanıcı adın vardır: tabloda, düelloda ve turnuvada aynı ad görünür. Bu ad, sunucuya gönderilene kadar yalnızca telefonunda durur.

Katıldığında şunlar Cloudflare üzerinde çalışan sunucumuza gönderilir ve saklanır:
- **Kullanıcı adın** (tablodaki takma adın),
- Uygulamanın ürettiği **rastgele bir kimlik** ve gizli bir anahtar (anahtarın yalnızca özeti saklanır), hesabın senin olduğunu kanıtlamak için,
- Bitirdiğin her günlük set için **5 cevabın (aralıkların)**, bunlardan hesaplanan **puanın ve isabet sayın**, ve gönderim zamanı.
- Kullanıcı adını en son ne zaman değiştirdiğin. Ad 3 günde bir değiştirilebilir; bu, adların kötüye kullanılmasını önlemek içindir.
- **Cihazının tek yönlü özeti.** Android'in her uygulamaya ayrı verdiği cihaz kimliğinden telefonunda üretilen bir özet (hash). Kimliğin kendisi telefondan çıkmaz; sunucu bu özeti bir kez daha özetleyerek saklar. Amacı hileyi önlemek: her cihazda tek hesap olur ve aynı günün puanı ikinci kez gönderilemez. Uygulamayı silip yeniden kurduğunda ya da verilerini temizlediğinde hesabın bu sayede geri gelir.

Bu yüzden uygulama, telefonunda tabloya katılmış bir hesap bulamadığında günde en fazla bir kez aynı özeti sunucuya sorar: "Bu cihazın hesabı var mı, bugünün setini gönderdi mi?" Cevaba göre hesabın geri gelir ve aynı günün seti yeniden oynanamaz. Tabloya hiç katılmamış bir cihaz için bu sorgudan sunucuda hiçbir şey saklanmaz.

Takma adın ve günlük puanın, o günün tablosunda diğer oyunculara görünür. Cevapların (aralıkların) kimseye gösterilmez; yalnızca puanı hesaplamak için kullanılır.

Hileyi ayıklamak için olağanüstü yüksek günlük puanlar (500 üzerinden 470 ve üstü) sunucuda "incelenecek" diye işaretlenir. Geliştirici bu puanlara bakabilir ve hile olduğu açık bir hesabı tablodan gizleyebilir; gizlenen hesap tabloyu kendisi görmeye devam eder, başka oyunculara görünmez. Bu işaret de puanla birlikte silinir.

Aynı cihazdan çok sayıda hesap açılmasını önlemek için, katılma isteğinin geldiği IP adresinin tek yönlü özeti (hash) en fazla 24 saat saklanır. IP adresinin kendisi saklanmaz. Sunucuyu işleten Cloudflare, her internet isteğinde olduğu gibi bağlantı bilgilerini kendi teknik kayıtlarında tutabilir; ayrıntılar için [Cloudflare Gizlilik Politikası](https://www.cloudflare.com/privacypolicy/)'na bakabilirsin.

Bu veriler yalnızca liderlik tablosu için kullanılır; satılmaz, reklam ya da analiz için kullanılmaz, başka kimseyle paylaşılmaz.

**Tablodan ayrılmak ve verilerini silmek için:** Ayarlar → Liderlik tablosu → Tablodan ayrıl. Sunucudaki hesabın (takma adın ve cihaz özetinle bağı) ve gönderdiğin tüm puanlar hemen silinir. Kullanıcı adın telefonunda kalır; düello ve turnuvada kullanılmaya devam eder, yeniden katılırsan tabloya yine bu adla girersin (ad o arada başkası tarafından alınmadıysa). Yalnızca cihaz özetinin hangi günler için puan gönderdiği bilgisi, adınla bağlantısız olarak en fazla 3 gün kalır; böylece aynı gün yeniden katılıp puan gönderilemez. Uygulamayı kaldırmışsan yeniden kurup tabloya katıldığında hesabın geri gelir, oradan ayrılabilirsin; istersen silinmesini aşağıdaki iletişim adresinden de isteyebilirsin.
{: .callout}

## Düello ve turnuva
Düello (arkadaşınla ya da rastgele bir rakiple) ya da turnuva (3–8 kişilik oda) oynadığında, aynı sunucudaki odaya şunlar gönderilir: Ayarlar'da seçtiğin **kullanıcı adın**, uygulamadaki soru sayısı ve kilitlediğin **aralıklar**. Hesap ya da kimlik gerekmez.

Rakip ararken de yalnızca kullanıcı adın ve soru sayısı gider. Adın ve aralıkların yalnızca o odadaki oyunculara gösterilir: düelloda rakibine, turnuvada odadaki herkese.

Bağlantın koparsa kaldığın yerden devam edebilmen için oda sana rastgele, tek kullanımlık bir **geri dönüş anahtarı** verir; bu anahtar yalnızca o odada ve oyun sürerken işe yarar. Turnuvada kurucunun odadan çıkardığı oyuncunun adı, aynı odaya yeniden girmesin diye oda açık kaldıkça tutulur.

Oda bittikten (ya da boş kaldıktan) en geç birkaç dakika sonra sunucudan tamamen silinir; hiçbir düello ya da turnuva verisi saklanmaz. Oynamazsan hiçbir şey gönderilmez.

Odaların kötüye kullanılmasını (örneğin binlerce oda açılmasını) önlemek için oda açma ve odaya bağlanma istekleri IP adresi başına dakikalık bir sınırla sayılır. Bu sayımı Cloudflare kısa süreliğine yapar; IP adresini biz saklamayız.

## Paylaşım
"Paylaş" düğmesine bastığında skor kartın, senin seçtiğin uygulamaya (örneğin bir mesajlaşma uygulamasına) Android'in paylaşım penceresi üzerinden gönderilir. Bu yalnızca sen istediğinde olur ve içerik yalnızca skorundur.

## Verilerin silinmesi
Cihazındaki tüm oyun verilerini (kullanıcı adın dahil) silmek için uygulamayı kaldırman ya da Android ayarlarından uygulamanın verilerini temizlemen yeterlidir. Liderlik tablosuna katıldıysan, önce Ayarlar → Liderlik tablosu → Tablodan ayrıl ile sunucudaki verini sil.

## Çocuklar
Uygulama hiçbir yaş grubundan kişisel veri istemez. Kullanıcı adı seçerken gerçek adını kullanmamanı öneririz.

## Veri kaynakları
Soruların cevapları açık lisanslı kaynaklardan gelir. Kaynakların ve lisanslarının listesi:
[Veri kaynakları ve lisanslar](attributions.md). Aynı liste uygulamada Ayarlar → Veri kaynakları ve
lisanslar ekranında da yer alır.

## Değişiklikler
Bu politika değişirse güncel hâli bu sayfada yayınlanır.

## İletişim
Soru ve önerilerin için: [github.com/YerdemA/aralik/issues](https://github.com/YerdemA/aralik/issues)
