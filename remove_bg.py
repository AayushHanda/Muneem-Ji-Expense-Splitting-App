import sys
from PIL import Image

def process_image(input_path, output_path):
    print(f"Processing {input_path}...")
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    # Any pixel close to white will become transparent.
    # The image has anti-aliasing so we use a threshold.
    # A soft alpha might be better for edges, but given standard rules, simple threshold:
    for item in data:
        # Check if R, G, B are all very high (white/almost white).
        # We also want to give partial transparency to things that are grayish white.
        r, g, b, a = item
        if r > 240 and g > 240 and b > 240:
            new_data.append((255, 255, 255, 0))
        elif r > 230 and g > 230 and b > 230:
            # partially transparent for smoother edges
            alpha = int((255 - r) * 10) 
            new_data.append((r, g, b, min(255, max(0, alpha))))
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Saved to {output_path}")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        process_image(sys.argv[1], sys.argv[2])
    else:
        print("Usage: python remove_bg.py <input> <output>")
