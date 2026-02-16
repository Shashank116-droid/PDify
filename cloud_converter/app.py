import os
import subprocess
import uuid
import shutil
from flask import Flask, request, send_file, jsonify
from pdf2docx import Converter

app = Flask(__name__)

TEMP_DIR = "/tmp/conversions"

# Valid input extensions
VALID_TO_PDF = {".docx", ".doc", ".pptx", ".ppt", ".odt", ".odp", ".xlsx", ".xls"}
VALID_FROM_PDF = {".pdf"}


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/convert/to-pdf", methods=["POST"])
def convert_to_pdf():
    """Convert office documents (docx, pptx, etc.) to PDF using LibreOffice."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if not file.filename:
        return jsonify({"error": "No filename"}), 400

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in VALID_TO_PDF:
        return jsonify({"error": f"Unsupported format: {ext}"}), 400

    job_id = str(uuid.uuid4())
    job_dir = os.path.join(TEMP_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    try:
        input_path = os.path.join(job_dir, file.filename)
        file.save(input_path)

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
            return jsonify({
                "error": "Conversion failed",
                "stderr": result.stderr,
                "stdout": result.stdout
            }), 500

        base_name = os.path.splitext(file.filename)[0]
        output_path = os.path.join(job_dir, f"{base_name}.pdf")

        if not os.path.exists(output_path):
            files_in_dir = os.listdir(job_dir)
            return jsonify({
                "error": f"Output file not found. Generated: {files_in_dir}",
                "stderr": result.stderr
            }), 500

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
        shutil.rmtree(job_dir, ignore_errors=True)


@app.route("/convert/from-pdf", methods=["POST"])
def convert_from_pdf():
    """Convert PDF to DOCX (using pdf2docx) or PPTX (using LibreOffice)."""
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

    job_id = str(uuid.uuid4())
    job_dir = os.path.join(TEMP_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)

    try:
        input_path = os.path.join(job_dir, file.filename)
        file.save(input_path)
        base_name = os.path.splitext(file.filename)[0]
        output_path = os.path.join(job_dir, f"{base_name}.{output_format}")

        if output_format == "docx":
            # Use pdf2docx for Word conversion
            try:
                cv = Converter(input_path)
                cv.convert(output_path)
                cv.close()
            except Exception as e:
                return jsonify({"error": f"pdf2docx conversion failed: {str(e)}"}), 500
                
        else:
            # Use LibreOffice for PPTX (experimental)
            # Note: PDF import into Impress/Draw and export to PPTX is shaky
            result = subprocess.run(
                [
                    "libreoffice",
                    "--headless",
                    "--infilter=impress_pdf_import",
                    "--convert-to",
                    "pptx:'Impress MS PowerPoint 2007 XML'",
                    "--outdir",
                    job_dir,
                    input_path,
                ],
                capture_output=True,
                text=True,
                timeout=120,
            )
            
            if result.returncode != 0:
                 return jsonify({
                    "error": "LibreOffice conversion failed",
                    "stderr": result.stderr,
                    "stdout": result.stdout
                }), 500

        if not os.path.exists(output_path):
             files_in_dir = os.listdir(job_dir)
             return jsonify({
                "error": f"Output file not found. Generated: {files_in_dir}",
            }), 500

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

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        shutil.rmtree(job_dir, ignore_errors=True)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
