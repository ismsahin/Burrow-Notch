# Örnek: yeni bir AppleScript destekli oynatıcı eklemek

1. `MediaPlayer` (`Burrow/Features/Media/MediaInfo.swift`) içine `case` ekle: bundle ID, `displayName`, `changeNotification`
   (oynatıcının dağıtık bildirimi yoksa periyodik yoklama yeterli; `MediaController` zaten çalışan tüm oynatıcıları yoklar).
2. `PlayerScripts.status/artwork/command` içine betikleri ekle. Alan sırası **değişmemeli**:
   `[durum, ad, sanatçı, albüm, süre, konum, kimlik]`. Her betik `with timeout of 2 seconds` içermeli (test bunu denetler).
3. Süre milisaniye dönüyorsa `MediaController.refresh` içindeki `durationIsMilliseconds` koşulunu güncelle.
4. Kapak URL dönüyorsa alan adını `MediaController.artworkHosts` izin listesine ekle (yalnızca https).
5. `MediaInfoParserTests`'e örnek çıktı testi ekle.
