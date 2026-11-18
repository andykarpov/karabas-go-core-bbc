# Ядро BBC Micro для Karabas Go / Mini / Mini G

Acorn BBC Micro Model B и BBC Master 128 для плат Karabas (Xilinx Spartan-6 XC6SLX25). Порт [BeebFpga](https://github.com/hoglet67/BeebFpga) Дэвида Бэнкса (hoglet67), на основе работы Майка Стирлинга, с контроллерами дисковода 8271 / 1770 и плеером кассет UEF из [BBCMicro.Alternate](https://github.com/Welsh71/BBCMicro.Alternate_MiSTer) Пола Стюарта (Welsh71).

Состояние: собрано для Go, Mini и Mini G (`src/bbc.kg`, один файл на все платы); проверено на Mini G, Go и Mini на плате ещё не запускались. План и история — `docs/PLAN.md`.

## Как пользоваться

- **Модель**: OSD *Model* = Model B (6502) или Master 128 (65C02). Смена — сброс машины.
- **Клавиатура** позиционная, как в BeebFpga (клавиши там, где на клавиатуре BBC): F12 = BREAK, Shift+F12 = Shift+BREAK, PC `'` = BBC `:` (с Shift — `*`), `=` = `^`, Shift+`2` = `"`.
- **Вторая SD-карта (MMFS)**: файл `BEEB.MMB` (например, от RetroClinic) в корне второй карты или `.ssd` на FAT для MMFS2 (OSD *Disc FS*). `*DCAT`, `*DIN n`, `*CAT`.
- **Образы дисков (DFS)**: `.ssd` / `.dsd` в `/bbc` на первой карте, OSD *Drive 0* / *Drive 1*. Model B — Intel 8271 (DFS 1.20) или WD1770 (DFS 2.26), OSD *B FDC*; Master — свой 1770. При *Disc FS* = MMFS+DFS команду `*DISC` перехватывает MMFS: для образов выберите *Disc FS* = DFS. Образы доступны на запись.
- **Кассета**: `.uef` в `/bbc`, OSD *Tape*, затем `*TAPE` и `CHAIN""` (или `*RUN`). Лента идёт, пока включён мотор; *Tape rewind* — с начала. Сжатые UEF (в архивах большинство — gzip) сначала распакуйте: `gunzip -c game.uef > game_raw.uef` (или `zcat`, 7-Zip). Без образа работает вход магнитофона платы.
- **Сопроцессор**: OSD *Co-Pro* = 65C02 (Model B); на Master трубу включает `*CONFIGURE TUBE`.

## Лицензия

Файлы этого порта — GPL-3.0 ([LICENSE](LICENSE)). У импортированных файлов лицензия в их шапках: файлы ядра BeebFpga — **только для некоммерческого использования** (BSD-подобная с пунктом о некоммерческом использовании), файлы BBCMicro.Alternate — GPL-2.0-or-later, MMFS — GPL-3.0.

BBC Micro — торговая марка BBC; ROM Acorn принадлежат их правообладателям. Проект не связан с BBC и Acorn.
