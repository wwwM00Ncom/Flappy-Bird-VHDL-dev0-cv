from PIL import Image
import os
import glob

images = glob.glob("./*.png")
generated = []

ADDRESS_WIDTH = 15

if os.path.exists("sprites_pkg.vhdl"):
    os.remove("sprites_pkg.vhdl")

with open("sprites.mif", "w") as file:
    file.writelines([
        f"Depth = {2 ** ADDRESS_WIDTH};\n",
        "Width = 12;\n",
        "Address_radix = hex;\n",
        "Data_radix = bin;\n",
        "Content\n",
        "Begin\n"
        ])
    
    romSize = 0
    for path in images:
        im = Image.open(path)
        pixels = im.getdata()

        width, height = im.size
        
        for i, pixel in enumerate(pixels):
            if len(pixel) == 3 or pixel[3] == 255:
                red = pixel[0] >> 4
                green = pixel[1] >> 4
                blue = pixel[2] >> 4
                data = (red << 8) | (green << 4) | blue
                file.write(f"{hex(i + romSize)[2:]:>04} : {bin(data)[2:]:>012};\n")
            else:
                file.write(f"{hex(i + romSize)[2:]:>04} : 000000000000;\n")

        generated.append((os.path.basename(path)[:-4], romSize, width, height))

        romSize += width * height   
    
    file.write("End;\n")
    
    print(f"{romSize} pixels.")

if romSize > 2 ** ADDRESS_WIDTH:
    print(f"WARNING: Too many pixels for address width! Please increase it to {romSize.bit_length()}.")
    print("MIF file not created.")
    os.remove("sprites.mif")
    quit()

with open("sprites_pkg.vhdl", "w") as file:
    file.write("--Auto-generated constants file.\npackage sprites_pkg is")
    for sprite in generated:
        varBaseName = "SPRITE_" + sprite[0].upper()
        file.writelines([
            f"\n\tconstant {varBaseName}_OFFSET : integer := {sprite[1]};\n",
            f"\tconstant {varBaseName}_WIDTH : integer := {sprite[2]};\n",
            f"\tconstant {varBaseName}_HEIGHT : integer := {sprite[3]};\n"
        ])
    file.writelines([
        f"\n\tconstant PIXEL_ALLOCATION : integer := {2 ** ADDRESS_WIDTH};\n",
        f"\tconstant ADDRESS_WIDTH : integer := {ADDRESS_WIDTH};\n"
    ])
    file.write("end package;\n")