import cv2
import numpy as np

img1 = cv2.imread("top.png")
img2 = cv2.imread("bottom.png")

# Find the blue "View challenge" button as a template
# Blue color approx: BGR (255, 217, 102) -> sky blue in OpenCV is (255, 217, 102)? 
# Let's just find the card bounds.
gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)
_, t1 = cv2.threshold(gray1, 240, 255, cv2.THRESH_BINARY)
_, t2 = cv2.threshold(gray2, 240, 255, cv2.THRESH_BINARY)

c1, _ = cv2.findContours(t1, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
c2, _ = cv2.findContours(t2, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

cards1 = [cv2.boundingRect(c) for c in c1 if cv2.boundingRect(c)[2] > 200]
cards2 = [cv2.boundingRect(c) for c in c2 if cv2.boundingRect(c)[2] > 200]

print("Top cards:", cards1)
print("Bottom cards:", cards2)
