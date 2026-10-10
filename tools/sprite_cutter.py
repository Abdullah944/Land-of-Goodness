# Purpose: Automatically split transparent asset sheets into individual PNG game assets.

"""Cut a transparent PNG sheet into one PNG per game object."""

import sys
from pathlib import Path

try:
	from PIL import Image
except ImportError:
	print("Pillow is not installed.")
	print("On macOS, run: python3 -m pip install pillow")
	raise SystemExit(1)


# Empty pixels kept around every saved object.
PADDING = 20

# Pixels fainter than this are treated as empty background.
# Raise it when a soft shadow joins separate objects into one file.
ALPHA_MIN = 24

# Specks smaller than this many pixels are ignored.
MIN_COMPONENT_AREA = 40

# Pieces closer than this many pixels are saved as one object.
# Leave it at 0 to keep every separate drawing on its own.
# Raise it when one object comes out as several files, such as a seed pack and its loose seeds.
# Lower it when two different objects come out as one file.
# This animal sheet sits tighter than 40 pixels, so 40 glues the whole sheet into one picture.
MERGE_DISTANCE = 0


class _Box:
	def __init__(self, min_x, min_y, max_x, max_y):
		self.min_x = min_x
		self.min_y = min_y
		self.max_x = max_x
		self.max_y = max_y
		self.cells = set()
		self.labels = set()

	@property
	def height(self):
		return self.max_y - self.min_y + 1

	def merge(self, other):
		self.min_x = min(self.min_x, other.min_x)
		self.min_y = min(self.min_y, other.min_y)
		self.max_x = max(self.max_x, other.max_x)
		self.max_y = max(self.max_y, other.max_y)
		self.cells.update(other.cells)
		self.labels.update(other.labels)


def _shapes_are_close(box_a, box_b):
	# Compare the artwork itself. Nearby boxes can overlap even when the drawings do not.
	if MERGE_DISTANCE <= 0:
		return False
	cell = 8
	reach = max(1, (MERGE_DISTANCE + cell - 1) // cell)
	reach_sq = reach * reach
	small, large = (box_a, box_b) if len(box_a.cells) <= len(box_b.cells) else (box_b, box_a)
	large_cells = large.cells
	for cx, cy in small.cells:
		for oy in range(-reach, reach + 1):
			for ox in range(-reach, reach + 1):
				if ox * ox + oy * oy > reach_sq:
					continue
				if (cx + ox, cy + oy) in large_cells:
					return True
	return False


def _find_pieces(image):
	width, height = image.size
	pixels = image.load()
	seen = bytearray(width * height)
	labels = [0] * (width * height)
	pieces = []
	next_label = 1
	neighbors = (
		(-1, -1), (0, -1), (1, -1),
		(-1, 0), (1, 0),
		(-1, 1), (0, 1), (1, 1),
	)

	for y in range(height):
		row = y * width
		for x in range(width):
			start = row + x
			if seen[start]:
				continue
			if pixels[x, y][3] <= ALPHA_MIN:
				seen[start] = 1
				continue

			stack = [(x, y)]
			seen[start] = 1
			labels[start] = next_label
			area = 0
			min_x = max_x = x
			min_y = max_y = y
			cells = set()
			while stack:
				cx, cy = stack.pop()
				area += 1
				cells.add((cx // 8, cy // 8))
				labels[cy * width + cx] = next_label
				if cx < min_x:
					min_x = cx
				elif cx > max_x:
					max_x = cx
				if cy < min_y:
					min_y = cy
				elif cy > max_y:
					max_y = cy
				for ox, oy in neighbors:
					nx = cx + ox
					ny = cy + oy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					index = ny * width + nx
					if seen[index]:
						continue
					seen[index] = 1
					if pixels[nx, ny][3] <= ALPHA_MIN:
						continue
					stack.append((nx, ny))

			if area >= MIN_COMPONENT_AREA:
				box = _Box(min_x, min_y, max_x, max_y)
				box.cells = cells
				box.labels.add(next_label)
				pieces.append(box)
			else:
				for clear_y in range(min_y, max_y + 1):
					clear_row = clear_y * width
					for clear_x in range(min_x, max_x + 1):
						clear_index = clear_row + clear_x
						if labels[clear_index] == next_label:
							labels[clear_index] = 0
			next_label += 1
	return pieces, labels


def _merge_nearby(pieces):
	parent = list(range(len(pieces)))

	def find(index):
		while parent[index] != index:
			parent[index] = parent[parent[index]]
			index = parent[index]
		return index

	for i, box_a in enumerate(pieces):
		root_a = find(i)
		for j in range(i + 1, len(pieces)):
			if _shapes_are_close(box_a, pieces[j]):
				root_b = find(j)
				if root_a != root_b:
					parent[root_b] = root_a

	groups = {}
	for index, box in enumerate(pieces):
		root = find(index)
		if root not in groups:
			groups[root] = _Box(box.min_x, box.min_y, box.max_x, box.max_y)
			groups[root].cells = set(box.cells)
			groups[root].labels = set(box.labels)
		else:
			groups[root].merge(box)
	return list(groups.values())


def _reading_order(boxes):
	# Group into rows, then left to right inside each row.
	rows = []
	for box in sorted(boxes, key=lambda item: (item.min_y, item.min_x)):
		center_y = (box.min_y + box.max_y) / 2
		placed = False
		for row in rows:
			if abs(center_y - row["center_y"]) <= max(box.height, row["height"]) * 0.55:
				row["items"].append(box)
				count = len(row["items"])
				row["center_y"] = (row["center_y"] * (count - 1) + center_y) / count
				row["height"] = max(row["height"], box.height)
				placed = True
				break
		if not placed:
			rows.append({"center_y": center_y, "height": box.height, "items": [box]})

	ordered = []
	for row in rows:
		row["items"].sort(key=lambda item: item.min_x)
		ordered.extend(row["items"])
	return ordered


def _save_object(image, labels, box, path):
	width = image.size[0]
	crop = image.crop((box.min_x, box.min_y, box.max_x + 1, box.max_y + 1))
	pixels = crop.load()
	for y in range(crop.height):
		source_row = (box.min_y + y) * width
		for x in range(crop.width):
			owner = labels[source_row + box.min_x + x]
			# Drop pixels that belong to a neighboring object inside this box.
			if owner != 0 and owner not in box.labels:
				pixels[x, y] = (0, 0, 0, 0)
	canvas = Image.new(
		"RGBA",
		(crop.width + PADDING * 2, crop.height + PADDING * 2),
		(0, 0, 0, 0),
	)
	canvas.paste(crop, (PADDING, PADDING))
	canvas.save(path, "PNG")


def main():
	if len(sys.argv) not in (2, 3):
		print("Usage: python3 tools/sprite_cutter.py path/to/sheet.png [output_folder]")
		raise SystemExit(1)

	source = Path(sys.argv[1])
	if not source.is_file():
		print(f"Cannot find the image: {source}")
		raise SystemExit(1)
	if source.suffix.lower() != ".png":
		print("The source image must be a PNG.")
		raise SystemExit(1)

	if len(sys.argv) == 3:
		output = Path(sys.argv[2])
	else:
		output = source.with_name(source.stem + "_cut")
	if output.resolve() == source.resolve():
		print("Refusing to overwrite the original sheet.")
		raise SystemExit(1)

	image = Image.open(source)
	image.load()
	if image.mode != "RGBA":
		image = image.convert("RGBA")
	alphas = list(image.getchannel("A").get_flattened_data())
	if not any(alpha <= ALPHA_MIN for alpha in alphas):
		print("This PNG has no transparency, so the objects cannot be separated.")
		raise SystemExit(1)

	pieces, labels = _find_pieces(image)
	objects = _reading_order(_merge_nearby(pieces))
	if not objects:
		print("No objects were found.")
		raise SystemExit(1)

	output.mkdir(parents=True, exist_ok=True)
	for number, box in enumerate(objects, start=1):
		_save_object(image, labels, box, output / f"item_{number:02d}.png")

	print(f"Found {len(objects)} objects.")
	print(f"Saved to: {output}")


if __name__ == "__main__":
	main()
