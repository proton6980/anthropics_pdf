#!/bin/sh
# 功能级 smoke: 沙箱 base image 里真跑 pdf 全工具链。
# OCR 用 rapidocr(requirements.txt 装); pdftk 沙箱无, 不测。由 scripts/smoke.sh 在容器内执行。
set -e

echo "-- reportlab 造 PDF"
python - <<'PY'
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
c = canvas.Canvas("/tmp/smoke.pdf", pagesize=letter)
c.drawString(72, 720, "Smoke PDF hello sandbox")
c.showPage()
c.drawString(72, 720, "Page two")
c.showPage()
c.save()
print("  created /tmp/smoke.pdf")
PY

echo "-- pypdf 读页数"
python - <<'PY'
from pypdf import PdfReader
r = PdfReader("/tmp/smoke.pdf")
assert len(r.pages) == 2, len(r.pages)
print("  pages:", len(r.pages))
PY

echo "-- pdfplumber 提取文本"
python - <<'PY'
import pdfplumber
with pdfplumber.open("/tmp/smoke.pdf") as pdf:
    txt = pdf.pages[0].extract_text() or ""
assert "hello sandbox" in txt, repr(txt)
print("  extracted:", txt.strip())
PY

echo "-- pdf2image 转图片 (poppler pdftoppm)"
python - <<'PY'
from pdf2image import convert_from_path
imgs = convert_from_path("/tmp/smoke.pdf", dpi=72)
assert len(imgs) == 2, len(imgs)
imgs[0].save("/tmp/smoke_p1.png")
print("  images:", len(imgs), "| size:", imgs[0].size)
PY

echo "-- qpdf CLI 合并 (替代 pdftk)"
qpdf --empty --pages /tmp/smoke.pdf /tmp/smoke.pdf -- /tmp/smoke_merged.pdf
python - <<'PY'
from pypdf import PdfReader
assert len(PdfReader("/tmp/smoke_merged.pdf").pages) == 4
print("  merged pages: 4")
PY

echo "-- rapidocr OCR 扫描件 (渲染大字 PDF -> 转图 -> 识别)"
python - <<'PY'
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
c = canvas.Canvas("/tmp/scan.pdf", pagesize=letter)
c.setFont("Helvetica-Bold", 48)          # 大字, 靠 OCR 认
c.drawString(80, 600, "INVOICE 2026")
c.save()

import numpy as np
from pdf2image import convert_from_path
from rapidocr_onnxruntime import RapidOCR
img = convert_from_path("/tmp/scan.pdf", dpi=200)[0]
result, _ = RapidOCR()(np.asarray(img))
txt = " ".join(l[1] for l in (result or [])).upper()
assert "INVOICE" in txt and "2026" in txt, repr(txt)
print("  OCR 识别:", txt)
PY

echo "功能 smoke 通过: reportlab/pypdf/pdfplumber/pdf2image/rapidocr + qpdf 全链可用 (pdftk 沙箱不测)"
