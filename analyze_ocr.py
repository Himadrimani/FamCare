import pytesseract
from PIL import Image
import sys

img = Image.open(sys.argv[1])
data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)

for i in range(len(data['text'])):
    text = data['text'][i].strip()
    if text == "0%":
        print(f"Found '0%' at y={data['top'][i]}, width={data['width'][i]}, height={data['height'][i]}")
