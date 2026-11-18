-- bbc_kg_core.vhd
--
-- karabas: bbc_micro_core of BeebFpga with the configuration of the Karabas boards (the boolean
-- generics stay in VHDL; the Verilog tops instantiate this entity without generics) and only the
-- ports they use.
--
-- Configuration: Model B (T65) and Master 128 (AlanD) in one bitstream (KgDualCpu, picked by
-- m128_mode), keyboard bytes from the MCU (KgExtKeyboard), MMFS on the SD card (SPI), the 1770 and
-- 8271 disc controllers on images (KgFdc, the MiSTer sector interface sd_*), SID,
-- Music 5000 with its filter, the internal 65C02 co-processor, VideoNuLA, the VGA scan doubler
-- (clock_27). Not used: speech (TMS5220: too large next to the rest, user decision 2026-11-18),
-- the 48 kHz resampler (the tops take audio_l / audio_r), HDMI of the core (the boards have their
-- own), sRGB, the ICE debugger, the AMX mouse (later), the external tube. The serial port is in for
-- the cassette (ACIA + Serial ULA), its RS423 side is not wired.

library ieee;
use ieee.std_logic_1164.all;

entity bbc_kg_core is
    port (
        clock_27        : in  std_logic;
        clock_48        : in  std_logic;
        hard_reset_n    : in  std_logic;
        powerup_reset_n : in  std_logic;

        m128_mode       : in  std_logic;
        copro_mode      : in  std_logic;

        kbd_data        : in  std_logic_vector(7 downto 0);
        kbd_valid       : in  std_logic;
        caps_led        : out std_logic;
        shift_led       : out std_logic;
        motor_led       : out std_logic;

        joystick1       : in  std_logic_vector(4 downto 0);
        joystick2       : in  std_logic_vector(4 downto 0);

        vga_red         : out std_logic_vector(3 downto 0);
        vga_green       : out std_logic_vector(3 downto 0);
        vga_blue        : out std_logic_vector(3 downto 0);
        vga_hsync       : out std_logic;
        vga_vsync       : out std_logic;

        audio_l         : out std_logic_vector(15 downto 0);
        audio_r         : out std_logic_vector(15 downto 0);

        ext_nOE         : out std_logic;
        ext_nWE         : out std_logic;
        ext_nCS         : out std_logic;
        ext_A           : out std_logic_vector(18 downto 0);
        ext_Dout        : in  std_logic_vector(7 downto 0);
        ext_Din         : out std_logic_vector(7 downto 0);

        SDMISO          : in  std_logic;
        SDSS            : out std_logic;
        SDCLK           : out std_logic;
        SDMOSI          : out std_logic;

        cas_in          : in  std_logic;
        cas_out         : out std_logic;

        cpu_addr        : out std_logic_vector(15 downto 0);

        fdc_8271        : in  std_logic;
        img_mounted     : in  std_logic_vector(1 downto 0);
        img_wp          : in  std_logic_vector(1 downto 0);
        img_size        : in  std_logic_vector(31 downto 0);
        sd_lba          : out std_logic_vector(31 downto 0);
        sd_rd           : out std_logic_vector(1 downto 0);
        sd_wr           : out std_logic_vector(1 downto 0);
        sd_ack          : in  std_logic;
        sd_buff_addr    : in  std_logic_vector(8 downto 0);
        sd_dout         : in  std_logic_vector(7 downto 0);
        sd_din          : out std_logic_vector(7 downto 0);
        sd_dout_strobe  : in  std_logic;
        floppy_led      : out std_logic
    );
end entity;

architecture rtl of bbc_kg_core is

    signal cas_out_i    : std_logic_vector(1 downto 0);

begin

    cas_out <= cas_out_i(0);

    core : entity work.bbc_micro_core
        generic map (
            IncludeAMXMouse        => false,
            IncludeSPISD           => true,
            IncludeSID             => true,
            IncludeMusic5000       => true,
            IncludeMusic5000Filter => true,
            IncludeMusic5000SPDIF  => false,
            IncludeMixerResampler  => false,
            IncludePSGSPDIF        => false,
            IncludeSpeech          => false,
            IncludeICEDebugger     => false,
            IncludeCoPro6502       => true,
            IncludeCoProSPI        => false,
            IncludeCoProExt        => false,
            IncludeVideoNuLA       => true,
            IncludeMode7NuLA       => true,
            IncludeSRGB            => false,
            IncludeVGA             => true,
            IncludeHDMI            => false,
            IncludeTrace           => false,
            IncludeSerial          => true,   -- karabas: ACIA + Serial ULA, the cassette (cas_in from bbc_tape)
            UseOrigKeyboard        => false,
            UseT65Core             => false,
            UseAlanDCore           => false,
            KgDualCpu              => true,
            KgExtKeyboard          => true,
            KgFdc                  => true,
            OverrideCMOS           => false
        )
        port map (
            clock_27        => clock_27,
            clock_48        => clock_48,
            clock_avr       => clock_48,
            hard_reset_n    => hard_reset_n,
            powerup_reset_n => powerup_reset_n,

            ps2_kbd_clk     => open,  -- not used (KgExtKeyboard, no mouse)
            ps2_kbd_clk_o   => open,
            ps2_kbd_data    => open,  -- not used (KgExtKeyboard, no mouse)
            ps2_kbd_data_o  => open,
            ps2_mse_clk     => open,  -- not used (KgExtKeyboard, no mouse)
            ps2_mse_clk_o   => open,
            ps2_mse_data    => open,  -- not used (KgExtKeyboard, no mouse)
            ps2_mse_data_o  => open,
            ps2_swap        => '0',
            dbg_keyboard_state => open,

            rgb_red         => open,
            rgb_green       => open,
            rgb_blue        => open,
            rgb_csync       => open,
            vga_red         => vga_red,
            vga_green       => vga_green,
            vga_blue        => vga_blue,
            vga_vsync       => vga_vsync,
            vga_hsync       => vga_hsync,
            video_disen     => open,
            video_clken     => open,
            video_mhz12     => open,

            audio_src       => '0',
            audio_l         => audio_l,
            audio_r         => audio_r,
            hd_audio_l      => open,
            hd_audio_r      => open,
            clip_led        => open,
            psg_audio       => open,
            psg_strobe      => open,
            psg_spdif       => open,
            m5k_filter_en   => '1',
            m5k_audio_l     => open,
            m5k_audio_r     => open,
            m5k_strobe      => open,
            m5k_spdif       => open,
            sid_audio       => open,
            sid_strobe      => open,

            ext_A_stb       => open,
            ext_nOE         => ext_nOE,
            ext_nWE         => ext_nWE,
            ext_nWE_long    => open,
            ext_nCS         => ext_nCS,
            ext_A           => ext_A,
            ext_Dout        => ext_Dout,
            ext_Din         => ext_Din,

            SDMISO          => SDMISO,
            SDSS            => SDSS,
            SDCLK           => SDCLK,
            SDMOSI          => SDMOSI,

            caps_led        => caps_led,
            shift_led       => shift_led,
            motor_led       => motor_led,

            keyb_dip        => "00000000",

            ext_keyb_led1   => open,
            ext_keyb_led2   => open,
            ext_keyb_led3   => open,
            ext_keyb_1mhz   => open,
            ext_keyb_en_n   => open,
            ext_keyb_pa     => open,
            ext_keyb_rst_n  => '1',
            ext_keyb_ca2    => '0',
            ext_keyb_pa7    => '0',

            rtc_mgmt_dout   => open,

            config_key      => '0',
            config          => open,

            joystick1       => joystick1,
            joystick2       => joystick2,

            avr_reset       => '1',
            avr_RxD         => '1',
            avr_TxD         => open,

            serial_TxD      => open,
            serial_RTS      => open,

            cas_in          => cas_in,
            cas_out         => cas_out_i,

            cpu_addr        => cpu_addr,

            m128_mode       => m128_mode,
            ext_kbd_data    => kbd_data,
            ext_kbd_valid   => kbd_valid,

            fdc_8271        => fdc_8271,
            img_mounted     => img_mounted,
            img_wp          => img_wp,
            img_size        => img_size,
            sd_lba          => sd_lba,
            sd_rd           => sd_rd,
            sd_wr           => sd_wr,
            sd_ack          => sd_ack,
            sd_buff_addr    => sd_buff_addr,
            sd_dout         => sd_dout,
            sd_din          => sd_din,
            sd_dout_strobe  => sd_dout_strobe,
            floppy_led      => floppy_led,

            copro_mode      => copro_mode,
            copro_ext       => '0',

            p_spi_ssel      => '0',
            p_spi_sck       => '0',
            p_spi_mosi      => '0',
            p_spi_miso      => open,
            p_irq_b         => open,
            p_nmi_b         => open,
            p_rst_b         => open,

            ext_tube_r_nw   => open,
            ext_tube_nrst   => open,
            ext_tube_ntube  => open,
            ext_tube_phi2   => open,
            ext_tube_a      => open,
            ext_tube_di     => open,

            ext_1mhz_clken  => open,
            ext_1mhz_nrst   => open,
            ext_1mhz_pgfc_n => open,
            ext_1mhz_pgfd_n => open,
            ext_1mhz_r_nw   => open,
            ext_1mhz_addr   => open,
            ext_1mhz_di     => open,

            trace_data      => open,
            trace_r_nw      => open,
            trace_sync      => open,
            trace_rstn      => open,
            trace_rdy       => open,
            trace_phi2      => open,

            tmds_r          => open,
            tmds_g          => open,
            tmds_b          => open,

            test            => open
        );

end architecture;
