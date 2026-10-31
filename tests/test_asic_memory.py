"""Static checks for the generated ASIC program-memory artifacts."""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sw"))
import assembler


class AsicMemoryTests(unittest.TestCase):
    def setUp(self):
        self.words = assembler.ensamblar((ROOT / "sw" / "game.s").read_text())
        self.rom = (ROOT / "rtl" / "game_rom.v").read_text()

    def test_game_size_and_generated_rom_contents(self):
        self.assertEqual(len(self.words), 143)
        self.assertEqual(self.rom, assembler.generar_rom_verilog(self.words))
        self.assertIn("30'd142", self.rom)

    def test_game_uses_one_non_mmio_data_word(self):
        source = (ROOT / "sw" / "game.s").read_text()
        offsets = re.findall(r"(?:lw|sw)\s+x\d+,\s*(-?\d+)\(x0\)", source)
        self.assertEqual(set(offsets), {"2044"})

    def test_asic_memory_sources_have_no_fpga_memory_constructs(self):
        text = "\n".join((ROOT / "rtl" / name).read_text() for name in
                         ["game_rom.v", "pochoco_memory_rom_ram.v", "pochoco_memory_unified_ff.v"])
        self.assertNotIn("SB_RAM40_4K", text)
        self.assertNotIn("$readmemh", text)
        self.assertNotIn("initial", text)

    def test_100ns_program_matches_generated_hardware_and_fpga_differences(self):
        words = assembler.ensamblar((ROOT / "sw" / "game_asic_100ns.s").read_text())
        image = (ROOT / "asic" / "generated" / "game_100ns.hex").read_text()
        rom = (ROOT / "asic" / "generated" / "game_rom.v").read_text()
        self.assertEqual(len(words), 143)
        self.assertEqual(image, "".join(f"{word:08x}\n" for word in words))
        self.assertEqual(rom, assembler.generar_rom_verilog(words))
        self.assertEqual([i for i, (fpga, asic) in enumerate(zip(self.words, words))
                          if fpga != asic], [2, 3, 4, 5])


if __name__ == "__main__":
    unittest.main()
