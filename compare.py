import cv2
import numpy as np
import sys

img = cv2.imread(sys.argv[1])
# Crop top half and bottom half approximately
h, w, _ = img.shape
top_half = img[100:h//2, :]
bottom_half = img[h//2:h-100, :]
cv2.imwrite("top.png", top_half)
cv2.imwrite("bottom.png", bottom_half)
