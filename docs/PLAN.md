# План ядра BBC Micro для Karabas Go / Mini / Mini G

Цель: Acorn BBC Micro Model B и BBC Master 128 на платах Karabas (XC6SLX25, ISE 14.7). Основа — [hoglet67/BeebFpga](https://github.com/hoglet67/BeebFpga), ветка `dev` (9b73fea, 2026-11-11). Донор — [Welsh71/BBCMicro.Alternate_MiSTer](https://github.com/Welsh71/BBCMicro.Alternate_MiSTer) (01da28c, v20261105): контроллеры дисковода 8271 и 1770, кассеты UEF, два процессора в одной прошивке.

## Что изучено (2026-11-18)

| Репо | Что даёт |
|---|---|
| **hoglet67/BeebFpga `dev`** (база) | Ядро `bbc_micro_core.vhd` без привязки к плате: Model B (T65, 6502) / Master 128 (AlanD R65C02), CoPro 65C02 через Tube, Music 5000, SID, речь TMS5220 (Model B), VideoNuLA, RTC / CMOS, мышь AMX, джойстики, ACIA / Serial ULA, удвоитель строк VGA, HDMI, микшер с ресемплером 48 кГц. Диски — только MMFS через SPI SD. Проекты ISE под xc6slx9 (Papilio Duo) и xc6slx16 (Spectrum Next, почти все опции). Master здесь ветка 2024 года, вся работа в `dev` |
| Welsh71/BBCMicro.Alternate_MiSTer (донор) | Ядро BeebFpga ~2022 + видеоправки hoglet 2022 года. Своё (GPL-2+): `i8271.v` (поведенческая модель под DFS 1.20), `fdc1772.v` MiST (DFS 2.26 / Master), образы `.ssd` / `.dsd` через `sd_lba` / `sd_buff` MiSTer; кассеты UEF (`tape_player`, `inflate` для gzip, `acia6850`, `serial_ula`, образ в DDR3); звуки дисковода; оба процессора одновременно, выбор по `m128_mode` |
| MiSTer-devel/BBCMicro_MiSTer | Старый порт BeebFpga, только для сверки |

Без основы: mikestir/fpga-bbc (предок 2011 года), sharpie7/BeebFpga_MiSTer (продолжен Welsh71), YazanMehyar, atthecodeface (CDL), DopierRex/OneNext. Порта MiST нет. Потом: сопроцессоры hoglet67/CoPro6502 (Z80, 6809, 68000, x86, ARM2, PDP-11, 32016).

## Решения пользователя (2026-11-18)

- Основа BeebFpga `dev`, из Welsh71 — переключение двух CPU, i8271 + fdc1772, UEF.
- Диски обоими способами: MMFS сам работает с SD2 (BEEB.MMB или MMFS2 на FAT, с записью) + образы `.ssd` / `.dsd` с SD1 через прошивку (8271 / 1770).
- Model B и Master 128 в одном ядре, модель в OSD, у каждой свой процессор (6502 / 65C02).
- ROM (OS 1.2, BASIC 2, MOS 3.20, DFS, ADFS, MMFS, …) — в `.kg`.
- Имя ядра `bbc`, репозиторий karabas-go-core-bbc, публичный.

## Лицензии

Файлы ядра BeebFpga (Mike Stirling, David Banks) — BSD-подобная с пунктом «только некоммерческое использование» (у пользователя разрешено). AtomBusMon (T65, AlanD) — GPL-3. Файлы Welsh71 — GPL-2+. MMFS — GPL-3. Наши файлы — GPL-3. Welsh71 выпускает всё под GPL-2, хотя внутри лежат файлы BeebFpga с пунктом NC: у нас лицензии остаются в шапках файлов, README это объясняет.

## Плата

XC6SLX25: 15 032 LUT6, 30 064 FF, 52 RAMB16. SRAM 4 МБ, SDRAM 32 МБ. SD2 (`SD_CS_N` L4, `SD_DI` L7, `SD_DO` M7, `SD_CLK` L8, `SD_DET_N` M6) выведена на FPGA на всех трёх платах — MMFS работает с ней через SPI ядра (`IncludeSPISD`). На Mini G SD2 общая с Next / Profi / TS-Conf.

Ядро: внешняя шина 8 бит, 512 КБ (`ext_A` 19 бит) → SRAM. Такты 48 МГц (ядро) и 27 МГц (удвоитель строк, 720×576p50); у Spec Next оба из PLL от 50 МГц, у нас вход тоже 50 МГц.

## Фазы

### Ф0 — импорт и замер (ветка f0-measure)

- [x] Импорт BeebFpga `dev` 9b73fea: `src/common` → `src/rtl/beeb`, процессоры AtomBusMon → `src/rtl/beeb/cpu`, ROM (без `.bit`) → `src/roms`, топы Spec Next и Tang 20K → `upstream/beebfpga`.
- [x] Импорт Welsh71 01da28c: `i8271`, `fdc1772`, `tape`, звуки дисковода → `src/rtl/alt`; их `bbc_micro_core.vhd` и верх MiSTer → `upstream/alternate`.
- [x] XST `bbc_micro_core` на xc6slx25: Master (AlanD) и Model B (T65), все опции, кроме HDMI и ICE (`make measure-master`, `make measure-beeb`). Цифры ниже.

### Ф1 — Mini G, первый запуск

Верх платы на kg_* из karabas-go-modules: `kg_mcu2` (OSD, клавиатура, загрузка ROM из `.kg` в SRAM), SRAM на внешней шине ядра, PLL 48 + 27 МГц, видео 720×576p50 (удвоитель строк ядра) на HDMI / VGA, звук. Оба процессора с выбором по `m128_mode` (как у Welsh71). Клавиатура: USB HID → матрица BBC (`keyboard.vhd` ядра принимает PS/2, решаем в Ф1). MMFS на SD2. OSD: Model, Reset / Break, автозагрузка (Shift+Break). Цель: приглашение BASIC на обеих моделях, `*DCAT` / `*DIN` и запуск игры из BEEB.MMB.

Сделано (ветка f1-minig, сборка 26111820):
- Ядро (`karabas:`): `KgDualCpu` — T65 и AlanD одновременно, выбор по `m128_mode`, невыбранный в сбросе; `KgExtKeyboard` — байты PS/2 set 2 от `kg_mcu2` прямо в `keyboard.vhd` (generic `NoHandshake`: без команд сброса / ID / LED устройству). Раскладка позиционная, как в BeebFpga: PC `'` = BBC `:` (Shift = `*`), `=` = `^`, F12 = BREAK.
- `rtl/karabas/bbc_kg_core.vhd` — конфигурация для плат (булевы generic остаются в VHDL). `bbc_clocks.v`: 48 МГц = DCM_CLKGEN 50·24/25 → PLL; 27 / 135 / 8 МГц от второго PLL (VCO 675). `bbc_mem.v`: банки SRAM по 512 КБ `{ MMFS2, модель }`, загрузка ROM из `.kg` (LOAD kind 0, ядро в сбросе). `bbc_video_out.v`: 720×576p50 со своими синхросигналами (`sim/run_video_out.sh`: 624 / 625 строк, окно 720×576 с синхрой ядра и без неё). Звук `audio_l/r` ядра → PCM5102 и HDMI 48 кГц.
- ROM: `tools/bbc_roms.sh` → `roms/kg/{beeb,master}_{mmfs,mmfs2}.rom` (раскладка Tang Nano).
- OSD: Model (Model B / Master 128), SD2 FS (MMFS / MMFS2), Co-Pro (Off / 65C02), Reset (Menu+F12). Смена модели / ФС / Co-Pro = сброс по питанию.

| Сборка | LUT | Slices | RAMB16 | DSP48 | Время |
|---|---|---|---|---|---|
| 26111820 Mini G | 7 882 (52 %) | 2 913 (77 %) | 13 (+4 RAMB8) | 5 | всё сходится |

На плате 2026-11-18 (Mini G): Model B — «BBC Computer 32K / RAM Master / Model B MMFS SWRAM / BASIC», клавиатура, MODE 2; Master 128 — «Acorn MOS / Master MMFS / BASIC», `*HELP` (MMFS 1.61, DFS 2.24); звук HDMI (`VDU 7`); Model B + Co-Pro 65C02 — «Acorn TUBE 65C102 Co-Processor»; OSD. Сбросов USB за время работы ядра нет. На Master трубу включает CMOS (`*CONFIGURE TUBE`), пункт Co-Pro там не действует (`OverrideCMOS` false).

MMFS на SD2 (2026-11-18, BEEB.MMB RetroClinic, 100 МБ, Model B): `*DCAT` (каталог больше 200 дисков), `*DIN 0` + `*CAT` (диск MENU), `*EXEC !BOOT` — меню RetroClinic (65 страниц, цветной Mode 7), игра «2002» (Superior) загрузилась и идёт в графическом режиме. Shift+Break через `kg_board.py key shift+f12` дал только Break без автозагрузки (вероятно, Shift отпускается вместе с F12): проверить с настоящей клавиатуры.

Осталось в Ф1: одобрение OSD пользователем.

### Ф2 — образы дисков через прошивку

`.ssd` / `.dsd` с SD1 через `kg_l2_img` → i8271 (Model B, DFS 1.20) и fdc1772 (Model B DFS 2.26 / Master). OSD: дисководы 0 / 1, файловая система (MMFS / DFS / оба).

Сделано (ветка f2-discs, сборка 26111822):
- Ядро (`karabas:`, generic `KgFdc`): fdc1772 + i8271 Welsh71 — Master FE24 (управление) / FE28 (1770); Model B FE80-FE9F 8271 или FE80 / FE84 (Acorn 1770); защёлка управления дисководом; NMI от 8271 или INTRQ / DRQ 1770; общий буфер сектора и порт `sd_*`.
- fdc1772: без `$clog2`, начальное значение `sd_state` (XST, как в core-atarist); fdc1772 / floppy / i8271 через sv2v (`tools/sv2v.sh` → `rtl/sv2v`: XST не принимает объявления в безымянных блоках). Отдельный XST (`measure/alt_*`): 1 400 + 809 LUT, тракт `sd_rd` / `sd_wr` на месте.
- `bbc_sd_sdc.v` (`cpc_sd_sdc` из core-cpc): слоты 0 / 1 файлового монтировщика `kg_mcu2` → интерфейс секторов MiSTer; `IMG_OUT_LATENCY` 3; защита записи по дисководу.
- `bbc_mem`: банк на модель, ROM файловых систем по одной копии в `fs.rom` (0x100000), подставляются в слоты по OSD: Model B слот 3 DFS (DNFS 1.20 для 8271 / DFS 2.26 для 1770), слот 8 SWMMFS / SWMMFS2; Master слот 9 MAMMFS / MAMMFS2, а при одном DFS — DFS 2.24 (CMOS по умолчанию грузит ФС из слота 9, иначе Master уходил в ADFS: «No ADFS partitions»), слот 8 DFS при MMFS+DFS.
- OSD (одобрено 2026-11-18): Drive 0 / Drive 1 (`.ssd`, `.dsd`, `/bbc`, Menu+F1 / F2), Model, Disc FS (MMFS / MMFS2 / DFS / MMFS+DFS / MMFS2+DFS, по умолчанию MMFS+DFS), B FDC (8271 / 1770), Co-Pro, Reset.
- `tools/mmb.py`: список и извлечение дисков BEEB.MMB, пустой DFS `.ssd`.

| Сборка | LUT | Slices | RAMB16 | DSP48 | Время |
|---|---|---|---|---|---|
| 26111822 Mini G | 9 525 (63 %) | 3 251 (86 %) | 13 (+6 RAMB8) | 10 | всё сходится |

На плате 2026-11-18 (Mini G, образы из BEEB.MMB): Model B + 8271 — `*CAT` games1.ssd, `CHAIN"MENU"`, Chuckie Egg идёт; `SAVE` на blank.ssd в Drive 1. Model B + 1770 (DFS 2.26) — читает файл, записанный через 8271 (запись дошла до образа на SD), `CHAIN` печатает KARABAS. Master 128 + 1770 — `SAVE` / `CHAIN` на Drive 1; с Disc FS = DFS грузится в BASIC + DFS (26111822). При MMFS+DFS `*DISC` перехватывает MMFS (у него слот выше): для DFS выбрать Disc FS = DFS.

### Ф3 — кассеты и опции

UEF (с gzip) — образ в SDRAM или SRAM вместо DDR3. OSD: CoPro 65C02, Music 5000, SID, речь, VideoNuLA, джойстик, громкость.

Сделано (ветка f3-tape, сборка 26111823):
- Образ ленты — в SDRAM 32 МБ (на плате она свободна; SRAM ядро занимает каждым слотом CPU / видео / Tube). `bbc_tape_sdram.v`: один байтовый порт, сделан из `bk_sdram.v` core-bk (инвертированный клок чипа через ODDR2, захват по спаду, CL2, автопрекардж, регенерация каждые 360 тактов), выводы SDRAM `SLEW SLOW`, как в core-bk.
- `bbc_tape.v`: FL Tape (слот 2) → FIFO 16 → SDRAM; `tape_player` Welsh71 (через sv2v, чанки UEF 0100 / 0102 / 0104 / 0110 / 0111 / 0112 / 0116 / 0117) → `cas_in` Serial ULA ядра (`IncludeSerial`, своя у BeebFpga dev) при включённом моторе; без образа — вход `TAPE_IN` платы. `TAPE_OUT` = кассетный выход ядра.
- `sim/run_tape.sh` (1 с): маленький UEF через `LD_*` в поведенческую SDRAM (`sim/sdram_model.v`), чтение обратно, воспроизведение, 140 фронтов — PASS.
- `tools/uef.py`: несжатый UEF из файлов DFS `.ssd` (кассетные блоки BBC, CRC-16).
- OSD: Tape (`.uef`, Menu+F3), Tape rewind.

| Сборка | LUT | Slices | RAMB16 | DSP48 | Время |
|---|---|---|---|---|---|
| 26111823 Mini G | 10 621 (70 %) | 3 459 (92 %) | 13 (+7 RAMB8) | 12 | всё сходится |

На плате 2026-11-18: snake.uef (SNAKE + BANDIT из games1.ssd, `tools/uef.py`) → `*TAPE`, `CHAIN""`: Searching / Loading / блоки, Snake запустился. Сбросов USB нет (SDRAM в работе).

Не сделано: gzip-образы (`.uef` часто сжаты; `inflate.v` Welsh71 — только логика, без BRAM; при 92 % slices сначала замер), звук ленты в динамике, опции OSD для Music 5000 / SID / NuLA / джойстика.

### Ф4 — Go и Mini, выпуск

Топы Go / Mini, сборка всех плат, `cores.json` karabas-go.

## Беклог

- Сопроцессоры CoPro6502 (Z80, 6809, 68000, ARM2 и др.) через внутренний Tube.
- Звуки дисковода (sounds.rom BeebEm у Welsh71).
- RTC Master от RTC прошивки (порт `rtc_mgmt_*` ядра).
- Речь TMS5220 (2,2k LUT, 20 DSP): не помещается вместе с остальным (решение 2026-11-18).

## Ф0: замеры XST

XST 14.7, xc6slx25-2, верх `bbc_micro_core`, `-iobuf NO`, около 1,5 мин на сборку. Опции: SPI SD, SID, Music 5000 + фильтр, микшер / ресемплер 48 кГц, речь TMS5220, CoPro 65C02, VideoNuLA, удвоитель строк VGA, ACIA / Serial ULA, мышь AMX. Без HDMI (у нас свой) и без отладчика ICE.

| Сборка | LUT | FF | RAMB16 | DSP48 | XST, МГц |
|---|---|---|---|---|---|
| Master 128 (AlanD 65C02), `make measure-master` | 9 551 (63 %) | 5 479 | 16 | 26 | 52,4 |
| Model B (T65 6502), `make measure-beeb` | 9 559 (63 %) | 5 535 | 15 | 26 | 52,8 |

Ядру нужно 48 МГц: запас небольшой. Худший путь — внутри R65C02 CoPro (`nextOpcInfo` → `Z`); процессоры работают по clock enable, это проверяем в Ф1 после PAR.

Разбивка Master (`make measure-hier`: `-keep_hierarchy Yes` + netgen + `tools/lut_breakdown.py`, LUT своих ячеек модуля, всего 9 365):

| Модуль | LUT | DSP48 | RAMB16 |
|---|---|---|---|
| TMS5220 (речь) | 2 224 | 20 | 0 |
| R65C02 ×2 (основной + CoPro) | 1 146 | 0 | 4 |
| SID | 1 079 | 4 | 2 |
| sample_rate_converter (ресемплер 48 кГц) | 789 | 1 | 0 |
| bbc_micro_core (связка) | 478 | 0 | 0 |
| vidproc (Video ULA + NuLA) | 474 | 0 | 0 |
| M6522 ×2 | 446 | 0 | 0 |
| sn76489 | 363 | 0 | 0 |
| Music 5000: фильтр / сам | 355 / 115 | 1 / 0 | 0 / 3 |
| div_12u_8u (делитель) | 284 | 0 | 0 |
| keyboard + ps2interface | 273 + 213 | 0 | 0 |
| mc6845 / tube / saa5050 | 205 / 193 / 178 | 0 | 0 |
| остальное (ACIA, Serial ULA, мышь, SPI, ADC, RTC, удвоитель) | ~550 | 0 | 6 |

Предупреждения XST об обрезанных регистрах (Xst:1710 / 1293, 14 шт.) — постоянные младшие биты ресемплера, SID, TMS5220 и `keys_10_0` клавиатуры, тракт не теряется.

Оценка Mini G: ядро 9,55k + второй процессор (T65 рядом с AlanD, ~0,6–0,8k) + обвязка платы (~3,2k, как у CPC) + i8271 / fdc1772 (~1k) + кассеты UEF с inflate (~1k) ≈ 15,4k LUT — больше 15 032. Поэтому:
- речь TMS5220 (2,2k LUT и 20 из 38 DSP) — отдельная сборка или выключить: она только для Model B, на Tang 20K hoglet её на Master не включает;
- без речи ≈ 13,2k (88 %): помещается со всеми остальными опциями;
- запас ещё: ресемплер 48 кГц (0,8k) не нужен, если звук HDMI / I2S у нас берёт отсчёты на своей частоте; SID (1,1k) можно сделать опцией сборки.

**Решение пользователя (2026-11-18): без речи** — `IncludeSpeech` = false во всех сборках; TMS5220 остаётся в дереве (беклог).
