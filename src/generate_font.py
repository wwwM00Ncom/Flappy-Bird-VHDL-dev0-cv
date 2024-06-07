from PIL import Image

glyphs = Image.open("glyphs.png")

with open("char_rom.mif", "w") as file:
    file.writelines([
        "Depth = 1024;\n",
        "Width = 8;\n",
        "Address_radix = hex;\n",
        "Data_radix = bin;\n",
        "Content\n",
        "Begin\n"
        ])
    
    romSize = 0
    for y in range(8):
        for x in range(16):
            char = y * 16 + x
            if char > 0x20:
                file.write(f"-- {chr(char)}\n")
            else:
                file.write("-- ?\n")
            for dY in range(8):
                idx = y * 128 + x * 8 + dY
                data = 0
                for dX in range(8):
                    data = data << 1
                    pixel = glyphs.getpixel((x * 8 + dX, y * 8 + dY))
                    if pixel[3] == 255:
                        data = data | 1
                file.write(f"{hex(idx)[2:]:>03} : {bin(data)[2:]:>08};\n")
    file.write("End;\n")