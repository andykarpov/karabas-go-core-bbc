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

### Ф2 — образы дисков через прошивку

`.ssd` / `.dsd` с SD1 через `kg_l2_img` → i8271 (Model B, DFS 1.20) и fdc1772 (Model B DFS 2.26 / Master). OSD: дисководы 0 / 1, файловая система (MMFS / DFS / оба).

### Ф3 — кассеты и опции

UEF (с gzip) — образ в SDRAM или SRAM вместо DDR3. OSD: CoPro 65C02, Music 5000, SID, речь, VideoNuLA, джойстик, громкость.

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
