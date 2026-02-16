import os
import subprocess
import uuid
import shutil
from flask import Flask, request, send_file, jsonify

app = Flask(__name__)

TEMP_DIR = "/tmp/conversions"

# Mapping of output formats to LibreOffice filter names
FORMAT_FILTERS = {
    "pdf": "pdf",
    "docx": "docx:'MS Word 2007 XML'",
    "pptx": "pptx:'Impress MS PowerPoint 2007 XML'",
}

# Valid input extensions
VALID_TO_PDF = {".docx", ".doc", ".pptx", ".ppt", ".odt", ".odp", ".xlsx", ".xls"}
VALID_FROM_PDF = {".pdf"}


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/convert/to-pdf", methods=["POST"])
def convert_to_pdf():
    """Convert office documents (docx, pptx, etc.) to PDF."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if not file.filename:
        return jsonify({"error": "No filename"}), 400

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in VALID_TO_PDF:
        return jsonify({"error": f"Unsupported format: {ext}"}), 400

    # Create unique working directory
    job_id = str(uuid.uuid4())
    job_dir = os.path.join(TEMP_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    try:
        # Save uploaded file
        input_path = os.path.join(job_dir, file.filename)
        file.save(input_path)

        # Convert using LibreOffice
        result = subprocess.run(
            [
                "libreoffice",
                "--headless",
                "--convert-to",
                "pdf",
                "--outdir",
                job_dir,
                input_path,
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )

        if result.returncode != 0:
            return jsonify({"error": f"Conversion failed: {result.stderr}"}), 500

        # Find output file
        base_name = os.path.splitext(file.filename)[0]
        output_path = os.path.join(job_dir, f"{base_name}.pdf")

        if not os.path.exists(output_path):
            return jsonify({"error": "Output file not found"}), 500

        return send_file(
            output_path,
            as_attachment=True,
            download_name=f"{base_name}.pdf",
            mimetype="application/pdf",
        )

    except subprocess.TimeoutExpired:
        return jsonify({"error": "Conversion timed out"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        # Cleanup
        shutil.rmtree(job_dir, ignore_errors=True)


@app.route("/convert/from-pdf", methods=["POST"])
def convert_from_pdf():
    """Convert PDF to office documents (docx, pptx)."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    output_format = request.form.get("format", "docx").lower()

    if not file.filename:
        return jsonify({"error": "No filename"}), 400

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in VALID_FROM_PDF:
        return jsonify({"error": f"Input must be PDF, got: {ext}"}), 400

    if output_format not in ("docx", "pptx"):
        return jsonify({"error": f"Unsupported output format: {output_format}"}), 400

    # Create unique working directory
    job_id = str(uuid.uuid4())
    job_dir = os.path.join(TEMP_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    try:
        # Save uploaded file
        input_path = os.path.join(job_dir, file.filename)
        file.save(input_path)

        # Get the LibreOffice filter for the target format
        lo_filter = FORMAT_FILTERS.get(output_format, output_format)

        # Convert using LibreOffice
        result = subprocess.run(
            [
                "libreoffice",
                "--headless",
                "--infilter=impress_pdf_import" if output_format == "pptx" else "--infilter=writer_pdf_import",
                "--convert-to",
                lo_filter,
                "--outdir",
                job_dir,
                input_path,
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )

        if result.returncode != 0:
            return jsonify({"error": f"Conversion failed: {result.stderr}"}), 500

        # Find output file
        base_name = os.path.splitext(file.filename)[0]
        output_path = os.path.join(job_dir, f"{base_name}.{output_format}")

        if not os.path.exists(output_path):
            return jsonify({"error": "Output file not found"}), 500

        mime_types = {
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        }

        return send_file(
            output_path,
            as_attachment=True,
            download_name=f"{base_name}.{output_format}",
            mimetype=mime_types.get(output_format, "application/octet-stream"),
        )

    except subprocess.TimeoutExpired:
        return jsonify({"error": "Conversion timed out"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        # Cleanup
        shutil.rmtree(job_dir, ignore_errors=True)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
