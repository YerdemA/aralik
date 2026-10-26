# Kabaca — Veri Kaynakları ve Lisanslar

*Hazırlanma: 2026-10-26 · Hedef dosya: `docs/SOURCES.md`*

Bu belge soru bankasını büyütmek ve çeşitlendirmek için kullanılabilecek kaynakları listeler. Her kaynakta lisans, erişim yolu, atıf şartı ve çıkarılabilecek soru türleri belirtilmiştir.
Uygulama Google Play'de yayınlanacağı için **ücretsiz olsa bile ticari dağıtım sayılır**. Bu yüzden yalnızca ticari kullanıma izin veren kaynaklar "kullan" olarak işaretlendi.

> Bu bir hukuki görüş değildir. Lisans metinleri değişebilir. Yeni bir kaynak eklemeden önce `license_url` adresindeki güncel metne bakılmalıdır.

---

## 0. Uygulamaya dönük zorunlu kurallar (Claude Code için)

1. **Sayılar yalnızca bu listedeki kaynakların ham dökümlerinden gelir.** Dil modeli en fazla soru metnini yazar, sayı üretmez.
2. Her ham döküm `tools/raw/<kaynak>/` altında, indirme tarihiyle birlikte saklanır (`_meta.json`: url, tarih, lisans).
3. Her sorunun `source` alanı, cevabın doğrudan görülebildiği sayfaya işaret eder. Kaynağın genel ana sayfası yeterli değildir.
4. **Atıf ekranı zorunludur.** CC BY ve benzeri lisanslar atıf ister. Ayarlar → Hakkında → "Veri kaynakları ve lisanslar" ekranı eklenir ve aşağıdaki her kaynağın atıf satırını listeler. Ayrıca `docs/privacy-policy.md` yanına `docs/attributions.md` eklenir.
5. Değeri yıla göre değişen veriler (nüfus, çalışan sayısı, tüketim) `data_year` alanı olmadan bankaya girmez. Soru metninde yıl geçer ("2024'te …").
6. Sitelerin kullanım koşulları otomatik kazımayı (scraping) yasaklıyorsa o site yalnızca **elle doğrulama referansı** olur, toplu veri çekilmez.

---

## 1. Ana tablo

| # | Kaynak | Lisans | Ticari kullanım | Atıf | Durum |
|---|---|---|---|---|---|
| 1 | Wikidata | CC0 | Evet | Gerekmez (önerilir) | **Kullan** (mevcut) |
| 2 | Wikimedia Pageviews API | Veri CC0 | Evet | — | **Kullan** (mevcut, zorluk için) |
| 3 | AnAge (HAGR) | CC BY 3.0 | Evet | Zorunlu | **Kullan** |
| 4 | AnimalTraits | CC BY 4.0 | Evet | Zorunlu | **Kullan** |
| 5 | USDA FoodData Central | CC0 / kamu malı | Evet | İstenir | **Kullan** |
| 6 | NASA NSSDC Planetary Fact Sheets | ABD kamu eseri | Evet (onay ima etmeden) | İstenir | **Kullan** |
| 7 | USGS Deprem Kataloğu (ComCat) | Kamu malı | Evet | İstenir | **Kullan** |
| 8 | OurAirports | Kamu malı | Evet | İsteğe bağlı | **Kullan** |
| 9 | openfootball (football.json, worldcup.json) | Kamu malı | Evet | Gerekmez | **Kullan** |
| 10 | Dünya Bankası Açık Veri | CC BY 4.0 | Evet | Zorunlu | **Kullan** |
| 11 | FAOSTAT | CC BY 4.0 | Evet | Zorunlu | **Kullan** |
| 12 | Our World in Data | CC BY (yalnızca OWID'in kendi ürettiği veri) | Evet | Zorunlu | **Kullan, dikkatle** |
| 13 | İBB Açık Veri Portalı | İBB Açık Veri Lisansı 1.0 | Evet | Zorunlu | **Kullan** |
| 14 | Eurostat | Kaynak gösterilerek serbest | Evet (istisnalar var) | Zorunlu | **Kullan, dikkatle** |
| 15 | TÜİK Veri Portalı (özet tablolar) | Kaynak gösterilerek kullanım | Muhtemelen evet | Zorunlu | **Kullan, dikkatle** |
| 16 | Nobel Prize API | Çelişkili bilgi | Belirsiz | — | **Wikidata üzerinden kullan** |
| 17 | PubChem | Kamu malı + katkıcı hakları | Kısmen | — | **Wikidata üzerinden kullan** |
| 18 | Open Food Facts | ODbL (share-alike) | Evet ama paylaşım zorunluluğu | Zorunlu | **Kullanma** |
| 19 | Guinness World Records sitesi | Tüm hakları saklı | Hayır | — | **Yalnızca elle referans** |
| 20 | Vikipedi metni | CC BY-SA 4.0 | Evet ama metin kopyalanırsa share-alike | Zorunlu | **Yalnızca referans, metin kopyalama** |

---

## 2. Kaynak ayrıntıları

### 1. Wikidata (mevcut hattın genişletilmesi)
- **Lisans:** Ana, property ve lexeme ad alanlarındaki tüm yapılandırılmış veri CC0'dır. https://www.wikidata.org/wiki/Wikidata:Licensing
- **Erişim:** https://query.wikidata.org/sparql (mevcut iki aşamalı yöntem)
- **Çeşitlilik için yeni veri setleri (mevcut coğrafya ve tarihin dışında):**

| Veri seti | Örnek property | Kategori | Örnek soru kalıbı |
|---|---|---|---|
| Hayvan türleri | kütle (P2067), boy (P2048), ömür (P2250) | hayvanlar | "Bir Afrika fili kaç kilogram gelir?" |
| Şirketler | kuruluş (P571), çalışan sayısı (P1128) | şirketler | "[Şirket] hangi yıl kuruldu?" |
| Filmler | hasılat (P2142), yayın yılı | kültür | "[Film] dünya genelinde kaç dolar hasılat yaptı?" |
| Gökdelenler, kuleler | yükseklik (P2048) | yapılar | "[Yapı] kaç metre?" |
| Stadyumlar | kapasite (P1083) | spor | "[Stadyum] kaç kişilik?" |
| Nobel ödülleri | alınan ödül (P166) + tarih | bilim | "[Kişi] Nobel'i hangi yıl aldı?" |
| Kimyasal elementler | erime ve kaynama noktası, atom numarası | bilim | "Demir kaç derecede erir?" |
| Uçak ve araç modelleri | üretim adedi (P1092), hız | teknoloji | "[Model] toplam kaç adet üretildi?" |
| İcatlar ve ürünler | ilk çıkış yılı | gündelik | "İlk [ürün] hangi yıl satışa çıktı?" |

- **Not:** Property kimlikleri kullanılmadan önce https://www.wikidata.org/wiki/Property:Pxxxx sayfasında doğrulanmalıdır. Birim (`wikibase:quantityUnit`) her zaman okunup dönüştürülmelidir. Mevcut "çelişen değerleri at" kuralı burada da geçerlidir.

### 2. Wikimedia Pageviews API
- Zaten kullanılıyor. Zorluk tahmininde "tanınırlık" sinyali olarak da kullanılmalı: yüksek okunma → kolay.

### 3. AnAge — Hayvan yaşlanması ve ömür veritabanı
- **İçerik:** 4.600'den fazla türün azami ömrü, gebelik süresi, cinsel olgunluk yaşı, doğum ağırlığı, yetişkin ağırlığı ve bazal metabolizma hızı.
- **Lisans:** HAGR içeriği CC BY 3.0 ile lisanslıdır. Ticari kullanım dahil her amaçla serbesttir, HAGR'nin kullanıldığının belirtilmesi şarttır. https://genomics.senescence.info/legal.html
- **Erişim:** https://genomics.senescence.info/species/ → "Downloading AnAge" (zip, sekmeyle ayrılmış tablo)
- **Soru kalıpları:** "[Hayvan] en fazla kaç yıl yaşadığı kaydedilmiştir?", "[Hayvan]'ın gebelik süresi kaç gün?", "Bir [hayvan] yavrusu doğduğunda kaç gram gelir?"
- **Kurallar:** Yalnızca `Data quality` alanı "high" veya "acceptable" olan ve `Sample size` alanı boş olmayan kayıtlar alınır. Türkçe adı Wikidata'dan bilimsel ad eşleştirmesiyle alınır. Türkçe adı olmayan tür soru olmaz.
- **`source`:** `https://genomics.senescence.info/species/entry.php?species=<Genus_species>`
- **Atıf:** "AnAge: The Animal Ageing and Longevity Database, HAGR (de Magalhães ve ark.), CC BY 3.0"

### 4. AnimalTraits
- **İçerik:** Yaklaşık 2.000 kara hayvanı türünün vücut kütlesi, metabolizma hızı ve beyin büyüklüğü. Her kayıt özgün hakemli yayına bağlanır.
- **Lisans:** CC BY 4.0. https://www.nature.com/articles/s41597-022-01364-9
- **Erişim:** https://animaltraits.org/ veya Zenodo (`observations.csv`)
- **Soru kalıpları:** "Bir [hayvan]'ın beyni kaç gram?", "Bir [böcek] kaç miligram gelir?"
- **Kurallar:** Tür başına birden çok ölçüm varsa medyan alınır ve `fun_fact` alanına ölçüm sayısı yazılır.
- **Atıf:** "AnimalTraits (Herberstein ve ark., 2022), CC BY 4.0"

### 5. USDA FoodData Central
- **İçerik:** Yiyeceklerin besin değerleri (kalori, protein, şeker, kafein vb.).
- **Lisans:** Kamu malı, CC0 1.0. FoodData Central'ın kaynak olarak belirtilmesi istenir. https://fdc.nal.usda.gov/
- **Erişim:** https://fdc.nal.usda.gov/download-datasets → "Foundation Foods" ve "SR Legacy" (CSV). Markalı ürünler (Branded Foods) **kullanılmaz**, çünkü marka içerirler ve sık değişirler.
- **Soru kalıpları:** "100 gram fındıkta kaç kalori var?", "Bir fincan filtre kahvede kaç mg kafein var?", "100 gram ıspanakta kaç mg demir var?"
- **Kurallar:** Türkiye'de yaygın, tanınan yiyecekler için Türkçe ad listesi elle hazırlanır (`tools/foods_tr.csv`: fdc_id → Türkçe ad). Birim her zaman "100 g başına" olarak soru metnine yazılır.
- **Atıf:** "USDA FoodData Central, CC0"

### 6. NASA NSSDC Planetary Fact Sheets
- **İçerik:** Gezegenler, Ay ve uydular için kütle, çap, yerçekimi, gün ve yıl uzunluğu, Güneş'e uzaklık, sıcaklık, uydu sayısı.
- **Lisans:** NASA içeriği ABD'de genellikle telif hakkına tabi değildir. NASA kaynak olarak belirtilmeli, onay ima edilmemeli ve logo kullanılmamalıdır. https://www.nasa.gov/nasa-brand-center/images-and-media/
- **Erişim:** https://nssdc.gsfc.nasa.gov/planetary/factsheet/ (tek HTML tablo, elle CSV'ye aktarılabilir, kırk hücre civarı)
- **Soru kalıpları:** "Mars'ta bir gün kaç saat sürer?", "Jüpiter'in kaç bilinen uydusu var?", "Ay Dünya'dan ortalama kaç km uzakta?"
- **Kural:** Uydu sayısı gibi değişen değerler `data_year` ile girilir.
- **Atıf:** "NASA Goddard Space Flight Center, NSSDC Planetary Fact Sheets"

### 7. USGS Deprem Kataloğu (ComCat)
- **İçerik:** Dünya geneli depremler: tarih, büyüklük, derinlik, konum.
- **Lisans:** ABD hükümeti eseri, kamu malı. https://earthquake.usgs.gov/fdsnws/event/1/
- **Erişim:** `https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minmagnitude=7&starttime=1900-01-01`
- **Soru kalıpları:** "1999 Gölcük depremi kaç km derinlikte oldu?", "[Deprem] büyüklüğü kaçtı?"
- **Not:** Büyüklük için tahmin aralığı çok dar kalacağı için **büyüklük yerine derinlik ve yıl** sorulmalı. Mevcut Wikidata deprem veri setini çapraz doğrulamak için de kullanılabilir.
- **Atıf:** "U.S. Geological Survey, ANSS ComCat"

### 8. OurAirports
- **İçerik:** Dünyadaki havalimanları, pist uzunlukları, rakımlar, koordinatlar.
- **Lisans:** Tüm veri kamu malına bırakılmıştır, atıf zorunlu değildir. https://ourairports.com/data/
- **Erişim:** https://davidmegginson.github.io/ourairports-data/airports.csv ve `runways.csv`
- **Soru kalıpları:** "İstanbul Havalimanı'nın en uzun pisti kaç metre?", "Dünyanın en yüksek rakımlı havalimanı kaç metrede?"
- **Kural:** Yalnızca `type = large_airport` olanlar alınır. Fit cinsinden değerler metreye çevrilir.
- **Ek fikir:** Cihazda yeni bir üretici yazılabilir: "İstanbul Havalimanı ile [başkent havalimanı] arası kaç km?"

### 9. openfootball
- **İçerik:** Dünya Kupası, Avrupa Şampiyonası, Şampiyonlar Ligi ve büyük ligler (Süper Lig dahil) maç sonuçları.
- **Lisans:** Veri, şema ve scriptler kamu malına bırakılmıştır. https://github.com/openfootball/football.json
- **Erişim:** `https://raw.githubusercontent.com/openfootball/worldcup.json/master/<yıl>/worldcup.json` ve `openfootball/europe` (Türkiye dahil).
- **Soru kalıpları (hesaplanmış):** "2018 Dünya Kupası'nda toplam kaç gol atıldı?", "Bir Süper Lig sezonunda maç başına ortalama kaç gol düşüyor?"
- **Kural:** Hesaplanan toplamlar script ile üretilir, `source` alanına ham dosyanın GitHub linki yazılır. Eksik maç içeren sezonlar atlanır.

### 10. Dünya Bankası Açık Veri
- **İçerik:** Ülke göstergeleri: ortalama yaşam süresi, internet kullanım oranı, kişi başı CO₂, orman alanı, turist sayısı.
- **Lisans:** Dünya Bankası API'sindeki veriler, aksi belirtilmedikçe CC BY 4.0'dır. https://datacatalog.worldbank.org/
- **Erişim:** `https://api.worldbank.org/v2/country/TUR/indicator/SP.DYN.LE00.IN?format=json` (anahtar gerekmez)
- **Soru kalıpları:** "2023'te Japonya'da ortalama yaşam süresi kaç yıl?", "Türkiye'ye 2023'te kaç turist geldi?"
- **Kural:** Her göstergenin kaynak alanı kontrol edilir. Üçüncü taraf kısıtı olan göstergeler alınmaz.
- **Atıf:** "The World Bank, World Development Indicators, CC BY 4.0"

### 11. FAOSTAT
- **İçerik:** Gıda ve tarım: ülkelere göre fındık, çay, zeytin üretimi, balıkçılık, orman ürünleri.
- **Lisans:** FAO istatistik veritabanlarındaki veri setleri, aksi belirtilmedikçe CC BY 4.0'dır. FAO'ya atıf zorunludur. https://www.fao.org/contact-us/terms/db-terms-of-use
- **Erişim:** https://www.fao.org/faostat/en/#data → toplu indirme (CSV)
- **Soru kalıpları (Türkiye'ye çok uygun):** "Türkiye 2023'te kaç ton fındık üretti?", "Dünyada yılda kaç ton çay üretiliyor?"
- **Kural:** Üçüncü taraf verisi olarak işaretlenmiş satırlar (flag) alınmaz.
- **Atıf:** "FAO. FAOSTAT. Lisans: CC BY 4.0"

### 12. Our World in Data
- **Lisans:** Yalnızca OWID'in kendi ürettiği veri CC BY'dir. Sitedeki verinin çoğu üçüncü taraflardan gelir ve onların lisansına tabidir. https://ourworldindata.org/faqs
- **Kural:** Yalnızca kaynak alanında "Our World in Data based on …" ya da "Official data collated by Our World in Data" yazan veriler alınır. Diğerleri için asıl kaynağa (örneğin Dünya Bankası) gidilir.
- **Soru kalıpları:** Uzun dönem tarih serileri ("1900'de dünya nüfusu kaçtı?"), enerji, aşılama.
- **Atıf:** "Our World in Data, CC BY"

### 13. İBB Açık Veri Portalı
- **İçerik:** İstanbul'un gündelik hayat verileri: toplu taşıma yolculukları, vapur seferleri, su tüketimi, park sayıları.
- **Lisans:** İBB Açık Veri Lisansı 1.0. Bilgiyi kopyalamaya, uyarlamaya ve kendi uygulamanıza ekleyerek ticari olarak kullanmaya izin verir. CC BY 4.0 ile uyumludur. https://data.ibb.gov.tr/license
- **Erişim:** CKAN API: `https://data.ibb.gov.tr/api/3/action/package_search?q=...`
- **Soru kalıpları (gündelik kategori için çok değerli):** "İstanbul'da 2024'te günde ortalama kaç toplu taşıma yolculuğu yapıldı?", "İstanbul'da bir yılda kaç vapur seferi yapılıyor?"
- **Kural:** Soru metninde mutlaka yıl geçer. Kaynak linki veri seti sayfasıdır.
- **Atıf:** "İstanbul Büyükşehir Belediyesi Açık Veri Portalı, İBB Açık Veri Lisansı"
- **Not:** İzmir ve Ankara büyükşehir belediyelerinin de açık veri portalları var. Lisansları ayrıca kontrol edilmeden kullanılmaz.

### 14. Eurostat
- **Lisans:** Veriler kaynak gösterilerek ticari ve ticari olmayan amaçla yeniden kullanılabilir. **Ancak** başka kaynaklara ait veriler (örneğin ABD, Japonya, Çin) ticari amaçla kullanılamaz. https://ec.europa.eu/eurostat/help/copyright-notice
- **Kural:** Yalnızca AB, EFTA ve aday ülke (Türkiye dahil) satırları alınır.
- **Soru kalıpları:** "Almanya'da kişi başı yılda kaç kg et tüketiliyor?", "AB'de ortalama ilk evlenme yaşı kaç?"
- **Atıf:** "Source: Eurostat, [veri kodu], [erişim tarihi]"

### 15. TÜİK Veri Portalı
- **Lisans durumu:** Resmî bir açık lisans metni (CC BY gibi) bu araştırmada **doğrulanamadı**. Yaygın uygulama, özet istatistik tablolarının kaynak gösterilerek kullanılmasıdır. Mikro veriler ise kesinlikle kullanılmaz, çünkü üçüncü kişilere verilemez.
- **Erişim:** https://data.tuik.gov.tr (tablolar elle indirilir, `tools/tuik/` altında saklanır)
- **Kural:** Yalnızca yayımlanmış özet tablolar kullanılır. Her soruda "TÜİK, [tablo adı], [yıl]" atfı yapılır. Yayın öncesinde portalın kullanım koşulları sayfası okunmalı ve gerekirse TÜİK'e e-posta ile sorulmalıdır.
- **Soru kalıpları:** "Türkiye'de 2024'te kaç bebek doğdu?", "Türkiye'de trafiğe kayıtlı kaç otomobil var?", "Türkiye'de ortalama ilk evlenme yaşı kaç?"

### 16. Nobel Prize API
- 2013 tarihli resmî basın bülteni açık verinin CC0 olduğunu söylüyor. Ancak güncel üçüncü taraf kaynaklar API'yi "ticari olmayan kullanım" için tanımlıyor. **Belirsiz.**
- **Karar:** Nobel verisi Wikidata'dan (CC0) çekilir, Nobel API kullanılmaz.

### 17. PubChem
- PubChem kamu malı olarak tanımlanıyor, ancak katkıcıların gönderdiği verilerde ayrı haklar olabiliyor.
- **Karar:** Element ve basit bileşik özellikleri Wikidata'dan çekilir. PubChem yalnızca elle doğrulama referansıdır.

### 18. Open Food Facts — kullanma
- ODbL lisanslıdır. Uyarlanmış bir veritabanı kamuya açık kullanılırsa onun da ODbL ile sunulması gerekir. Bankamız GitHub Pages'te yayımlandığı için bu yükümlülük karmaşa yaratır. Veri de markalı ürün odaklıdır. https://wiki.openfoodfacts.org/ODBL_License
- **Karar:** Kullanılmaz. Besin değerleri için USDA kullanılır.

### 19. Guinness World Records — yalnızca elle referans
- Kullanım koşullarına göre kullanıcının sitedeki içerik üzerinde hiçbir hakkı yoktur. https://www.guinnessworldrecords.com/using-this-website/terms-and-conditions
- **Karar:** Toplu çekim ya da kazıma yapılmaz, metin kopyalanmaz. Bir rekorun sayısı (tek bir olgu) küratörlü hatta, Guinness sayfası `source` olarak gösterilerek ve **elle doğrulanarak** kullanılabilir.

### 20. Vikipedi
- Metin CC BY-SA'dır. Metin cümleleri `fun_fact` alanına **kopyalanmaz**, kendi cümlemizle yazılır.
- Kaynakçalı Vikipedi listeleri ("en uzun …", "rekorlar listesi") küratörlü hat için **aday bulma** aracıdır. Sayı, listenin gösterdiği birincil kaynaktan doğrulanır.

---

## 3. Küratörlü hat (ilginç bilgi soruları)

Yapılandırılmış veritabanlarında olmayan "en uzak gol", "en hızlı servis" tarzı sorular için.

### Kabul kuralları
1. Tek, ölçülmüş, sayısal bir cevap olmalı ("yaklaşık", "bazı kaynaklara göre" yok).
2. Cevap birincil ya da güvenilir bir ikincil kaynakta açıkça yazmalı: resmî federasyon, kulüp, bilimsel yayın, resmî kurum ya da Guinness'in tekil rekor sayfası.
3. İnternette dolaşan ama ölçümü olmayan "ilginç bilgiler" reddedilir.
4. Rekor soruları "[tarih] itibarıyla" ifadesiyle yazılır, çünkü rekorlar kırılır.

### Dosya biçimi: `tools/curated/<kategori>.yaml`
```yaml
- key: longest-goal-distance          # kalıcı anahtar, id değil
  text: "Resmî maçta en uzak mesafeden atılan gol kaç metreden atıldı? (2024 itibarıyla)"
  answer: 0                            # kaynaktan elle girilir
  unit: m
  kind: magnitude
  category: spor
  data_year: 2024
  source: "https://..."                # cevabın görüldüğü sayfa
  source_excerpt: ""                   # verify_curated.py doldurur
  verified: pending                    # pending | auto | manual | rejected
  verified_at: null
  anchor: null                         # isteğe bağlı çapa (kendi kaynağıyla)
  fun_fact: ""                         # kendi cümlemiz
```

### `tools/verify_curated.py` davranışı
1. `verified: pending` kayıtlarının `source` sayfasını indirir (zaman aşımı 15 sn, açık bir User-Agent ile).
2. Sayfa metnini düz metne çevirir, `answer` değerini farklı biçimlerde arar: `96.01`, `96,01`, `96.0`, `96`, ayrıca fit/mil gibi birim çevrimleri.
3. Bulursa çevresindeki ~120 karakteri `source_excerpt` alanına yazar ve `verified: auto` yapar.
4. Bulamazsa ya da sayfa açılmazsa (403, bot engeli) kaydı `needs_manual` listesine ekler. Bu kayıtlar geliştirici tarafından elle `manual` olarak işaretlenir.
5. `rejected` ve `pending` kayıtlar `build_questions.py` tarafından **asla** bankaya alınmaz.
6. Guinness gibi kazımaya izin vermeyen alan adları için script istek göndermez, doğrudan `needs_manual` listesine ekler. Engelli alan adları listesi: `tools/curated/no_fetch_domains.txt`.

---

## 4. Kategori → kaynak haritası

| Kategori | Birincil kaynaklar |
|---|---|
| coğrafya | Wikidata, OurAirports, NASA (uzay) |
| tarih | Wikidata, USGS (depremler) |
| spor | Wikidata (stadyum, kulüp), openfootball, küratörlü hat |
| türkiye | TÜİK, İBB, FAOSTAT (Türkiye satırları), Wikidata |
| gündelik | USDA FoodData, İBB, TÜİK, Dünya Bankası |
| bilim | Wikidata (elementler, Nobel), NASA, AnAge, AnimalTraits |
| **hayvanlar** (yeni) | AnAge, AnimalTraits, Wikidata |
| **şirketler** (yeni) | Wikidata (kuruluş yılı, çalışan sayısı) |
| **uzay** (yeni, istenirse bilimden ayrılabilir) | NASA |

Yeni kategoriler (`hayvanlar`, `şirketler`) için `Question.fromJson` doğrulaması, `core/theme.dart` kategori renk ve ikonları ve `strings.dart` güncellenmelidir.

---

## 5. Önerilen uygulama sırası
1. ✅ Atıf altyapısı: `docs/attributions.md` ve Ayarlar → Hakkında → Veri kaynakları ekranı. *(2026-10-26: tek kaynak listesi `tools/sources.json`, üretici `tools/build_attributions.py`, ham dökümler `tools/raw/<kaynak>/` + `_meta.json`.)*
2. ✅ Wikidata genişlemesi (hayvanlar, şirketler, yapılar, elementler, Nobel). *(2026-10-26: 9 yeni veri seti, 122 yeni soru. Notlar: hayvan verisi Wikidata'da zayıf; kütle yalnızca "yetişkin ağırlığı" niteleyicili değerlerden alınır, ömür (P2250) Wikidata'nın tamamında ~70 türde var. Sıcaklıklar kelvin gelir ve °C'ye çevrilir, yalnızca ≥ 100 °C sorulur. Q80061'in Türkçe etiketi hatalı olduğu için Nobel adları sabit listeden gelir.)*
3. USDA FoodData + AnAge: gündelik ve hayvan kategorilerini hızla doldurur.
4. NASA + OurAirports + openfootball.
5. Dünya Bankası + FAOSTAT + İBB + TÜİK (yıl bilgili sorular).
6. Küratörlü hat ve `verify_curated.py`, ilk 50 kayıt.

Hedef dağılım (450 soru): hiçbir kategori %25'i, hiçbir tek veri seti %10'u geçmesin.
