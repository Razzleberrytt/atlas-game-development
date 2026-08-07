from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
ICON_SOURCE = ROOT / "living-kingdoms-icon-source.png"
THUMBNAIL_SOURCE = ROOT / "living-kingdoms-thumbnail-source.png"
ICON_OUTPUT = ROOT / "living-kingdoms-icon-512.png"
THUMBNAIL_OUTPUT = ROOT / "living-kingdoms-thumbnail-1920x1080.png"
ICON_PREVIEW = ROOT / "living-kingdoms-icon-preview-150.png"
THUMBNAIL_PREVIEW = ROOT / "living-kingdoms-thumbnail-preview-480x270.png"

TITLE_FONT = Path(r"C:\Windows\Fonts\impact.ttf")


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source_ratio = image.width / image.height
    target_ratio = size[0] / size[1]
    if source_ratio > target_ratio:
        crop_width = round(image.height * target_ratio)
        left = (image.width - crop_width) // 2
        image = image.crop((left, 0, left + crop_width, image.height))
    elif source_ratio < target_ratio:
        crop_height = round(image.width / target_ratio)
        top = (image.height - crop_height) // 2
        image = image.crop((0, top, image.width, top + crop_height))
    return image.resize(size, Image.Resampling.LANCZOS)


def draw_title(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shade = Image.new("RGBA", image.size, (0, 0, 0, 0))

    shade_draw = ImageDraw.Draw(shade)
    shade_draw.rectangle((0, 0, 910, 390), fill=(1, 12, 18, 130))
    shade = shade.filter(ImageFilter.GaussianBlur(70))
    overlay.alpha_composite(shade)

    draw = ImageDraw.Draw(overlay)
    living_font = ImageFont.truetype(str(TITLE_FONT), 104)
    kingdoms_font = ImageFont.truetype(str(TITLE_FONT), 148)
    kicker_font = ImageFont.truetype(str(TITLE_FONT), 34)

    x = 92
    draw.text(
        (x, 66),
        "LIVING",
        font=living_font,
        fill=(222, 235, 235, 255),
        stroke_width=5,
        stroke_fill=(2, 13, 18, 235),
    )
    draw.text(
        (x, 146),
        "KINGDOMS",
        font=kingdoms_font,
        fill=(230, 156, 54, 255),
        stroke_width=7,
        stroke_fill=(2, 13, 18, 245),
    )
    draw.rectangle((x + 4, 304, x + 575, 311), fill=(230, 156, 54, 235))
    draw.text(
        (x + 5, 324),
        "CO-OP HORDE SURVIVAL",
        font=kicker_font,
        fill=(216, 229, 230, 245),
        stroke_width=2,
        stroke_fill=(2, 13, 18, 230),
    )

    return Image.alpha_composite(image, overlay).convert("RGB")


def main() -> None:
    icon = Image.open(ICON_SOURCE).convert("RGB")
    icon = cover(icon, (512, 512))
    icon = ImageEnhance.Contrast(icon).enhance(1.04)
    icon.save(ICON_OUTPUT, format="PNG", optimize=True)
    icon.resize((150, 150), Image.Resampling.LANCZOS).save(
        ICON_PREVIEW, format="PNG", optimize=True
    )

    thumbnail = Image.open(THUMBNAIL_SOURCE).convert("RGB")
    thumbnail = cover(thumbnail, (1920, 1080))
    thumbnail = draw_title(thumbnail)
    thumbnail.save(THUMBNAIL_OUTPUT, format="PNG", optimize=True)
    thumbnail.resize((480, 270), Image.Resampling.LANCZOS).save(
        THUMBNAIL_PREVIEW, format="PNG", optimize=True
    )


if __name__ == "__main__":
    main()
