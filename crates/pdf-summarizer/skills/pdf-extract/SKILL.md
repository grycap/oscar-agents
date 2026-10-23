---
name: pdf-extract
description: Extract readable text and basic metadata from PDF files before summarization.
---

# PDF Extract Skill

## Overview

Use terminal and file tools to inspect a PDF and extract text that can be safely
used by the agent.

## When to Use

Use this skill when the input is a PDF document and the agent needs a faithful
text representation before analysis or summarization.

## Body

1. Verify that the input file exists and appears to be a PDF.
2. Prefer `pdftotext` when available:

   ```bash
   pdftotext input.pdf extracted.txt
   ```

3. Inspect the extracted text before summarizing it.
4. If extraction yields little or no text, report that the document may be
   scanned or image-based.
5. Summarize only information present in the extracted text.

## Pitfalls

- Do not infer content from the filename or PDF metadata alone.
- Do not invent citations, authors, results, or conclusions.
- Do not claim OCR was performed unless an OCR tool was actually used.

## Checklist

- The PDF was inspected.
- Extracted text was used as the source of truth.
- Extraction limitations were reported when relevant.
