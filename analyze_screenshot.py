import cv2
import sys

img = cv2.imread(sys.argv[1])
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
_, thresh = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY)
contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

cards = []
for cnt in contours:
    x, y, w, h = cv2.boundingRect(cnt)
    if w > 200 and h > 100:
        cards.append((x, y, w, h))

cards = sorted(cards, key=lambda c: c[1])
for i, c in enumerate(cards):
    print(f"Card {i+1}: y={c[1]}, width={c[2]}, height={c[3]}")
