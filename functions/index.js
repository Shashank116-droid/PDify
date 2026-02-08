const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const pdf = require("pdf-parse");
const vision = require("@google-cloud/vision");

// OCR threshold - if extracted text is below this, trigger OCR
const OCR_TEXT_THRESHOLD = 150;
const MAX_OCR_PAGES = 10;


admin.initializeApp();

/**
 * Performs OCR on a PDF file stored in GCS using Google Cloud Vision API.
 * Uses asyncBatchAnnotateFiles to process PDF directly without image conversion.
 * @param {string} bucketName - The GCS bucket name
 * @param {string} filePath - The path to the PDF file in the bucket
 * @returns {Promise<string>} - The extracted OCR text
 */
async function performOcr(bucketName, filePath) {
    const client = new vision.ImageAnnotatorClient();

    const gcsSourceUri = `gs://${bucketName}/${filePath}`;
    const gcsDestinationUri = `gs://${bucketName}/ocr_output/${Date.now()}/`;

    const inputConfig = {
        mimeType: 'application/pdf',
        gcsSource: { uri: gcsSourceUri },
    };

    const outputConfig = {
        gcsDestination: { uri: gcsDestinationUri },
        batchSize: MAX_OCR_PAGES, // Process up to MAX_OCR_PAGES at once
    };

    const features = [{ type: 'DOCUMENT_TEXT_DETECTION' }];

    const request = {
        requests: [{
            inputConfig: inputConfig,
            features: features,
            outputConfig: outputConfig,
            pages: Array.from({ length: MAX_OCR_PAGES }, (_, i) => i + 1), // Pages 1-10
        }],
    };

    console.log(`Starting OCR for ${gcsSourceUri}...`);
    const [operation] = await client.asyncBatchAnnotateFiles(request);
    const [filesResponse] = await operation.promise();

    // Read OCR results from GCS output
    const bucket = admin.storage().bucket(bucketName);
    const [files] = await bucket.getFiles({ prefix: gcsDestinationUri.replace(`gs://${bucketName}/`, '') });

    let fullText = '';
    for (const file of files) {
        if (file.name.endsWith('.json')) {
            const [content] = await file.download();
            const jsonContent = JSON.parse(content.toString());
            if (jsonContent.responses) {
                for (const response of jsonContent.responses) {
                    if (response.fullTextAnnotation && response.fullTextAnnotation.text) {
                        fullText += response.fullTextAnnotation.text + '\n';
                    }
                }
            }
            // Clean up OCR output file
            await file.delete();
        }
    }

    // Normalize whitespace
    fullText = fullText.replace(/\s+/g, ' ').trim();

    return fullText;
}

/**
 * Detects chapter boundaries in text using common patterns.
 * Returns an array of chapter objects with title and content.
 * @param {string} text - The full text to analyze
 * @returns {Array<{title: string, content: string}>} - Array of chapters
 */
function detectChapters(text) {
    // Common chapter/section patterns
    const chapterPatterns = [
        /^(Chapter\s+\d+[.:]*\s*.*)$/gim,
        /^(Unit\s+\d+[.:]*\s*.*)$/gim,
        /^(Section\s+\d+[.:]*\s*.*)$/gim,
        /^(Part\s+[IVXLC\d]+[.:]*\s*.*)$/gim,
        /^(Module\s+\d+[.:]*\s*.*)$/gim,
        /^(Lecture\s+\d+[.:]*\s*.*)$/gim,
        /^(\d+\.\s+[A-Z][^.]{5,50})$/gm, // "1. Introduction to..."
    ];

    // Find all matches with their positions
    let markers = [];
    for (const pattern of chapterPatterns) {
        let match;
        const regex = new RegExp(pattern.source, pattern.flags);
        while ((match = regex.exec(text)) !== null) {
            markers.push({
                title: match[1].trim(),
                position: match.index
            });
        }
    }

    // If no chapters detected, return empty array (fall back to single summary)
    if (markers.length < 2) {
        return [];
    }

    // Sort by position
    markers.sort((a, b) => a.position - b.position);

    // Remove duplicates that are too close together (within 50 chars)
    markers = markers.filter((marker, index) => {
        if (index === 0) return true;
        return marker.position - markers[index - 1].position > 50;
    });

    // If still less than 2 chapters, return empty
    if (markers.length < 2) {
        return [];
    }

    // Extract content for each chapter
    const chapters = [];
    for (let i = 0; i < markers.length; i++) {
        const start = markers[i].position;
        const end = i < markers.length - 1 ? markers[i + 1].position : text.length;
        const content = text.substring(start, end).trim();

        // Only include chapters with substantial content (> 200 chars)
        if (content.length > 200) {
            chapters.push({
                title: markers[i].title,
                content: content.substring(0, 15000) // Limit per chapter
            });
        }
    }

    // Only return chapters if we have at least 2 valid ones
    return chapters.length >= 2 ? chapters : [];
}

// Set memory to 1GiB and timeout to 540s for OCR processing
setGlobalOptions({ region: "us-central1", memory: "1GiB", timeoutSeconds: 540 });

exports.processPdf = onDocumentCreated("pdfs/{pdfId}", async (event) => {
    // v2 API: event.data is a DocumentSnapshot
    // But wait, event.data is a FirestoreEvent data. 
    // For onDocumentCreated, event.data is a QueryDocumentSnapshot.

    const snap = event.data;
    if (!snap) {
        console.log("No data associated with the event");
        return;
    }

    const pdfId = event.params.pdfId;
    const data = snap.data();
    const storagePath = data.storagePath;

    if (!storagePath) {
        console.error("No storagePath found in document");
        return;
    }

    // --- COST OPTIMIZATION: Early exit checks ---

    // 1. Skip if already completed or error (prevents re-processing)
    const currentStatus = data.status;
    if (currentStatus === 'completed' || currentStatus === 'error') {
        console.log(`PDF ${pdfId} already has status '${currentStatus}'. Skipping.`);
        return;
    }

    // 2. Check if summary already exists for this PDF (prevents duplicates)
    const existingSummary = await admin.firestore()
        .collection('summaries')
        .where('pdfId', '==', pdfId)
        .where('type', '==', 'full')
        .limit(1)
        .get();

    if (!existingSummary.empty) {
        console.log(`Summary already exists for PDF ${pdfId}. Marking as completed.`);
        await snap.ref.update({ status: "completed" });
        return;
    }
    // --- END COST OPTIMIZATION ---

    try {
        const bucket = admin.storage().bucket();
        const file = bucket.file(storagePath);

        const [buffer] = await file.download();
        const pdfData = await pdf(buffer);
        let text = pdfData.text;
        let isOcrText = false;

        // Check if text extraction returned very little content (likely scanned PDF)
        if (text.trim().length < OCR_TEXT_THRESHOLD) {
            console.log(`Text extraction returned only ${text.trim().length} chars. Attempting OCR...`);
            try {
                text = await performOcr(bucket.name, storagePath);
                isOcrText = true;
                console.log(`OCR extracted ${text.length} chars.`);
            } catch (ocrError) {
                console.error("OCR failed:", JSON.stringify(ocrError, Object.getOwnPropertyNames(ocrError)));
                throw new Error(`OCR failed: ${ocrError.message}`);
            }
        }

        const apiKey = process.env.AI_API_KEY;
        if (!apiKey) {
            console.error("AI API Key is MISSING in environment variables.");
            throw new Error("AI API Key not configured.");
        }
        console.log(`AI API Key loaded: ${apiKey.substring(0, 5)}...`);

        const modelName = "gemini-2.5-flash";
        const fallbackModelName = "gemini-2.0-flash-exp";

        const generateContent = async (model, promptTextOverride = null) => {
            const getUrl = (m) => `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${apiKey}`;

            const makeRequest = async (m) => {
                return fetch(getUrl(m), {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{
                            parts: [{
                                text: promptTextOverride || (isOcrText
                                    ? `The following text comes from handwritten class notes. Clean and organize it before summarizing:\n\n${text.substring(0, 30000)}`
                                    : `Summarize this PDF content for a student, handling key points and concepts concisely:\n\n${text.substring(0, 30000)}`)
                            }]
                        }]
                    })
                });
            };

            let retries = 3;
            let delay = 2000;
            let currentModel = model;

            while (retries >= 0) {
                try {
                    const response = await makeRequest(currentModel);

                    if (response.status === 429 || response.status === 404 || response.status === 503) {
                        console.warn(`Error ${response.status} for ${currentModel}. Retrying...`);

                        // If primary fails, switch to fallback immediately for next try
                        if (currentModel === modelName && fallbackModelName) {
                            console.log(`Switching to fallback model: ${fallbackModelName}`);
                            currentModel = fallbackModelName;
                            // Don't wait long for model switch, just retry immediately
                            delay = 1000;
                        } else {
                            // If fallback also fails, wait and retry
                            if (retries === 0) return { response, usedModel: currentModel };
                            await new Promise(resolve => setTimeout(resolve, delay));
                            delay *= 2;
                        }

                        retries--;
                        continue;
                    }

                    return { response, usedModel: currentModel };
                } catch (err) {
                    console.error("Fetch error:", err);
                    if (retries === 0) throw err;
                    await new Promise(resolve => setTimeout(resolve, delay));
                    retries--;
                    delay *= 2;
                }
            }
            // Should not reach here, but as a fallback
            throw new Error("Failed to generate content after multiple retries.");
        };

        const { response, usedModel: usedModelName } = await generateContent(modelName);

        if (!response.ok) {
            const errorBody = await response.text();
            throw new Error(`Gemini API Error (${response.status}): ${errorBody}`);
        }

        const json = await response.json();
        const summaryText = json.candidates?.[0]?.content?.parts?.[0]?.text;

        if (!summaryText) {
            throw new Error("No summary text generated in response.");
        }

        await admin.firestore().collection("summaries").add({
            pdfId: pdfId,
            content: summaryText,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            model: usedModelName,
            type: "full" // Mark as full summary
        });

        // --- Exam-Oriented Summary (Additive Feature) ---
        try {
            const examPrompt = `You are helping a student prepare for exams. Analyze the following content and create an exam-focused summary:

1. **Key Definitions**: List important terms and their definitions
2. **Core Concepts**: Explain the main concepts that are likely to be tested
3. **Potential Exam Questions**: Suggest 3-5 likely exam questions based on the content
4. **Quick Review Points**: Bullet points for last-minute revision

Content:
${text.substring(0, 25000)}`;

            const { response: examResponse } = await generateContent(usedModelName, examPrompt);

            if (examResponse.ok) {
                const examJson = await examResponse.json();
                const examSummaryText = examJson.candidates?.[0]?.content?.parts?.[0]?.text;

                if (examSummaryText) {
                    await admin.firestore().collection("summaries").add({
                        pdfId: pdfId,
                        content: examSummaryText,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        model: usedModelName,
                        type: "exam" // Mark as exam summary
                    });
                    console.log("Exam summary generated and stored.");
                }
            } else {
                console.warn(`Exam summary generation failed: ${examResponse.status}`);
            }
        } catch (examError) {
            // Exam summary failure should NOT fail the main process
            console.warn("Exam summary generation failed (non-critical):", examError.message);
        }
        // --- End Exam-Oriented Summary ---

        // --- Chapter-wise Summaries (Additive Feature) ---
        try {
            const chapters = detectChapters(text);

            if (chapters.length >= 2) {
                console.log(`Detected ${chapters.length} chapters. Generating chapter summaries...`);

                // Helper to generate chapter summary
                const generateChapterSummary = async (chapter, chapterIndex) => {
                    const chapterPrompt = `Summarize this chapter/section concisely for a student. Focus on key concepts and takeaways.\n\nTitle: ${chapter.title}\n\nContent:\n${chapter.content}`;

                    const { response: chapterResponse } = await generateContent(usedModelName, chapterPrompt);

                    if (!chapterResponse.ok) {
                        console.warn(`Chapter ${chapterIndex + 1} summary failed: ${chapterResponse.status}`);
                        return null;
                    }

                    const chapterJson = await chapterResponse.json();
                    return chapterJson.candidates?.[0]?.content?.parts?.[0]?.text || null;
                };

                // Process chapters sequentially to avoid rate limits
                const chapterSummaries = [];
                for (let i = 0; i < Math.min(chapters.length, 10); i++) { // Max 10 chapters
                    const chapterSummary = await generateChapterSummary(chapters[i], i);
                    if (chapterSummary) {
                        chapterSummaries.push({
                            title: chapters[i].title,
                            summary: chapterSummary,
                            order: i
                        });
                    }
                }

                // Store chapter summaries if we have any
                if (chapterSummaries.length > 0) {
                    await admin.firestore().collection("summaries").add({
                        pdfId: pdfId,
                        chapters: chapterSummaries,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        model: usedModelName,
                        type: "chapters" // Mark as chapter summary
                    });
                    console.log(`Stored ${chapterSummaries.length} chapter summaries.`);
                }
            } else {
                console.log("No chapter structure detected, skipping chapter summaries.");
            }
        } catch (chapterError) {
            // Chapter summary failure should NOT fail the main process
            console.warn("Chapter summary generation failed (non-critical):", chapterError.message);
        }
        // --- End Chapter-wise Summaries ---

        await snap.ref.update({ status: "completed" });
    } catch (error) {
        console.error("Error processing PDF:", JSON.stringify(error, Object.getOwnPropertyNames(error)));
        await snap.ref.update({ status: "error" });
    }
});
